// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>

#include "Host.h"
#include "../ListingInput.h"
#include "EncodingDetection.h"
#include "File.h"
#include "Internal.h"
#include <Base/CFStackAllocator.h>
#include <Base/UnorderedUtil.h>
#include <Base/algo.h>
#include <Base/StackAllocator.h>
#include <Base/CFPtr.h>
#include <Utility/DataBlockAnalysis.h>
#include <Utility/PathManip.h>
#include <VFS/AppleDoubleEA.h>
#include <VFS/Log.h>
#include <fmt/format.h>
#include <mutex>
#include <sys/dirent.h>
#include <sys/param.h>

namespace nc::vfs {

const char *const ArchiveHost::UniqueTag = "arc_libarchive";

struct ArchiveHost::Impl {
    // Path to a dir including trailing slash -> Dir structure
    using PathToDirT = ankerl::unordered_dense::
        segmented_map<std::string, arc::Dir, nc::UnorderedStringHashEqual, nc::UnorderedStringHashEqual>;

    using SymlinksT = ankerl::unordered_dense::map<uint32_t, Symlink>;

    std::shared_ptr<VFSFile> m_ArFile;
    std::shared_ptr<arc::Mediator> m_Mediator;
    struct ::archive *m_Arc = nullptr;
    PathToDirT m_PathToDir;

    uint32_t m_TotalFiles = 0;
    uint32_t m_TotalDirs = 0;
    uint32_t m_TotalRegs = 0;
    uint32_t m_LastItemUID = 0;
    uint64_t m_ArchivedFilesTotalSize = 0;

    bool m_NeedsPathResolving = false; // true if there are any symlinks present in archive
    SymlinksT m_Symlinks;
    std::recursive_mutex m_SymlinksResolveLock;

    // TODO: this leaves 4 bytes of gaps, i.e. for 500K# archive = 2MB of waste(!)
    std::vector<std::pair<arc::Dir *, uint32_t>> m_EntryByUID; // points to directory and entry No inside it

    std::vector<std::unique_ptr<arc::State>> m_States;
    std::mutex m_StatesLock;

    struct stat m_SrcFileStat;
};

class VFSArchiveHostConfiguration
{
public:
    std::string path;
    std::optional<std::string> password;

    [[nodiscard]] static const char *Tag() { return ArchiveHost::UniqueTag; }

    [[nodiscard]] const char *Junction() const { return path.c_str(); }

    bool operator==(const VFSArchiveHostConfiguration &_rhs) const
    {
        return path == _rhs.path && password == _rhs.password;
    }
};

static VFSConfiguration ComposeConfiguration(const std::string_view _path, std::optional<std::string> _passwd)
{
    VFSArchiveHostConfiguration config;
    config.path = _path;
    config.password = std::move(_passwd);
    return {std::move(config)};
}

void ArchiveHost::AppendDecodedStringToUTF8(const std::span<const std::byte> _bytes,
                                            const CFStringEncoding _encoding,
                                            std::pmr::string &_to)
{
    const base::CFStackAllocator alloc;
    const base::CFPtr<CFStringRef> str = base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytesNoCopy(
        alloc, reinterpret_cast<const UInt8 *>(_bytes.data()), _bytes.size(), _encoding, false, kCFAllocatorNull));
    if( str ) {
        if( const char *utf8 = CFStringGetCStringPtr(str.get(), kCFStringEncodingUTF8) ) {
            _to.append(utf8);
            return;
        }
        else {
            char buf[4096];
            if( CFStringGetCString(str.get(), buf, std::size(buf), kCFStringEncodingUTF8) ) {
                _to.append(buf);
                return;
            }
        }
    }

