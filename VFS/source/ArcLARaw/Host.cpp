// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Host.h"
#include "../Log.h"
#include <vector>
#include <VFS/VFSGenericMemReadOnlyFile.h>
#include <VFS/VFSListingInput.h>
#include <Habanero/algo.h>
#include <Utility/PathManip.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>
#include <sys/dirent.h>
#include <filesystem>

#include <iostream>

namespace nc::vfs {

const char *const ArchiveRawHost::UniqueTag = "arc_libarchive_raw";

// An arbitrary picked value, invented out of a blue. Should presumably cover reasonable uses cases
// while giving a protection about potential traps, like accidentally expanding a 100GB .gz file.
static constexpr uint64_t g_MaxBytes = 64 * 1024 * 1024;

// A filename to be used if we failed to deduce or extract it
static constexpr const char *g_LastResortFilename = "data";

// Lowercase FormC extensions supported by this VFS
static constexpr std::string_view g_ExtensionsList[] =
    {"bz2", "gz", "lz", "lz4", "lzma", "lzo", "xz", "z", "zst"};

// O(1) unordered set of the extensions
[[clang::no_destroy]] static const robin_hood::
    unordered_flat_set<std::string, RHTransparentStringHashEqual, RHTransparentStringHashEqual>
        g_ExtensionsSet(std::begin(g_ExtensionsList), std::end(g_ExtensionsList));

namespace {
struct Extracted {
    Extracted() = default;
    Extracted(int _vfs_err) : vfs_err(_vfs_err){};

    int vfs_err = VFSError::Ok;
    std::vector<std::byte> bytes;
    std::string filename;
    time_t mtime = 0;
};

} // namespace

static Extracted read_stream(const uint64_t _max_bytes,
                             const std::string &_path,
                             VFSHost &_parent,
                             const VFSCancelChecker &_cancel_checker)
{
    static constexpr size_t buf_sz = 256 * 1024;
    struct State {
        VFSFilePtr source_file;
        std::unique_ptr<std::byte[]> inbuf;
        std::unique_ptr<std::byte[]> outbuf;
        VFSCancelChecker cancel_checker;
    } st;

    int rc = 0;
    rc = _parent.CreateFile(_path.c_str(), st.source_file, _cancel_checker);
    if( rc < 0 )
        return rc;
    rc = st.source_file->Open(VFSFlags::OF_Read);
    if( rc < 0 )
        return rc;
    if( st.source_file->Size() <= 0 )
        return VFSError::ArclibFileFormat;
    if( st.source_file->GetReadParadigm() < VFSFile::ReadParadigm::Sequential )
        return VFSError::InvalidCall;

    st.inbuf = std::make_unique<std::byte[]>(buf_sz);
    st.outbuf = std::make_unique<std::byte[]>(buf_sz);
    st.cancel_checker = _cancel_checker;

    auto myread = [](struct archive *a, void *client_data, const void **buff) -> ssize_t {
        State &st = *static_cast<State *>(client_data);
        if( st.cancel_checker && st.cancel_checker() ) {
            archive_set_error(a, ECANCELED, "user-canceled");
            return ARCHIVE_FATAL;
        }
        ssize_t result = st.source_file->Read(st.inbuf.get(), buf_sz);
        if( result < 0 ) {
            archive_set_error(a, EIO, "I/O error");
            return ARCHIVE_FATAL; // handle somehow
        }
        *buff = static_cast<void *>(st.inbuf.get());
        return result;
    };

    archive *arc = archive_read_new();
    auto cleanup_arc = at_scope_end([arc] { archive_read_free(arc); });
    auto require = [](int rc) {
        if( rc != 0 )
            abort();
    };
    require(archive_read_support_filter_bzip2(arc));
    require(archive_read_support_filter_gzip(arc));
    require(archive_read_support_filter_zstd(arc));
    require(archive_read_support_filter_lzma(arc));
    require(archive_read_support_filter_lzip(arc));
    require(archive_read_support_filter_lzop(arc));
    require(archive_read_support_filter_compress(arc));
    require(archive_read_support_filter_xz(arc));
    require(archive_read_support_filter_lz4(arc));
    archive_read_support_format_raw(arc);
    archive_read_set_callback_data(arc, &st);
    archive_read_set_read_callback(arc, myread);
    int arc_rc = archive_read_open1(arc);
    if( arc_rc != ARCHIVE_OK )
        return VFSError::FromErrno(archive_errno(arc));

    if( archive_filter_code(arc, 0) == ARCHIVE_FILTER_NONE ) {
        // libarchive always supports "none" compression filter as a fallback, but in this
        // configuration it doesn't make any sense, so reject such files.
        return VFSError::ArclibFileFormat;
    }

    archive_entry *entry;
    arc_rc = archive_read_next_header(arc, &entry);
    if( arc_rc != ARCHIVE_OK )
        return VFSError::FromErrno(archive_errno(arc));

    Extracted extr;

    const auto entry_pathname = archive_entry_pathname(entry);
    if( entry_pathname != nullptr && std::string_view("data") != entry_pathname )
        extr.filename = utility::PathManip::Filename(entry_pathname);

    if( archive_entry_mtime_is_set(entry) )
        extr.mtime = archive_entry_mtime(entry);

    uint64_t total_size = 0;
    while( true ) {
        if( st.cancel_checker && st.cancel_checker() ) {
            return VFSError::Cancelled;
        }
        const ssize_t size = archive_read_data(arc, st.outbuf.get(), buf_sz);
        if( size < 0 )
            return VFSError::FromErrno(archive_errno(arc));
        if( size == 0 )
            break; // EOF?
        total_size += size;
        if( total_size > _max_bytes )
            return VFSError::FromErrno(EFBIG);
        extr.bytes.insert(extr.bytes.end(), st.outbuf.get(), st.outbuf.get() + size);
    }

    return extr;
}

class VFSArchiveRawHostConfiguration
{
public:
    std::filesystem::path path;

