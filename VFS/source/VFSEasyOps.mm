// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <sys/dirent.h>
#include <Habanero/SerialQueue.h>
#include <Habanero/DispatchGroup.h>
#include "../include/VFS/VFSEasyOps.h"
#include "../include/VFS/VFSError.h"

using namespace nc::vfs;

static int CopyNodeAttrs(const char *_src_full_path,
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
    
    VFSStat st;
    int result = _src_host->Stat(_src_full_path, st, VFSFlags::F_NoFollow, 0);
    if(result < 0)
        return result;

    _dst_host->SetTimes(_dst_full_path,
                        st.btime.tv_sec,
                        st.mtime.tv_sec,
                        st.ctime.tv_sec,
                        st.atime.tv_sec,
                        0);
    
    return 0;
}

static int CopyFileContentsSmall(std::shared_ptr<VFSFile> _src, std::shared_ptr<VFSFile> _dst)
{
    uint64_t bufsz = 256*1024;
    char buf[bufsz];
    const uint64_t src_size = _src->Size();
    uint64_t left_read = src_size;
    ssize_t res_read = 0, total_wrote = 0;
    
    while ( (res_read = _src->Read(buf, std::min(bufsz, left_read))) > 0 )
    {
        ssize_t res_write = 0;
        while(res_read > 0)
        {
            res_write = _dst->Write(buf, res_read);
            if(res_write >= 0)
            {
                res_read -= res_write;
                total_wrote += res_write;
            }
            else
                return (int)res_write;
        }
    }
    
    if(res_read < 0)
        return (int)res_read;
    
    if(res_read == 0 && (uint64_t)total_wrote != src_size)
        return VFSError::UnexpectedEOF;

    return 0;
}

static int CopyFileContentsLarge(std::shared_ptr<VFSFile> _src, std::shared_ptr<VFSFile> _dst)
{
    DispatchGroup io;
  
    // consider using variable-sized buffers depending on underlying media
    const int buffer_size = 1024*1024; // 1Mb
    auto buffer_read  = std::make_unique<uint8_t[]>(buffer_size);
    auto buffer_write = std::make_unique<uint8_t[]>(buffer_size);

    const uint64_t src_size = _src->Size();
    uint64_t total_read = 0;
    uint64_t total_written = 0;
    int64_t  io_left_to_write = 0;
    int64_t  io_nread = 0;
    int64_t  io_nwritten = 0;

    while(true)
    {
        io.Run([&]{
            if(total_read < src_size) {
                io_nread = _src->Read(buffer_read.get(), buffer_size);
                if(io_nread >= 0)
                    total_read += io_nread;
            }
        });
    
        io.Run([&]{
            int64_t already_wrote = 0;
            while(io_left_to_write > 0) {
                io_nwritten = _dst->Write(buffer_write.get() + already_wrote, io_left_to_write);
                if(io_nwritten >= 0) {
                    already_wrote += io_nwritten;
                    io_left_to_write -= io_nwritten;
                }
                else
                    break;
            }
            total_written += already_wrote;
        });
        
        io.Wait();
    
        if(io_nread < 0)
            return (int)io_nread;
        if(io_nwritten < 0)
            return (int)io_nwritten;
    
        assert(io_left_to_write == 0); // vfs sanity check
    
        if(total_written == src_size)
            return 0;
        
        io_left_to_write = io_nread;
        
        swap(buffer_read, buffer_write);
    }
}

static int CopyFileContents(std::shared_ptr<VFSFile> _src, std::shared_ptr<VFSFile> _dst)
{
    const ssize_t small_large_tresh = 16*1024*1024; // 16mb
    
    if(_src->Size() > small_large_tresh )
        return CopyFileContentsLarge(_src, _dst);
    else
        return CopyFileContentsSmall(_src, _dst);
}