    // corrupt string - just append raw bytes as a fallback
    _to.append(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
}

ArchiveHost::ArchiveHost(const std::string_view _path,
                         const VFSHostPtr &_parent,
                         std::optional<std::string> _password,
                         VFSCancelChecker _cancel_checker)
    : Host(_path, _parent, UniqueTag), I(std::make_unique<Impl>()),
      m_Configuration(ComposeConfiguration(_path, std::move(_password)))
{
    assert(_parent);
    if( const std::expected<void, Error> rc = DoInit(_cancel_checker); !rc ) {
        if( I->m_Arc != nullptr ) { // TODO: ugly
            archive_read_free(I->m_Arc);
            I->m_Arc = nullptr;
        }
        throw ErrorException(rc.error());
    }
}

ArchiveHost::ArchiveHost(const VFSHostPtr &_parent, const VFSConfiguration &_config, VFSCancelChecker _cancel_checker)
    : Host(_config.Get<VFSArchiveHostConfiguration>().path, _parent, UniqueTag), I(std::make_unique<Impl>()),
      m_Configuration(_config)
{
    assert(_parent);
    if( const std::expected<void, Error> rc = DoInit(_cancel_checker); !rc ) {
        if( I->m_Arc != nullptr ) { // TODO: ugly
            archive_read_free(I->m_Arc);
            I->m_Arc = nullptr;
        }
        throw ErrorException(rc.error());
    }
}

ArchiveHost::~ArchiveHost()
{
    if( I->m_Arc != nullptr )
        archive_read_free(I->m_Arc);
}

bool ArchiveHost::IsImmutableFS() const noexcept
{
    return true;
}

VFSConfiguration ArchiveHost::Configuration() const
{
    return m_Configuration;
}

const VFSArchiveHostConfiguration &ArchiveHost::Config() const
{
    return m_Configuration.GetUnchecked<VFSArchiveHostConfiguration>();
}

VFSMeta ArchiveHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig =
        [](const VFSHostPtr &_parent, const VFSConfiguration &_config, VFSCancelChecker _cancel_checker) {
            return std::make_shared<ArchiveHost>(_parent, _config, _cancel_checker);
        };
    return m;
}

std::expected<void, Error> ArchiveHost::DoInit(const VFSCancelChecker &_cancel_checker)
{
    using namespace arc;
    assert(I->m_Arc == nullptr);
    int res = 0;

    StackAllocator alloc;
    const std::pmr::string path(JunctionPath(), &alloc);

    {
        const std::expected<VFSStat, Error> st = Parent()->Stat(path, 0, _cancel_checker);
        if( !st )
            return std::unexpected(st.error());
        VFSStat::ToSysStat(*st, I->m_SrcFileStat);
    }

    VFSFilePtr source_file;
    if( auto exp = Parent()->CreateFile(path, _cancel_checker); exp )
        source_file = *exp;
    else
        return std::unexpected(exp.error());

    if( const std::expected<void, Error> rc = source_file->Open(VFSFlags::OF_Read); !rc )
        return rc;

    if( const std::expected<uint64_t, Error> source_file_size = source_file->Size(); !source_file_size )
        return std::unexpected(source_file_size.error());
    else if( *source_file_size == 0 )
        return std::unexpected(
            Error{Error::POSIX, EFTYPE}); // libarchive thinks that zero-bytes archives are OK, but I don't think so.

    if( Parent()->IsNativeFS() ) {
        I->m_ArFile = source_file;
    }
    else {
        auto wrapping = std::make_shared<VFSSeqToRandomROWrapperFile>(source_file);
        if( const std::expected<void, Error> rc = wrapping->Open(VFSFlags::OF_Read, _cancel_checker); !rc )
            return rc;
        I->m_ArFile = wrapping;
    }

    if( I->m_ArFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential ) {
        I->m_ArFile.reset();
        return std::unexpected(Error{Error::POSIX, EINVAL});
    }

    I->m_Mediator = std::make_shared<Mediator>();
    I->m_Mediator->file = I->m_ArFile;

    I->m_Arc = SpawnLibarchive();

    archive_read_set_callback_data(I->m_Arc, I->m_Mediator.get());
    archive_read_set_read_callback(I->m_Arc, Mediator::myread);
    archive_read_set_seek_callback(I->m_Arc, Mediator::myseek);
    res = archive_read_open1(I->m_Arc);
    if( res < 0 ) {
        const int err = archive_errno(I->m_Arc);
        archive_read_free(I->m_Arc);
        I->m_Arc = nullptr;
        I->m_Mediator.reset();
        I->m_ArFile.reset();
        return std::unexpected(Error{Error::POSIX, err});
    }

    // we should fail is archive is encrypted and there's no password provided
    if( archive_read_has_encrypted_entries(I->m_Arc) > 0 && !Config().password )
        return std::unexpected(Error{Error::POSIX, ENEEDAUTH});

    const std::expected<void, Error> list_rc = ReadArchiveListing();
    if( archive_read_has_encrypted_entries(I->m_Arc) > 0 && !Config().password )
        return std::unexpected(Error{Error::POSIX, ENEEDAUTH});

    if( !list_rc )
        return std::unexpected(list_rc.error());

    return {};
}