    const char *Tag() const noexcept { return ArchiveRawHost::UniqueTag; }

    const char *Junction() const noexcept { return path.c_str(); }

    bool operator==(const VFSArchiveRawHostConfiguration &_rhs) const noexcept
    {
        return path == _rhs.path;
    }
};

ArchiveRawHost::ArchiveRawHost(const std::string &_path,
                               const VFSHostPtr &_parent,
                               VFSCancelChecker _cancel_checker)
    : Host(_path.c_str(), _parent, UniqueTag),
      m_Configuration(VFSArchiveRawHostConfiguration{_path})
{
    Init(_cancel_checker);
}

ArchiveRawHost::ArchiveRawHost(const VFSHostPtr &_parent,
                               const VFSConfiguration &_config,
                               VFSCancelChecker _cancel_checker)
    : Host(_config.Get<VFSArchiveRawHostConfiguration>().path.c_str(), _parent, UniqueTag),
      m_Configuration(_config)
{
    Init(_cancel_checker);
}

VFSMeta ArchiveRawHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent,
                           const VFSConfiguration &_config,
                           VFSCancelChecker _cancel_checker) {
        return std::make_shared<ArchiveRawHost>(_parent, _config, _cancel_checker);
    };
    return m;
}

void ArchiveRawHost::Init(const VFSCancelChecker &_cancel_checker)
{
    const auto &path = Configuration().Get<VFSArchiveRawHostConfiguration>().path;
    auto extracted = read_stream(g_MaxBytes, path, *Parent(), _cancel_checker);
    if( extracted.vfs_err != VFSError::Ok ) {
        Log::Warn(SPDLOC,
                  "unable to open {}({}), error: {}({})",
                  path.c_str(),
                  Parent()->Tag(),
                  VFSError::FormatErrorCode(extracted.vfs_err),
                  extracted.vfs_err);
        throw VFSErrorException(extracted.vfs_err);
    }

    m_Data = std::move(extracted.bytes);
    m_Filename = extracted.filename;
    if( m_Filename.empty() )
        m_Filename = DeduceFilename(path.native());
    if( m_Filename.empty() )
        m_Filename = g_LastResortFilename;
    m_MTime.tv_nsec = 0;
    m_MTime.tv_sec = extracted.mtime;
    if( m_MTime.tv_sec == 0 ) {
        VFSStat st;
        const auto st_rc = Parent()->Stat(path.c_str(), st, Flags::None, _cancel_checker);
        if( st_rc != VFSError::Ok )
            throw VFSErrorException(st_rc);
        m_MTime = st.mtime;
    }
}

int ArchiveRawHost::CreateFile(const char *_path,
                               std::shared_ptr<VFSFile> &_target,
                               [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr || _path[0] != '/' )
        return VFSError::FromErrno(EINVAL);

    if( m_Filename != std::string_view(_path + 1) )
        return VFSError::FromErrno(ENOENT);

    _target = std::make_unique<GenericMemReadOnlyFile>(
        _path, shared_from_this(), m_Data.data(), m_Data.size());
    return VFSError::Ok;
}