int VFSEasyCopyFile(const char *_src_full_path,
                    std::shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    std::shared_ptr<VFSHost> _dst_host
                    )
{
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       !_src_host                   ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       !_dst_host
       )
        return VFSError::InvalidCall;
    
    int result = 0;
    
    VFSFilePtr source_file, dest_file;
    result = _src_host->CreateFile(_src_full_path, source_file, 0);
    if(result != 0)
        return result;
    
    result = source_file->Open(VFSFlags::OF_Read);
    if(result != 0)
        return result;
    
    result = _dst_host->CreateFile(_dst_full_path, dest_file, 0);
    if(result != 0)
        return result;
    
    result = dest_file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist |
                             VFSFlags::OF_IRUsr | VFSFlags::OF_IWUsr | VFSFlags::OF_IRGrp);
    if(result != 0)
        return result;
    
    result = CopyFileContents(source_file, dest_file);
    if(result < 0)
        return result;

    source_file.reset();
    dest_file.reset();
    
    result = CopyNodeAttrs(_src_full_path, _src_host,
                           _dst_full_path, _dst_host);
    if(result < 0)
        return result;
    
    return 0;
}

int VFSEasyCopyDirectory(const char *_src_full_path,
                         std::shared_ptr<VFSHost> _src_host,
                         const char *_dst_full_path,
                         std::shared_ptr<VFSHost> _dst_host
                         )
{
    int result = 0;
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       !_src_host                   ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       !_dst_host
       )
        return VFSError::InvalidCall;

    if(!_src_host->IsDirectory(_src_full_path, 0, 0))
        return VFSError::InvalidCall;
    
    result = _dst_host->CreateDirectory(_dst_full_path, 0640, 0);
    if(result < 0)
        return result;
    
    result = CopyNodeAttrs(_src_full_path, _src_host,
                           _dst_full_path, _dst_host);
    if(result < 0)
        return result;
    
    result = _src_host->IterateDirectoryListing(_src_full_path, [&](const VFSDirEnt &_dirent)
    {
        std::string source(_src_full_path);
        source += '/';
        source += _dirent.name;
        
        std::string destination(_dst_full_path);
        destination += '/';
        destination += _dirent.name;

        VFSEasyCopyNode(source.c_str(),
                        _src_host,
                        destination.c_str(),
                        _dst_host
                        );
        return true;
    });
    
    if(result < 0)
        return result;

    return 0;
}

int VFSEasyCopySymlink(const char *_src_full_path,
                       std::shared_ptr<VFSHost> _src_host,
                       const char *_dst_full_path,
                       std::shared_ptr<VFSHost> _dst_host
                       )
{
    int result = 0;
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       !_src_host                   ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       !_dst_host
       )
        return VFSError::InvalidCall;
    
    char symlink_val[MAXPATHLEN];
    
    result = _src_host->ReadSymlink(_src_full_path, symlink_val, MAXPATHLEN, 0);
    if(result < 0)
        return result;
    
    result = _dst_host->CreateSymlink(_dst_full_path, symlink_val, 0);
    if(result < 0)
        return result;
    
    result = CopyNodeAttrs(_src_full_path, _src_host,
                           _dst_full_path, _dst_host);
    if(result < 0)
        return result;
    
    return 0;
}

int VFSEasyCopyNode(const char *_src_full_path,
                    std::shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    std::shared_ptr<VFSHost> _dst_host
                    )
{
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       !_src_host                   ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       !_dst_host
       )
        return VFSError::InvalidCall;
    
    VFSStat st;
    int result;
    
    result = _src_host->Stat(_src_full_path, st, VFSFlags::F_NoFollow, 0);
    if(result < 0)
        return result;
    
    switch (st.mode & S_IFMT){
        case S_IFDIR:
            return VFSEasyCopyDirectory(_src_full_path, _src_host, _dst_full_path, _dst_host);
            
        case S_IFREG:
            return VFSEasyCopyFile(_src_full_path, _src_host, _dst_full_path, _dst_host);

        case S_IFLNK:
            return VFSEasyCopySymlink(_src_full_path, _src_host, _dst_full_path, _dst_host);
    }
    
    return VFSError::GenericError;
}