std::expected<void, Error> ArchiveHost::ReadArchiveListing()
{
    using namespace arc;
    assert(I->m_Arc != nullptr);
    uint32_t aruid = 0;

    Dir *parent_dir = nullptr;
    {
        // Manually "invent" the root directory
        assert(I->m_PathToDir.empty());
        Dir root_dir;
        root_dir.full_path = "/";
        root_dir.name_in_parent = "";
        const auto ret = I->m_PathToDir.emplace("/", std::move(root_dir));
        parent_dir = &ret.first->second;
    }

    std::optional<CFStringEncoding> detected_encoding;
    StackAllocator alloc;

    // This string will be reused for each entry path decoding
    std::pmr::string path{&alloc};

    struct archive_entry *aentry;
    int ret = 0;
    while( (ret = archive_read_next_header(I->m_Arc, &aentry)) == ARCHIVE_OK ) {
        aruid++;
        const struct stat *stat = archive_entry_stat(aentry);
        if( stat == nullptr )
            continue; // check for broken archives

        const char *entry_pathname = archive_entry_pathname(aentry);
        if( entry_pathname == nullptr )
            continue; // check for broken archives

        const size_t entry_pathname_len = std::string_view{entry_pathname}.length();
        if( entry_pathname_len == 0 )
            continue;

        const bool entry_pathname_has_heading_slash = entry_pathname[0] == '/';

        // When decoding each entry path - reuse the same buffer, clearing it first.
        // If the entry doesn't start with a slash - add it manually to the beginning.
        path.clear();
        if( !entry_pathname_has_heading_slash )
            path += '/';

        // pathname can be represented in ANY encoding.
        // if we already have figured out it - convert from it to UTF8 immediately
        if( detected_encoding ) {
            AppendDecodedStringToUTF8(
                {reinterpret_cast<const std::byte *>(entry_pathname), entry_pathname_len}, *detected_encoding, path);
        }
        else {
            // if we don't know any specific encoding setting for this archive - check for UTF8.
            // this checking is supposed to be very fast, for most archives it will return true
            if( IsValidUTF8String(entry_pathname, entry_pathname_len) ) {
                // we can use the path straightaway
                path.append(entry_pathname, entry_pathname_len);
            }
            else {
                // if this archive doesn't use a valid UTF8 encoding -
                // find it out and decode to UTF8
                if( !detected_encoding )
                    detected_encoding = DetectEncoding(entry_pathname, entry_pathname_len);

                AppendDecodedStringToUTF8({reinterpret_cast<const std::byte *>(entry_pathname), entry_pathname_len},
                                          *detected_encoding,
                                          path);
            }
        }

        if( path == "/" )
            continue; // skip root entry - they are handled manually outside

        if( path == "/." )
            continue; // skip "." entry for ISO for example

        const bool isdir = (stat->st_mode & S_IFMT) == S_IFDIR;
        const bool isreg = (stat->st_mode & S_IFMT) == S_IFREG;
        const bool issymlink = (stat->st_mode & S_IFMT) == S_IFLNK;
        const std::string_view parent_path = utility::PathManip::Parent(path);
        const std::string_view filename = utility::PathManip::Filename(path);

        if( parent_dir->full_path != parent_path ) {
            Dir *const new_parent = FindOrBuildDir(parent_path);
            if( new_parent == nullptr ) {
                continue; // skip entries with bogus paths
            }
            parent_dir = new_parent;
        }

        DirEntry *entry = nullptr;
        unsigned entry_index_in_dir = 0;
        if( isdir ) // check if it wasn't added before via FindOrBuildDir
            for( size_t i = 0, e = parent_dir->entries.size(); i < e; ++i ) {
                auto &it = parent_dir->entries[i];
                if( (it.st.st_mode & S_IFMT) == S_IFDIR && it.name == filename ) {
                    assert(it.aruid == SyntheticArUID);
                    entry = &it;
                    entry_index_in_dir = static_cast<unsigned>(i);
                    break;
                }
            }

        if( entry == nullptr ) {
            parent_dir->entries.emplace_back();
            entry_index_in_dir = static_cast<unsigned>(parent_dir->entries.size() - 1);
            entry = &parent_dir->entries.back();
            entry->name = filename;
        }

        entry->aruid = aruid;
        entry->st = *stat;
        I->m_ArchivedFilesTotalSize += stat->st_size;

        if( I->m_EntryByUID.size() <= entry->aruid )
            I->m_EntryByUID.resize(entry->aruid + 1, std::make_pair(nullptr, 0));
        I->m_EntryByUID[entry->aruid] = std::make_pair(parent_dir, entry_index_in_dir);

        if( issymlink ) { // read any symlink values at archive opening time
            const char *link = archive_entry_symlink(aentry);
            Symlink symlink;
            symlink.uid = entry->aruid;
            if( !link || link[0] == 0 ) { // for invalid symlinks - mark them as invalid without resolving
                symlink.value = "";
                symlink.state = SymlinkState::Invalid;
            }
            else {
                symlink.value = link;
            }
            I->m_Symlinks.emplace(entry->aruid, std::move(symlink));
            I->m_NeedsPathResolving = true;
        }

        if( isdir ) {
            // It's a directory, so ensure the path has a trailing slash to conform map key style
            if( !path.ends_with('/') )
                path += '/';

            // Check if it wasn't added before via FindOrBuildDir
            if( !I->m_PathToDir.contains(path) ) {
                Dir dir;
                dir.full_path = path; // full_path is with trailing slash

                // NB! do no use 'filename' here - it potentially dangles here
                dir.name_in_parent = utility::PathManip::Filename(path);
                I->m_PathToDir.emplace(path, std::move(dir));
            }
        }

        if( isdir )
            I->m_TotalDirs++;
        if( isreg )
            I->m_TotalRegs++;
        I->m_TotalFiles++;
    }

    I->m_LastItemUID = aruid - 1;

    UpdateDirectorySize(I->m_PathToDir["/"], "/");

    if( ret == ARCHIVE_EOF )
        return {};

    fmt::println("{}", archive_error_string(I->m_Arc));

    if( ret == ARCHIVE_WARN )
        return {};

    return std::unexpected(Error{Error::POSIX, archive_errno(I->m_Arc)});
}