int ArchiveRawHost::Stat(const char *_path,
                         VFSStat &_st,
                         [[maybe_unused]] unsigned long _flags,
                         [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr || _path[0] != '/' )
        return VFSError::FromErrno(EINVAL);

    if( m_Filename != std::string_view(_path + 1) )
        return VFSError::FromErrno(ENOENT);

    std::memset(&_st, 0, sizeof(_st));

    _st.size = m_Data.size();
    _st.meaning.size = 1;
    _st.mode_bits.reg = 1;
    _st.mode_bits.rusr = 1;
    _st.mode_bits.rgrp = 1;
    _st.meaning.mode = 1;
    _st.mtime = _st.atime = _st.ctime = _st.btime = m_MTime;
    _st.meaning.mtime = _st.meaning.atime = _st.meaning.ctime = _st.meaning.btime = 1;
    return VFSError::Ok;
}

int ArchiveRawHost::IterateDirectoryListing(
    const char *_path,
    const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    if( _path == nullptr || _path[0] != '/' || !_handler )
        return VFSError::FromErrno(EINVAL);
    if( std::string_view(_path) != "/" )
        return VFSError::FromErrno(ENOENT);

    VFSDirEnt entry;
    entry.type = VFSDirEnt::Reg;
    if( m_Filename.size() > sizeof(entry.name) - 1 )
        return VFSError::FromErrno(ENAMETOOLONG);
    strcpy(entry.name, m_Filename.c_str());
    entry.name_len = static_cast<uint16_t>(m_Filename.size());

    _handler(entry);

    return VFSError::Ok;
}

int ArchiveRawHost::FetchDirectoryListing(const char *_path,
                                          VFSListingPtr &_target,
                                          unsigned long _flags,
                                          [[maybe_unused]] const VFSCancelChecker &_cancel_checker)

{
    if( _path == nullptr || _path[0] != '/' )
        return VFSError::FromErrno(EINVAL);
    if( std::string_view(_path) != "/" )
        return VFSError::FromErrno(ENOENT);

    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = "/";
    listing_source.atimes.reset(variable_container<>::type::common);
    listing_source.mtimes.reset(variable_container<>::type::common);
    listing_source.ctimes.reset(variable_container<>::type::common);
    listing_source.btimes.reset(variable_container<>::type::common);
    ;
    listing_source.sizes.reset(variable_container<>::type::dense);

    size_t index = 0;
    if( !(_flags & VFSFlags::F_NoDotDot) ) {
        listing_source.filenames.emplace_back("..");
        listing_source.unix_types.emplace_back(DT_DIR);
        listing_source.unix_modes.emplace_back(S_IRUSR | S_IXUSR | S_IFDIR);
        listing_source.atimes.insert(index, m_MTime.tv_sec);
        listing_source.btimes.insert(index, m_MTime.tv_sec);
        listing_source.ctimes.insert(index, m_MTime.tv_sec);
        listing_source.mtimes.insert(index, m_MTime.tv_sec);
        listing_source.sizes.insert(index, m_Data.size());
        ++index;
    }

    listing_source.filenames.emplace_back(m_Filename);
    listing_source.unix_types.emplace_back(DT_REG);
    listing_source.unix_modes.emplace_back(S_IRUSR | S_IRGRP | S_IFREG);
    listing_source.atimes.insert(index, m_MTime.tv_sec);
    listing_source.btimes.insert(index, m_MTime.tv_sec);
    listing_source.ctimes.insert(index, m_MTime.tv_sec);
    listing_source.mtimes.insert(index, m_MTime.tv_sec);
    listing_source.sizes.insert(index, m_Data.size());

    _target = VFSListing::Build(std::move(listing_source));
    return 0;
}

std::string_view ArchiveRawHost::DeduceFilename(std::string_view _path) noexcept
{
    const auto filename = utility::PathManip::Filename(_path);
    if( filename.empty() )
        return {};
    const auto original_extension = utility::PathManip::Extension(filename);
    if( original_extension.empty() )
        return {};
    const auto lowercase_formc_extension =
        utility::ExtensionLowercaseComparison::Instance().ExtensionToLowercase(original_extension);
    if( !g_ExtensionsSet.contains(lowercase_formc_extension) )
        return {};
    if( lowercase_formc_extension.size() + 1 < filename.size() )
        return filename.substr(0, filename.size() - lowercase_formc_extension.size() - 1);
    else
        return {};
}

bool ArchiveRawHost::HasSupportedExtension(std::string_view _path) noexcept
{
    const auto filename = utility::PathManip::Filename(_path);
    if( filename.empty() )
        return false;
    const auto original_extension = utility::PathManip::Extension(filename);
    if( original_extension.empty() )
        return false;
    const auto lowercase_formc_extension =
        utility::ExtensionLowercaseComparison::Instance().ExtensionToLowercase(original_extension);
    return g_ExtensionsSet.contains(lowercase_formc_extension);
}

VFSConfiguration ArchiveRawHost::Configuration() const
{
    return m_Configuration;
}

} // namespace nc::vfs
