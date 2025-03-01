// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSEasyOps.h"
#include "../include/VFS/VFSError.h"
#include <Base/SerialQueue.h>
#include <Base/DispatchGroup.h>
#include <Base/algo.h>
#include <Utility/PathManip.h>
#include <Utility/TemporaryFileStorage.h>
#include <sys/stat.h>
#include <sys/dirent.h>
#include <sys/xattr.h>
#include <numeric>
#include <stack>

using namespace nc;
using namespace nc::vfs;

static std::expected<void, Error> CopyNodeAttrs(const char *_src_full_path,
                                                std::shared_ptr<VFSHost> _src_host,
                                                const char *_dst_full_path,
                                                std::shared_ptr<VFSHost> _dst_host)
{
    /* copy permissions,
     owners,
     flags,
     times, <- done.
     xattrs
     and ACLs
     here. LOL!
     */

    const std::expected<VFSStat, Error> st = _src_host->Stat(_src_full_path, VFSFlags::F_NoFollow);
    if( !st )
        return std::unexpected(st.error());

    // Set times but do ignore the result for now
    std::ignore =
        _dst_host->SetTimes(_dst_full_path, st->btime.tv_sec, st->mtime.tv_sec, st->ctime.tv_sec, st->atime.tv_sec);

    return {};
}

static int CopyFileContentsSmall(std::shared_ptr<VFSFile> _src, std::shared_ptr<VFSFile> _dst)
{
    constexpr uint64_t bufsz = 256ULL * 1024ULL;
    const std::unique_ptr<char[]> buf = std::make_unique<char[]>(bufsz);
    const uint64_t src_size = _src->Size();
    const uint64_t left_read = src_size;
    ssize_t res_read = 0;
    ssize_t total_wrote = 0;

    while( (res_read = _src->Read(buf.get(), std::min(bufsz, left_read))) > 0 ) {
        ssize_t res_write = 0;
        const char *ptr = buf.get();
        while( res_read > 0 ) {
            res_write = _dst->Write(ptr, res_read);
            if( res_write >= 0 ) {
                res_read -= res_write;
                total_wrote += res_write;
                ptr += res_write;
            }
            else
                return static_cast<int>(res_write);
        }
    }

    if( res_read < 0 )
        return static_cast<int>(res_read);

    if( res_read == 0 && static_cast<uint64_t>(total_wrote) != src_size )
        return VFSError::UnexpectedEOF;

    return 0;
}

static int CopyFileContentsLarge(std::shared_ptr<VFSFile> _src, std::shared_ptr<VFSFile> _dst)
{
    const nc::base::DispatchGroup io;

    // consider using variable-sized buffers depending on underlying media
    const int buffer_size = 1024 * 1024; // 1Mb
    auto buffer_read = std::make_unique<uint8_t[]>(buffer_size);
    auto buffer_write = std::make_unique<uint8_t[]>(buffer_size);

    const uint64_t src_size = _src->Size();
    uint64_t total_read = 0;
    uint64_t total_written = 0;
    int64_t io_left_to_write = 0;
    int64_t io_nread = 0;
    int64_t io_nwritten = 0;

    while( true ) {
        io.Run([&] {
            if( total_read < src_size ) {
                io_nread = _src->Read(buffer_read.get(), buffer_size);
                if( io_nread >= 0 )
                    total_read += io_nread;
            }
        });

        io.Run([&] {
            int64_t already_wrote = 0;
            while( io_left_to_write > 0 ) {
                io_nwritten = _dst->Write(buffer_write.get() + already_wrote, io_left_to_write);
                if( io_nwritten >= 0 ) {
                    already_wrote += io_nwritten;
                    io_left_to_write -= io_nwritten;
                }
                else
                    break;
            }
            total_written += already_wrote;
        });

        io.Wait();

        if( io_nread < 0 )
            return static_cast<int>(io_nread);
        if( io_nwritten < 0 )
            return static_cast<int>(io_nwritten);

        assert(io_left_to_write == 0); // vfs sanity check

        if( total_written == src_size )
            return 0;

        io_left_to_write = io_nread;

        std::swap(buffer_read, buffer_write);
    }
}

static int CopyFileContents(std::shared_ptr<VFSFile> _src, std::shared_ptr<VFSFile> _dst)
{
    const ssize_t small_large_tresh = 16LL * 1024LL * 1024LL; // 16mb

    if( _src->Size() > small_large_tresh )
        return CopyFileContentsLarge(_src, _dst);
    else
        return CopyFileContentsSmall(_src, _dst);
}