uint64_t ArchiveHost::UpdateDirectorySize(arc::Dir &_directory, const std::string &_path)
{
    uint64_t size = 0;
    for( auto &e : _directory.entries )
        if( S_ISDIR(e.st.st_mode) ) {
            const auto subdir_path = _path + e.name + "/";
            const auto it = I->m_PathToDir.find(subdir_path);
            if( it != std::end(I->m_PathToDir) ) {
                const auto subdir_sz = UpdateDirectorySize(it->second, subdir_path);
                e.st.st_size = subdir_sz;
                size += subdir_sz;
            }
        }
        else if( S_ISREG(e.st.st_mode) )
            size += e.st.st_size;

    _directory.content_size = size;

    return size;
}

arc::Dir *ArchiveHost::FindOrBuildDir(const std::string_view _path_with_tr_sl)
{
    using namespace arc;
    assert(utility::PathManip::HasTrailingSlash(_path_with_tr_sl));
    if( const auto i = I->m_PathToDir.find(_path_with_tr_sl); i != I->m_PathToDir.end() )
        return &(*i).second;

    const std::string_view parent_path = utility::PathManip::Parent(_path_with_tr_sl);
    if( parent_path.empty() ) {
        return nullptr;
    }

    const std::string_view entry_name = utility::PathManip::Filename(_path_with_tr_sl);
    if( entry_name.empty() ) {
        return nullptr;
    }

    Dir *const parent_dir = FindOrBuildDir(parent_path);
    if( parent_dir == nullptr ) {
        return nullptr;
    }

    // TODO: need to check presense of entry_name in parent_dir

    InsertDummyDirInto(parent_dir, entry_name);
    Dir entry;
    entry.full_path = _path_with_tr_sl;
    entry.name_in_parent = entry_name;
    const auto it = I->m_PathToDir.emplace(_path_with_tr_sl, std::move(entry));
    return &(*it.first).second;
}

void ArchiveHost::InsertDummyDirInto(arc::Dir *_parent, const std::string_view _dir_name)
{
    using namespace arc;
    constexpr mode_t synthetic_mode = S_IFDIR |                     //
                                      S_IRUSR | S_IXUSR | S_IWUSR | //
                                      S_IRGRP | S_IXGRP |           //
                                      S_IROTH | S_IXOTH;

    _parent->entries.emplace_back();
    auto &entry = _parent->entries.back();
    entry.name = _dir_name;
    memset(&entry.st, 0, sizeof(entry.st));
    entry.st.st_mode = synthetic_mode;
    entry.st.st_atimespec = I->m_SrcFileStat.st_atimespec;
    entry.st.st_mtimespec = I->m_SrcFileStat.st_mtimespec;
    entry.st.st_ctimespec = I->m_SrcFileStat.st_ctimespec;
    entry.st.st_birthtimespec = I->m_SrcFileStat.st_birthtimespec;
    entry.st.st_uid = I->m_SrcFileStat.st_uid;
    entry.st.st_gid = I->m_SrcFileStat.st_gid;
    entry.aruid = SyntheticArUID;
}

std::expected<std::shared_ptr<VFSFile>, Error> ArchiveHost::CreateFile(std::string_view _path,
                                                                       const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<arc::File>(_path, SharedPtr());
    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(Error{Error::POSIX, ECANCELED});
    return file;
}

