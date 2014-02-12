//
//  VFSEasyOps.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <sys/stat.h>
#import <sys/dirent.h>
#import "VFSEasyOps.h"
#import "VFSError.h"
#import "path_manip.h"
#import "DispatchQueue.h"

#import "Common.h"

static int CopyNodeAttrs(const char *_src_full_path,
                         shared_ptr<VFSHost> _src_host,
                         const char *_dst_full_path,
                         shared_ptr<VFSHost> _dst_host)
{
    /* copy permissions,
     owners,
     flags,
     times, <- done.
     xattrs
     and ACLs
     here. LOL!
     */
    
    struct stat st;
    int result = _src_host->Stat(_src_full_path, st, VFSHost::F_NoFollow, 0);
    if(result < 0)
        return result;

    _dst_host->SetTimes(_dst_full_path,
                        VFSHost::F_NoFollow,
                        &st.st_birthtimespec,
                        &st.st_mtimespec,
                        &st.st_ctimespec,
                        &st.st_atimespec,
                        0);
    
    return 0;
}

static int CopyFileContentsSmall(shared_ptr<VFSFile> _src, shared_ptr<VFSFile> _dst)
{
    uint64_t bufsz = 256*1024;
    char buf[bufsz];
    const uint64_t src_size = _src->Size();
    uint64_t left_read = src_size;
    ssize_t res_read = 0, total_wrote = 0;
    
    while ( (res_read = _src->Read(buf, min(bufsz, left_read))) > 0 )
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
    
    if(res_read == 0 && total_wrote != src_size)
        return VFSError::UnexpectedEOF;

    return 0;
}

static int CopyFileContentsLarge(shared_ptr<VFSFile> _src, shared_ptr<VFSFile> _dst)
{
    DispatchGroup io;
  
    // consider using variable-sized buffers depending on underlying media
    const int buffer_size = 1024*1024; // 1Mb
    __block unique_ptr<uint8_t[]> buffer_read(new uint8_t[buffer_size]),
                                  buffer_write(new uint8_t[buffer_size]);

    const uint64_t src_size = _src->Size();
    __block uint64_t total_read = 0;
    __block uint64_t total_written = 0;
    __block int64_t io_left_to_write = 0;
    __block int64_t io_nread = 0;
    __block int64_t io_nwritten = 0;

    while(true)
    {
        io.Run(^{
            if(total_read < src_size) {
                io_nread = _src->Read(buffer_read.get(), buffer_size);
                if(io_nread >= 0)
                    total_read += io_nread;
            }
        });
    
        io.Run(^{
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

static int CopyFileContents(shared_ptr<VFSFile> _src, shared_ptr<VFSFile> _dst)
{
    const uint64_t small_large_tresh = 16*1024*1024; // 16mb
    
    if(_src->Size() > small_large_tresh )
        return CopyFileContentsLarge(_src, _dst);
    else
        return CopyFileContentsSmall(_src, _dst);
}

int VFSEasyCopyFile(const char *_src_full_path,
                    shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    shared_ptr<VFSHost> _dst_host
                    )
{
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       _src_host == false           ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       _dst_host == false
       )
        return VFSError::InvalidCall;
    
    int result = 0;
    
    shared_ptr<VFSFile> source_file, dest_file;
    result = _src_host->CreateFile(_src_full_path, &source_file, 0);
    if(result != 0)
        return result;
    
    result = source_file->Open(VFSFile::OF_Read);
    if(result != 0)
        return result;
    
    result = _dst_host->CreateFile(_dst_full_path, &dest_file, 0);
    if(result != 0)
        return result;
    
    result = dest_file->Open(VFSFile::OF_Write | VFSFile::OF_Create | VFSFile::OF_NoExist);
    if(result != 0)
        return result;
    
    result = CopyFileContents(source_file, dest_file);
    if(result < 0)
        return result;
    
    result = CopyNodeAttrs(_src_full_path, _src_host,
                           _dst_full_path, _dst_host);
    if(result < 0)
        return result;
    
    return 0;
}

int VFSEasyCopyDirectory(const char *_src_full_path,
                         shared_ptr<VFSHost> _src_host,
                         const char *_dst_full_path,
                         shared_ptr<VFSHost> _dst_host
                         )
{
    int result = 0;
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       _src_host == false           ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       _dst_host == false
       )
        return VFSError::InvalidCall;

    if(!_src_host->IsDirectory(_src_full_path, 0, 0))
        return VFSError::InvalidCall;
    
    result = _dst_host->CreateDirectory(_dst_full_path, 0);
    if(result < 0)
        return result;
    
    result = CopyNodeAttrs(_src_full_path, _src_host,
                           _dst_full_path, _dst_host);
    if(result < 0)
        return result;
    
    result = _src_host->IterateDirectoryListing(_src_full_path, ^bool(const VFSDirEnt &_dirent)
    {
        string source(_src_full_path);
        source += '/';
        source += _dirent.name;
        
        string destination(_dst_full_path);
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
                       shared_ptr<VFSHost> _src_host,
                       const char *_dst_full_path,
                       shared_ptr<VFSHost> _dst_host
                       )
{
    int result = 0;
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       _src_host == false           ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       _dst_host == false
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
                    shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    shared_ptr<VFSHost> _dst_host
                    )
{
    if(_src_full_path == nullptr    ||
       _src_full_path[0] != '/'     ||
       _src_host == false           ||
       _dst_full_path == nullptr    ||
       _dst_full_path[0] != '/'     ||
       _dst_host == false
       )
        return VFSError::InvalidCall;
    
    struct stat st;
    int result;
    
    result = _src_host->Stat(_src_full_path, st, VFSHost::F_NoFollow, 0);
    if(result < 0)
        return result;
    
    switch (st.st_mode & S_IFMT){
        case S_IFDIR:
            return VFSEasyCopyDirectory(_src_full_path, _src_host, _dst_full_path, _dst_host);
            
        case S_IFREG:
            return VFSEasyCopyFile(_src_full_path, _src_host, _dst_full_path, _dst_host);

        case S_IFLNK:
            return VFSEasyCopySymlink(_src_full_path, _src_host, _dst_full_path, _dst_host);
    }
    
    return VFSError::GenericError;
}