int VFSEasyCopyFile(const char *_src_full_path,
                    std::shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    std::shared_ptr<VFSHost> _dst_host)
{
    if( _src_full_path == nullptr || _src_full_path[0] != '/' || !_src_host || _dst_full_path == nullptr ||
        _dst_full_path[0] != '/' || !_dst_host )
        return VFSError::InvalidCall;

    int result = 0;

    {
        const std::expected<std::shared_ptr<VFSFile>, nc::Error> source_file = _src_host->CreateFile(_src_full_path);
        if( !source_file )
            return VFSError::GenericError; // TODO: return source_file

        result = (*source_file)->Open(VFSFlags::OF_Read);
        if( result != 0 )
            return result;

        const std::expected<std::shared_ptr<VFSFile>, nc::Error> dest_file = _dst_host->CreateFile(_dst_full_path);
        if( !dest_file )
            return VFSError::GenericError; // TODO: return dest_file

        result = (*dest_file)
                     ->Open(VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist | VFSFlags::OF_IRUsr |
                            VFSFlags::OF_IWUsr | VFSFlags::OF_IRGrp);
        if( result != 0 )
            return result;

        result = CopyFileContents(*source_file, *dest_file);
        if( result < 0 )
            return result;
    }

    const std::expected<void, Error> attrs_rc = CopyNodeAttrs(_src_full_path, _src_host, _dst_full_path, _dst_host);
    if( !attrs_rc )
        return VFSError::GenericError; // TODO: return attrs_rc

    return 0;
}

int VFSEasyCopyDirectory(const char *_src_full_path,
                         std::shared_ptr<VFSHost> _src_host,
                         const char *_dst_full_path,
                         std::shared_ptr<VFSHost> _dst_host)
{

    if( _src_full_path == nullptr || _src_full_path[0] != '/' || !_src_host || _dst_full_path == nullptr ||
        _dst_full_path[0] != '/' || !_dst_host )
        return VFSError::InvalidCall;

    if( !_src_host->IsDirectory(_src_full_path, 0, nullptr) )
        return VFSError::InvalidCall;

    if( const std::expected<void, nc::Error> rc = _dst_host->CreateDirectory(_dst_full_path, 0740); !rc )
        return VFSError::GenericError; // TODO: return rc

    const std::expected<void, Error> attrs_rc = CopyNodeAttrs(_src_full_path, _src_host, _dst_full_path, _dst_host);
    if( !attrs_rc )
        return VFSError::GenericError; // TODO: return attrs_rc

    const std::expected<void, Error> it_rc =
        _src_host->IterateDirectoryListing(_src_full_path, [&](const VFSDirEnt &_dirent) {
            std::string source(_src_full_path);
            source += '/';
            source += _dirent.name;

            std::string destination(_dst_full_path);
            destination += '/';
            destination += _dirent.name;

            VFSEasyCopyNode(source.c_str(), _src_host, destination.c_str(), _dst_host);
            return true;
        });

    if( !it_rc )
        return VFSError::GenericError; // TODO: return it_rc

    return 0;
}

int VFSEasyCopySymlink(const char *_src_full_path,
                       std::shared_ptr<VFSHost> _src_host,
                       const char *_dst_full_path,
                       std::shared_ptr<VFSHost> _dst_host)
{
    if( _src_full_path == nullptr || _src_full_path[0] != '/' || !_src_host || _dst_full_path == nullptr ||
        _dst_full_path[0] != '/' || !_dst_host )
        return VFSError::InvalidCall;

    const std::expected<std::string, nc::Error> symlink = _src_host->ReadSymlink(_src_full_path);
    if( !symlink )
        return VFSError::FromErrno(EINVAL); // TODO: use symlink instead

    if( const std::expected<void, nc::Error> rc = _dst_host->CreateSymlink(_dst_full_path, *symlink); !rc )
        return VFSError::FromErrno(EINVAL); // TODO: use rc instead

    const std::expected<void, Error> attrs_rc = CopyNodeAttrs(_src_full_path, _src_host, _dst_full_path, _dst_host);
    if( !attrs_rc )
        return VFSError::GenericError; // TODO: return attrs_rc

    return 0;
}

int VFSEasyCopyNode(const char *_src_full_path,
                    std::shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    std::shared_ptr<VFSHost> _dst_host)
{
    if( _src_full_path == nullptr || _src_full_path[0] != '/' || !_src_host || _dst_full_path == nullptr ||
        _dst_full_path[0] != '/' || !_dst_host )
        return VFSError::InvalidCall;

    const std::expected<VFSStat, Error> st = _src_host->Stat(_src_full_path, VFSFlags::F_NoFollow);
    if( !st )
        return VFSError::GenericError; // TODO: return st

    switch( st->mode & S_IFMT ) {
        case S_IFDIR:
            return VFSEasyCopyDirectory(_src_full_path, _src_host, _dst_full_path, _dst_host);

        case S_IFREG:
            return VFSEasyCopyFile(_src_full_path, _src_host, _dst_full_path, _dst_host);

        case S_IFLNK:
            return VFSEasyCopySymlink(_src_full_path, _src_host, _dst_full_path, _dst_host);

        default:
            return VFSError::GenericError;
    }
}