std::expected<VFSListingPtr, Error> ArchiveHost::FetchDirectoryListing(std::string_view _path,
                                                                       unsigned long _flags,
                                                                       const VFSCancelChecker & /*_cancel_checker*/)
{
    StackAllocator alloc;
    std::pmr::string path(&alloc);
    if( const std::expected<void, Error> rc = ResolvePathIfNeeded(_path, path, _flags); !rc )
        return std::unexpected(rc.error());

    if( path.back() != '/' )
        path += "/";

    const auto i = I->m_PathToDir.find(path);
    if( i == I->m_PathToDir.end() )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    const auto &directory = i->second;

    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(std::string(_path));
    listing_source.atimes.reset(variable_container<>::type::dense);
    listing_source.mtimes.reset(variable_container<>::type::dense);
    listing_source.ctimes.reset(variable_container<>::type::dense);
    listing_source.btimes.reset(variable_container<>::type::dense);
    listing_source.unix_flags.reset(variable_container<>::type::dense);
    listing_source.uids.reset(variable_container<>::type::dense);
    listing_source.gids.reset(variable_container<>::type::dense);
    listing_source.sizes.reset(variable_container<>::type::dense);
    listing_source.symlinks.reset(variable_container<>::type::sparse);

    if( !(_flags & VFSFlags::F_NoDotDot) ) {
        listing_source.filenames.emplace_back("..");
        listing_source.unix_types.emplace_back(DT_DIR);
        listing_source.unix_modes.emplace_back(S_IRUSR | S_IXUSR | S_IFDIR);
        auto curtime = time(nullptr); // it's better to show date of archive itself
        listing_source.atimes.insert(0, curtime);
        listing_source.btimes.insert(0, curtime);
        listing_source.ctimes.insert(0, curtime);
        listing_source.mtimes.insert(0, curtime);
        listing_source.sizes.insert(0, directory.content_size);
        listing_source.uids.insert(0, 0);
        listing_source.gids.insert(0, 0);
        listing_source.unix_flags.insert(0, 0);
    }

    for( auto &entry : directory.entries ) {
        listing_source.filenames.emplace_back(entry.name);
        listing_source.unix_types.emplace_back(IFTODT(entry.st.st_mode));

        const int index = int(listing_source.filenames.size() - 1);
        auto stat = entry.st;
        if( S_ISLNK(entry.st.st_mode) )
            if( auto symlink = ResolvedSymlink(entry.aruid) ) {
                listing_source.symlinks.insert(index, symlink->value);
                if( symlink->state == SymlinkState::Resolved )
                    if( auto target_entry = FindEntry(symlink->target_uid) )
                        stat = target_entry->st;
            }

        listing_source.unix_modes.emplace_back(stat.st_mode);
        listing_source.sizes.insert(index,
                                    //                                    S_ISDIR(stat.st_mode) ?
                                    //                                        VFSListingInput::unknown_size :
                                    stat.st_size);
        listing_source.atimes.insert(index, stat.st_atime);
        listing_source.ctimes.insert(index, stat.st_ctime);
        listing_source.mtimes.insert(index, stat.st_mtime);
        listing_source.btimes.insert(index, stat.st_birthtime);
        listing_source.uids.insert(index, stat.st_uid);
        listing_source.gids.insert(index, stat.st_gid);
        listing_source.unix_flags.insert(index, stat.st_flags);
    }

    return VFSListing::Build(std::move(listing_source));
}

bool ArchiveHost::IsDirectory(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() )
        return false;
    if( _path[0] != '/' )
        return false;
    if( _path == "/" )
        return true;

    return Host::IsDirectory(_path, _flags, _cancel_checker);
}

std::expected<VFSStat, Error>
ArchiveHost::Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker & /*_cancel_checker*/)
{
    if( _path.empty() )
        return std::unexpected(Error{Error::POSIX, EINVAL});
    if( _path[0] != '/' )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    if( _path.length() == 1 ) {
        // we have no info about root dir - dummy here
        VFSStat st;
        st.mode = S_IRUSR | S_IFDIR;
        return st;
    }

    StackAllocator alloc;
    std::pmr::string resolve_buf(&alloc);

    if( const std::expected<void, Error> rc = ResolvePathIfNeeded(_path, resolve_buf, _flags); !rc )
        return std::unexpected(rc.error());

    if( auto it = FindEntry(resolve_buf) ) {
        VFSStat st;
        VFSStat::FromSysStat(it->st, st);
        return st;
    }
    return std::unexpected(Error{Error::POSIX, ENOENT});
}

std::expected<void, Error>
ArchiveHost::ResolvePathIfNeeded(std::string_view _path, std::pmr::string &_resolved_path, unsigned long _flags)
{
    if( _path.empty() )
        std::unexpected(Error{Error::POSIX, EINVAL});

    if( !I->m_NeedsPathResolving || (_flags & VFSFlags::F_NoFollow) ) {
        _resolved_path = _path;
    }
    else {
        return ResolvePath(_path, _resolved_path);
    }
    return {};
}