int VFSEasyCompareFiles(const char *_file1_full_path,
                        std::shared_ptr<VFSHost> _file1_host,
                        const char *_file2_full_path,
                        std::shared_ptr<VFSHost> _file2_host,
                        int &_result
                        )
{
    if(_file1_full_path == nullptr    ||
       _file1_full_path[0] != '/'     ||
       !_file1_host                   ||
       _file2_full_path == nullptr    ||
       _file2_full_path[0] != '/'     ||
       !_file2_host
       )
        return VFSError::InvalidCall;
    
    int ret;
    VFSFilePtr file1, file2;
    std::optional<std::vector<uint8_t>> data1, data2;
    
    if( (ret = _file1_host->CreateFile(_file1_full_path, file1, 0)) != 0 )
        return ret;
    if( (ret = file1->Open(VFSFlags::OF_Read)) != 0 )
        return ret;
    if( !(data1 = file1->ReadFile()))
        return file1->LastError();
    
    if( (ret = _file2_host->CreateFile(_file2_full_path, file2, 0)) != 0 )
        return ret;
    if( (ret = file2->Open(VFSFlags::OF_Read)) != 0 )
        return ret;
    if( !(data2 = file2->ReadFile()) )
        return file2->LastError();
    
    if( data1->size() < data2->size() )
    {
        _result = -1;
        return 0;
    }
    if( data1->size() > data2->size() )
    {
        _result = 1;
        return 0;
    }
    
    _result = memcmp( data1->data(), data2->data(), data1->size() );
    return 0;
}

int VFSEasyDelete(const char *_full_path, const std::shared_ptr<VFSHost> &_host)
{
    VFSStat st;
    int result;
    
    result = _host->Stat(_full_path, st, VFSFlags::F_NoFollow, 0);
    if(result < 0)
        return result;
    
    if((st.mode & S_IFMT) == S_IFDIR) {
        if( !(_host->Features() & HostFeatures::NonEmptyRmDir) )
            _host->IterateDirectoryListing(_full_path, [&](const VFSDirEnt &_dirent) {
                boost::filesystem::path p = _full_path;
                p /= _dirent.name;
                VFSEasyDelete(p.native().c_str(), _host);
                return true;
            });
        return _host->RemoveDirectory(_full_path, 0);
    }
    else
        return _host->Unlink(_full_path, 0);
}

int VFSEasyCreateEmptyFile(const char *_path, const VFSHostPtr & _vfs)
{
    VFSFilePtr file;
    int ret = _vfs->CreateFile(_path, file, 0);
    if( ret != 0 )
        return ret;
    
    ret = file->Open(VFSFlags::OF_IRUsr | VFSFlags::OF_IRGrp | VFSFlags::OF_IROth |
                    VFSFlags::OF_IWUsr | VFSFlags::OF_Write | VFSFlags::OF_Create);
    if( ret != 0 )
        return ret;
    
    if( file->GetWriteParadigm() == VFSFile::WriteParadigm::Upload )
        file->SetUploadSize(0);
        
    return file->Close();
}

int VFSCompareNodes(const boost::filesystem::path& _file1_full_path,
                    const VFSHostPtr& _file1_host,
                    const boost::filesystem::path& _file2_full_path,
                    const VFSHostPtr& _file2_host,
                    int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now
    
    VFSStat st1, st2;
    int ret;
    if((ret =_file1_host->Stat(_file1_full_path.c_str(), st1, VFSFlags::F_NoFollow, 0)) < 0)
        return ret;
    
    if((ret =_file2_host->Stat(_file2_full_path.c_str(), st2, VFSFlags::F_NoFollow, 0)) < 0)
        return ret;
    
    if((st1.mode & S_IFMT) != (st2.mode & S_IFMT)) {
        _result = -1;
        return 0;
    }
    
    if( S_ISREG(st1.mode) ) {
        if(int64_t(st1.size) - int64_t(st2.size) != 0)
            _result = int(int64_t(st1.size) - int64_t(st2.size));
    }
    else if( S_ISLNK(st1.mode) ) {
        char link1[MAXPATHLEN], link2[MAXPATHLEN];
        if( (ret = _file1_host->ReadSymlink(_file1_full_path.c_str(), link1, MAXPATHLEN, 0)) < 0)
            return ret;
        if( (ret = _file2_host->ReadSymlink(_file2_full_path.c_str(), link2, MAXPATHLEN, 0)) < 0)
            return ret;
        if( strcmp(link1, link2) != 0)
            _result = strcmp(link1, link2);
    }
    else if ( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            int ret = VFSCompareNodes( _file1_full_path / _dirent.name,
                                        _file1_host,
                                        _file2_full_path / _dirent.name,
                                        _file2_host,
                                        _result);
            if(ret != 0)
                return false;
            return true;
        });
    }
    return 0;
}