std::expected<int, nc::Error> VFSEasyCompareFiles(const char *_file1_full_path,
                                                  std::shared_ptr<VFSHost> _file1_host,
                                                  const char *_file2_full_path,
                                                  std::shared_ptr<VFSHost> _file2_host)
{
    if( _file1_full_path == nullptr || _file1_full_path[0] != '/' || !_file1_host || _file2_full_path == nullptr ||
        _file2_full_path[0] != '/' || !_file2_host )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::expected<VFSFilePtr, nc::Error> file1 = _file1_host->CreateFile(_file1_full_path);
    if( !file1 )
        return std::unexpected(file1.error());

    if( const int ret = (*file1)->Open(VFSFlags::OF_Read); ret != 0 )
        return std::unexpected(VFSError::ToError(ret));

    const std::expected<std::vector<uint8_t>, nc::Error> data1 = (*file1)->ReadFile();
    if( !data1 )
        return std::unexpected(data1.error());

    const std::expected<VFSFilePtr, nc::Error> file2 = _file2_host->CreateFile(_file2_full_path);
    if( !file2 )
        return std::unexpected(file2.error());

    if( const int ret = (*file2)->Open(VFSFlags::OF_Read); ret != 0 )
        return std::unexpected(VFSError::ToError(ret));

    const std::expected<std::vector<uint8_t>, nc::Error> data2 = (*file2)->ReadFile();
    if( !data2 )
        return std::unexpected(data2.error());

    if( data1->size() < data2->size() ) {
        return -1;
    }
    else if( data1->size() > data2->size() ) {
        return 1;
    }
    else {
        return memcmp(data1->data(), data2->data(), data1->size());
    }
}

std::expected<void, nc::Error> VFSEasyDelete(const char *_full_path, const std::shared_ptr<VFSHost> &_host)
{
    const std::expected<VFSStat, Error> st = _host->Stat(_full_path, VFSFlags::F_NoFollow);
    if( !st )
        return std::unexpected(st.error());

    if( (st->mode & S_IFMT) == S_IFDIR ) {
        if( !(_host->Features() & HostFeatures::NonEmptyRmDir) ) {
            std::ignore = _host->IterateDirectoryListing(_full_path, [&](const VFSDirEnt &_dirent) {
                std::filesystem::path p = _full_path;
                p /= _dirent.name;
                std::ignore = VFSEasyDelete(p.native().c_str(), _host); // TODO: why the return status is ignored?
                return true;
            });
        }
        return _host->RemoveDirectory(_full_path);
    }
    else {
        return _host->Unlink(_full_path);
    }
}

int VFSEasyCreateEmptyFile(const char *_path, const VFSHostPtr &_vfs)
{
    const std::expected<VFSFilePtr, nc::Error> efile = _vfs->CreateFile(_path);
    if( !efile )
        return VFSError::GenericError; // TODO: return efile
    VFSFile &file = **efile;

    const int ret = file.Open(VFSFlags::OF_IRUsr | VFSFlags::OF_IRGrp | VFSFlags::OF_IROth | VFSFlags::OF_IWUsr |
                              VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist);
    if( ret != 0 )
        return ret;

    if( file.GetWriteParadigm() == VFSFile::WriteParadigm::Upload )
        file.SetUploadSize(0);

    return file.Close();
}