std::expected<void, Error>
ArchiveHost::IterateDirectoryListing(std::string_view _path,
                                     const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    if( !_path.starts_with("/") )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    StackAllocator alloc;
    std::pmr::string buf(&alloc);

    if( const std::expected<void, Error> rc = ResolvePathIfNeeded(_path, buf, 0); !rc )
        return std::unexpected(rc.error());

    if( buf.back() != '/' )
        buf += '/'; // we store directories with trailing slash

    const auto i = I->m_PathToDir.find(buf);
    if( i == I->m_PathToDir.end() )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    VFSDirEnt dir;

    for( const auto &it : i->second.entries ) {
        strcpy(dir.name, it.name.c_str());
        dir.name_len = uint16_t(it.name.length());

        if( S_ISDIR(it.st.st_mode) )
            dir.type = VFSDirEnt::Dir;
        else if( S_ISREG(it.st.st_mode) )
            dir.type = VFSDirEnt::Reg;
        else if( S_ISLNK(it.st.st_mode) )
            dir.type = VFSDirEnt::Link;
        else
            dir.type = VFSDirEnt::Unknown; // other stuff is not supported currently

        if( !_handler(dir) )
            break;
    }

    return {};
}

uint32_t ArchiveHost::ItemUID(const char *_filename)
{
    auto it = FindEntry(_filename);
    if( it )
        return it->aruid;
    return 0;
}

const arc::DirEntry *ArchiveHost::FindEntry(std::string_view _path) noexcept
{
    if( _path.empty() || _path[0] != '/' )
        return nullptr; // sanitation

    if( _path == "/" )
        return nullptr; // we have no info about root dir

    // Split the full path into a parent directory (including the trailing slash!) and filename
    const std::string_view parent_directory = utility::PathManip::Parent(_path);
    const std::string_view filename = utility::PathManip::Filename(_path);

    // special treatment for dot-dot
    if( filename == ".." )
        return FindEntry(parent_directory);

    // 1st - try to find _path directly (assume it's directory)
    const auto i = I->m_PathToDir.find(parent_directory);
    if( i == I->m_PathToDir.end() )
        return nullptr;

    // ok, found dir, now let's find item
    const auto found_entry_it =
        std::ranges::find_if(i->second.entries, [&](const arc::DirEntry &entry) { return entry.name == filename; });
    if( found_entry_it != i->second.entries.end() )
        return &(*found_entry_it);

    return nullptr;
}

const arc::DirEntry *ArchiveHost::FindEntry(uint32_t _uid) noexcept
{
    if( !_uid || _uid >= I->m_EntryByUID.size() )
        return nullptr;

    auto dir = I->m_EntryByUID[_uid].first;
    auto ind = I->m_EntryByUID[_uid].second;

    assert(ind < dir->entries.size());
    return &dir->entries[ind];
}

std::expected<void, Error> ArchiveHost::ResolvePath(std::string_view _path, std::pmr::string &_resolved_path)
{
    // TODO: make this malloc-free somehow, or at least use stack-backed malloc...
    if( _path.empty() || _path[0] != '/' )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    std::filesystem::path p = EnsureNoTrailingSlash(std::string(_path));
    p = p.relative_path();
    std::filesystem::path result_path = "/";

    for( auto i : p ) {
        result_path /= i;

        const arc::DirEntry *const entry = FindEntry(result_path.native());
        if( !entry )
            return std::unexpected(Error{Error::POSIX, ENOENT});

        if( (entry->st.st_mode & S_IFMT) == S_IFLNK ) {
            const auto symlink_it = I->m_Symlinks.find(entry->aruid);
            if( symlink_it == I->m_Symlinks.end() )
                return std::unexpected(Error{Error::POSIX, ENOENT});

            auto &s = symlink_it->second;
            if( s.state == SymlinkState::Unresolved )
                ResolveSymlink(s.uid);
            if( s.state != SymlinkState::Resolved )
                return std::unexpected(Error{Error::POSIX, ENOENT}); // current part points to nowhere

            result_path = s.target_path;
        }
    }

    _resolved_path = result_path.native();
    return {};
}