int VFSCompareNodes(const std::filesystem::path &_file1_full_path,
                    const VFSHostPtr &_file1_host,
                    const std::filesystem::path &_file2_full_path,
                    const VFSHostPtr &_file2_host,
                    int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now

    const std::expected<VFSStat, Error> st1 = _file1_host->Stat(_file1_full_path.c_str(), VFSFlags::F_NoFollow);
    if( !st1 )
        return VFSError::GenericError; // TODO: return st1

    const std::expected<VFSStat, Error> st2 = _file2_host->Stat(_file2_full_path.c_str(), VFSFlags::F_NoFollow);
    if( !st2 )
        return VFSError::GenericError; // TODO: return st2

    if( (st1->mode & S_IFMT) != (st2->mode & S_IFMT) ) {
        _result = -1;
        return 0;
    }

    if( S_ISREG(st1->mode) ) {
        if( int64_t(st1->size) - int64_t(st2->size) != 0 )
            _result = int(int64_t(st1->size) - int64_t(st2->size));
    }
    else if( S_ISLNK(st1->mode) ) {
        const std::expected<std::string, nc::Error> link1 = _file1_host->ReadSymlink(_file1_full_path.c_str());
        if( !link1 )
            return VFSError::FromErrno(EINVAL); // TODO: use link1 instead

        const std::expected<std::string, nc::Error> link2 = _file2_host->ReadSymlink(_file2_full_path.c_str());
        if( !link2 )
            return VFSError::FromErrno(EINVAL); // TODO: use link2 instead

        if( strcmp(link1->c_str(), link2->c_str()) != 0 )
            _result = strcmp(link1->c_str(), link2->c_str());
    }
    else if( S_ISDIR(st1->mode) ) {
        std::ignore = _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            const int ret = VFSCompareNodes(
                _file1_full_path / _dirent.name, _file1_host, _file2_full_path / _dirent.name, _file2_host, _result);
            return ret == 0;
        });
    }
    return 0;
}

namespace nc::vfs::easy {

std::optional<std::string> CopyFileToTempStorage(const std::string &_vfs_filepath,
                                                 VFSHost &_host,
                                                 nc::utility::TemporaryFileStorage &_temp_storage,
                                                 const std::function<bool()> &_cancel_checker)
{
    const std::expected<VFSFilePtr, nc::Error> evfs_file = _host.CreateFile(_vfs_filepath, _cancel_checker);
    if( !evfs_file )
        return std::nullopt; // TODO: return vfs_file;
    VFSFile &vfs_file = **evfs_file;

    if( vfs_file.Open(VFSFlags::OF_Read, _cancel_checker) < 0 )
        return std::nullopt;

    const std::string_view name = utility::PathManip::Filename(_vfs_filepath);
    if( name.empty() )
        return std::nullopt;

    auto native_file = _temp_storage.OpenFile(name);
    if( native_file == std::nullopt )
        return std::nullopt;
    auto do_unlink = at_scope_end([&] { unlink(native_file->path.c_str()); });

    constexpr size_t bufsz = 256ULL * 1024ULL;
    std::unique_ptr<char[]> buf = std::make_unique<char[]>(bufsz);
    ssize_t res_read;
    while( (res_read = vfs_file.Read(buf.get(), bufsz)) > 0 ) {
        ssize_t res_write;
        auto bufp = &buf[0];
        while( res_read > 0 ) {
            res_write = write(native_file->file_descriptor, bufp, res_read);
            if( res_write >= 0 ) {
                res_read -= res_write;
                bufp += res_write;
            }
            else
                return std::nullopt;
        }
    }
    if( res_read < 0 )
        return std::nullopt;

    vfs_file.XAttrIterateNames([&](const char *_name) {
        const ssize_t res = vfs_file.XAttrGet(_name, buf.get(), bufsz);
        if( res >= 0 )
            fsetxattr(native_file->file_descriptor, _name, buf.get(), res, 0, 0);
        return true;
    });

    do_unlink.disengage();
    return std::move(native_file->path);
}

namespace {

struct TraversedFSEntry {
    std::string src_full_path;
    std::string rel_path;
    VFSStat st;
};

} // namespace

static std::optional<std::vector<TraversedFSEntry>>
Traverse(const std::string &_vfs_dirpath, VFSHost &_host, const std::function<bool()> &_cancel_checker)
{
    auto vfs_dirpath = EnsureNoTrailingSlash(_vfs_dirpath);

    const std::expected<VFSStat, Error> st_src_dir = _host.Stat(vfs_dirpath, VFSFlags::F_NoFollow, _cancel_checker);
    if( !st_src_dir )
        return {};

    if( !st_src_dir->mode_bits.dir )
        return {};

    const auto top_level_name = std::filesystem::path{vfs_dirpath}.filename().native();

    std::vector<TraversedFSEntry> result;
    std::stack<TraversedFSEntry> traverse;

    result.emplace_back(TraversedFSEntry{.src_full_path = vfs_dirpath, .rel_path = top_level_name, .st = *st_src_dir});
    traverse.push(result.back());

    while( !traverse.empty() ) {
        auto current = std::move(traverse.top());
        traverse.pop();

        const auto block = [&](const VFSDirEnt &_dirent) -> bool {
            if( _cancel_checker && _cancel_checker() )
                return false;

            auto full_entry_path = current.src_full_path + "/" + _dirent.name;
            const std::expected<VFSStat, Error> st = _host.Stat(full_entry_path, VFSFlags::F_NoFollow, _cancel_checker);
            if( !st )
                return false;

            result.emplace_back(TraversedFSEntry{
                .src_full_path = full_entry_path, .rel_path = current.rel_path + "/" + _dirent.name, .st = *st});
            if( st->mode_bits.dir )
                traverse.push(result.back());

            return true;
        };

        if( !_host.IterateDirectoryListing(current.src_full_path, block) )
            return {};
    }

    return result;
}

static size_t CalculateSumOfRegEntriesSizes(const std::vector<TraversedFSEntry> &_entries)
{
    return std::accumulate(_entries.begin(), _entries.end(), size_t(0), [](const auto &lhs, const auto &rhs) {
        return S_ISREG(rhs.st.mode) ? (rhs.st.size + lhs) : lhs;
    });
}

static int ExtractRegFile(const std::string &_vfs_path,
                          VFSHost &_host,
                          const std::string &_native_path,
                          const std::function<bool()> &_cancel_checker)
{
    const std::expected<VFSFilePtr, nc::Error> efile = _host.CreateFile(_vfs_path, _cancel_checker);
    if( !efile )
        return VFSError::GenericError; // TODO: return evfs_file
    VFSFile &file = **efile;

    const auto open_file_rc = file.Open(VFSFlags::OF_Read, _cancel_checker);
    if( open_file_rc != VFSError::Ok )
        return open_file_rc;

    const auto fd = open(_native_path.c_str(), O_EXLOCK | O_NONBLOCK | O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if( fd < 0 )
        return VFSError::FromErrno();
    const auto close_fd = at_scope_end([&] { close(fd); });

    auto unlink_file = at_scope_end([&] { unlink(_native_path.c_str()); });

    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);

    constexpr size_t bufsz = 256ULL * 1024ULL;
    std::unique_ptr<char[]> buf = std::make_unique<char[]>(bufsz);
    ssize_t res_read;
    while( (res_read = file.Read(buf.get(), bufsz)) > 0 ) {
        while( res_read > 0 ) {
            const ssize_t res_write = write(fd, buf.get(), res_read);
            if( res_write >= 0 )
                res_read -= res_write;
            else {
                return static_cast<int>(res_write);
            }
        }
    }
    if( res_read < 0 ) {
        return static_cast<int>(res_read);
    }

    file.XAttrIterateNames([&](const char *name) -> bool {
        const ssize_t res = file.XAttrGet(name, buf.get(), bufsz);
        if( res >= 0 )
            fsetxattr(fd, name, buf.get(), res, 0, 0);
        return true;
    });

    unlink_file.disengage();
    return VFSError::Ok;
}

static bool ExtractEntry(const TraversedFSEntry &_entry,
                         VFSHost &_host,
                         const std::string &_base_path,
                         const std::function<bool()> &_cancel_checker)
{
    assert(utility::PathManip::HasTrailingSlash(_base_path));

    const auto target_tmp_path = _base_path + _entry.rel_path;

    if( _entry.st.mode_bits.dir ) {
        // directory
        if( mkdir(target_tmp_path.c_str(), 0700) != 0 )
            return false;
    }
    else {
        // reg file
        const auto rc = ExtractRegFile(_entry.src_full_path, _host, target_tmp_path, _cancel_checker);
        if( rc != VFSError::Ok )
            return false;
    }
    // NB! no special types like symlinks are processed at the moment
    return true;
}

std::optional<std::string> CopyDirectoryToTempStorage(const std::string &_vfs_dirpath,
                                                      VFSHost &_host,
                                                      uint64_t _max_total_size,
                                                      nc::utility::TemporaryFileStorage &_temp_storage,
                                                      const std::function<bool()> &_cancel_checker)
{
    const auto traversed = Traverse(_vfs_dirpath, _host, _cancel_checker);
    if( traversed == std::nullopt )
        return {};

    const auto total_size = CalculateSumOfRegEntriesSizes(*traversed);
    if( total_size > _max_total_size )
        return {};

    assert(traversed->empty() == false);

    auto tmp_dir = _temp_storage.MakeDirectory(traversed->front().rel_path);
    if( tmp_dir == std::nullopt )
        return {};

    const auto base_path = EnsureTrailingSlash(std::filesystem::path{*tmp_dir}.parent_path().parent_path().native());

    for( auto i = std::next(traversed->begin()), e = traversed->end(); i != e; ++i ) {
        if( _cancel_checker && _cancel_checker() )
            return {};

        const auto &entry = *i;

        if( !ExtractEntry(entry, _host, base_path, _cancel_checker) )
            return {};
    }

    return tmp_dir;
}

} // namespace nc::vfs::easy