std::expected<VFSStatFS, Error> ArchiveHost::StatFS(std::string_view /*_path*/,
                                                    const VFSCancelChecker & /*_cancel_checker*/)
{
    const std::string_view vol_name = utility::PathManip::Filename(JunctionPath());
    if( vol_name.empty() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    VFSStatFS stat;
    stat.volume_name = vol_name;
    stat.total_bytes = I->m_ArchivedFilesTotalSize;
    stat.free_bytes = 0;
    stat.avail_bytes = 0;
    return stat;
}

bool ArchiveHost::ShouldProduceThumbnails() const
{
    return true;
}

std::unique_ptr<arc::State> ArchiveHost::ClosestState(uint32_t _requested_item)
{
    if( _requested_item == 0 )
        return nullptr;

    const std::lock_guard<std::mutex> lock(I->m_StatesLock);

    uint32_t best_delta = std::numeric_limits<uint32_t>::max();
    auto best = I->m_States.end();
    for( auto i = I->m_States.begin(), e = I->m_States.end(); i != e; ++i )
        if( (*i)->UID() < _requested_item || ((*i)->UID() == _requested_item && !(*i)->Consumed()) ) {
            const uint32_t delta = _requested_item - (*i)->UID();
            if( delta < best_delta ) {
                best_delta = delta;
                best = i;
                if( delta <= 1 ) // the closest one is found, no need to search further
                    break;
            }
        }

    if( best != I->m_States.end() ) {
        auto state = std::move(*best);
        I->m_States.erase(best);
        return state;
    }

    return nullptr;
}

void ArchiveHost::CommitState(std::unique_ptr<arc::State> _state)
{
    if( !_state )
        return;

    // will throw away archives positioned at last item - they are useless
    if( _state->UID() < I->m_LastItemUID ) {
        const std::lock_guard<std::mutex> lock(I->m_StatesLock);
        I->m_States.emplace_back(std::move(_state));

        if( I->m_States.size() > 32 ) { // purge the latest one
            auto last = std::begin(I->m_States);
            for( auto i = std::begin(I->m_States), e = std::end(I->m_States); i != e; ++i )
                if( (*i)->UID() > (*last)->UID() )
                    last = i;
            I->m_States.erase(last);
        }
    }
}

std::expected<std::unique_ptr<arc::State>, Error> ArchiveHost::ArchiveStateForItem(const char *_filename)
{
    const uint32_t requested_item = ItemUID(_filename);
    if( requested_item == 0 )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    auto state = ClosestState(requested_item);

    if( !state ) {
        VFSFilePtr file;

        // bad-bad design decision, need to refactor this later
        if( auto wrapping = std::dynamic_pointer_cast<VFSSeqToRandomROWrapperFile>(I->m_ArFile) )
            file = wrapping->Share();
        else
            file = I->m_ArFile->Clone();

        if( !file )
            return std::unexpected(Error{Error::POSIX, ENOTSUP});

        if( !file->IsOpened() ) {
            if( const std::expected<void, Error> rc = file->Open(VFSFlags::OF_Read); !rc )
                return std::unexpected(rc.error());
        }

        auto new_state = std::make_unique<arc::State>(file, SpawnLibarchive());

        const int res = new_state->Open();
        if( res < 0 ) {
            return std::unexpected(Error{Error::POSIX, new_state->Errno()});
        }
        state = std::move(new_state);
    }
    else if( state->UID() == requested_item && !state->Consumed() ) {
        assert(state->Entry());
        return std::move(state);
    }

    bool found = false;
    char path[1024];
    strcpy(path, _filename + 1); // skip first symbol, which is '/'
    // TODO: need special case for directories

    // consider case-insensitive comparison later
    struct archive_entry *entry;
    uint32_t entry_uid = state->UID();
    while( archive_read_next_header(state->Archive(), &entry) == ARCHIVE_OK ) {
        entry_uid++;
        if( entry_uid == requested_item ) {
            found = true;
            break;
        }
    }

    if( !found )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    state->SetEntry(entry, requested_item);
    return std::move(state);
}

struct ::archive *ArchiveHost::SpawnLibarchive()
{
    archive *arc = archive_read_new();
    auto require = [](int rc) {
        if( rc != 0 )
            abort();
    };
    require(archive_read_support_filter_bzip2(arc));
    require(archive_read_support_filter_compress(arc));
    require(archive_read_support_filter_gzip(arc));
    require(archive_read_support_filter_lzip(arc));
    require(archive_read_support_filter_lzma(arc));
    require(archive_read_support_filter_xz(arc));
    require(archive_read_support_filter_uu(arc));
    require(archive_read_support_filter_rpm(arc));
    require(archive_read_support_filter_lzop(arc));
    require(archive_read_support_filter_lz4(arc));
    require(archive_read_support_filter_zstd(arc));

    require(archive_read_support_format_ar(arc));
    require(archive_read_support_format_cpio(arc));
    require(archive_read_support_format_lha(arc));
    require(archive_read_support_format_mtree(arc));
    require(archive_read_support_format_tar(arc));
    require(archive_read_support_format_xar(arc));
    require(archive_read_support_format_7zip(arc));
    require(archive_read_support_format_cab(arc));
    require(archive_read_support_format_iso9660(arc));
    require(archive_read_support_format_warc(arc));
    require(archive_read_support_format_zip(arc));
    require(archive_read_support_format_rar(arc));
    require(archive_read_support_format_rar5(arc));

    if( Config().password )
        archive_read_add_passphrase(arc, Config().password->c_str());
    return arc;
}

void ArchiveHost::ResolveSymlink(uint32_t _uid)
{
    if( !_uid || _uid >= I->m_EntryByUID.size() )
        return;

    const auto iter = I->m_Symlinks.find(_uid);
    if( iter == std::end(I->m_Symlinks) )
        return;

    const std::lock_guard<std::recursive_mutex> lock(I->m_SymlinksResolveLock);
    auto &symlink = iter->second;
    if( symlink.state != SymlinkState::Unresolved )
        return; // was resolved in race condition

    if( symlink.value == "." || symlink.value == "./" ) {
        symlink.state = SymlinkState::Loop; // special upfront treating for some weird cases
        return;
    }

    symlink.state = SymlinkState::CurrentlyResolving;
    auto make_invalid_state = at_scope_end([&] { symlink.state = SymlinkState::Invalid; });

    const std::filesystem::path &symlink_path = symlink.value;
    std::filesystem::path result_path;
    if( symlink_path.is_relative() ) {
        result_path = I->m_EntryByUID[_uid].first->full_path;

        for( const auto &i : symlink_path ) {
            if( i != "" && i != "." ) {
                if( i == ".." ) {
                    if( !result_path.has_filename() )
                        result_path = result_path.parent_path(); // "/meow/bark/" -> "/meow/bark"
                    result_path = result_path.parent_path();
                }
                else {
                    result_path /= i;
                }
            }

            const uint32_t curr_uid = ItemUID(result_path.c_str());
            if( curr_uid == _uid ) {
                make_invalid_state.disengage();
                symlink.state = SymlinkState::Loop;
                return;
            }
            if( curr_uid == 0 )
                return;

            if( auto sym_it = I->m_Symlinks.find(curr_uid); sym_it != std::end(I->m_Symlinks) ) {
                // current entry is a symlink - needs an additional processing
                const auto &s = sym_it->second;

                if( s.state == SymlinkState::CurrentlyResolving ) {
                    make_invalid_state.disengage();
                    symlink.state = SymlinkState::Loop;
                    return;
                }

                if( s.state == SymlinkState::Unresolved )
                    ResolveSymlink(s.uid);

                if( s.state != SymlinkState::Resolved ) {
                    if( s.state == SymlinkState::Loop ) {
                        // the current part is a looping symlinks, mark the original symlink as a loop as well
                        make_invalid_state.disengage();
                        symlink.state = SymlinkState::Loop;
                    }
                    return; // current part points to nowhere
                }

                result_path = s.target_path;
            }
        }
    }
    else {
        result_path = symlink_path;
    }

    const uint32_t result_uid = ItemUID(result_path.c_str());
    if( result_uid == 0 )
        return;

    make_invalid_state.disengage();
    symlink.target_path = std::move(result_path);
    symlink.target_uid = result_uid;
    symlink.state = SymlinkState::Resolved;
}

const ArchiveHost::Symlink *ArchiveHost::ResolvedSymlink(uint32_t _uid)
{
    const auto iter = I->m_Symlinks.find(_uid);
    if( iter == std::end(I->m_Symlinks) )
        return nullptr;

    if( iter->second.state == SymlinkState::Unresolved )
        ResolveSymlink(_uid);

    return &iter->second;
}

std::expected<std::string, Error> ArchiveHost::ReadSymlink(std::string_view _symlink_path,
                                                           const VFSCancelChecker & /*_cancel_checker*/)
{
    auto entry = FindEntry(_symlink_path);
    if( !entry )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    if( (entry->st.st_mode & S_IFMT) != S_IFLNK )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const auto symlink_it = I->m_Symlinks.find(entry->aruid);
    if( symlink_it == std::end(I->m_Symlinks) )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    const std::filesystem::path &val = symlink_it->second.value;
    return val.native();
}

uint32_t ArchiveHost::StatTotalFiles() const
{
    return I->m_TotalFiles;
}

uint32_t ArchiveHost::StatTotalDirs() const
{
    return I->m_TotalDirs;
}

uint32_t ArchiveHost::StatTotalRegs() const
{
    return I->m_TotalRegs;
}

std::shared_ptr<const ArchiveHost> ArchiveHost::SharedPtr() const
{
    return std::static_pointer_cast<const ArchiveHost>(Host::SharedPtr());
}

std::shared_ptr<ArchiveHost> ArchiveHost::SharedPtr()
{
    return std::static_pointer_cast<ArchiveHost>(Host::SharedPtr());
}

} // namespace nc::vfs
