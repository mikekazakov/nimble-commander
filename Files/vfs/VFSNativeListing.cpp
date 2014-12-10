//
//  VFSNativeListing.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import <stddef.h>
#import <fcntl.h>
#import <string.h>
#import <memory.h>
#import <stdlib.h>

#import "DisplayNamesCache.h"
#import "NativeFSManager.h"
#import "VFSNativeListing.h"
#import "VFSNativeHost.h"
#import "Common.h"

#import "RoutedIO.h"

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

static_assert(sizeof(VFSNativeListingItem) == 128, "");

VFSNativeListing::VFSNativeListing(const char *_path, shared_ptr<VFSNativeHost> _host):
    VFSListing(_path, _host)
{
}

VFSNativeListing::~VFSNativeListing()
{
}

int VFSNativeListing::LoadListingData(int _flags, VFSCancelChecker _checker)
{
    auto &io = RoutedIO::InterfaceForAccess(RelativePath(), R_OK);
    
    m_Items.clear();
    
    DIR *dirp = io.opendir(RelativePath());
    if(!dirp)
        return VFSError::FromErrno(errno);
    
    if(_checker && _checker())
    {
        io.closedir(dirp);
        return VFSError::Cancelled;
    }
    
    dirent *entp;
    
    bool need_to_add_dot_dot = true; // in some fancy situations there's no ".." entry in directory - we should insert it by hand
    if(_flags & VFSFlags::F_NoDotDot)
        need_to_add_dot_dot = false;
    
    char pathwithslash[MAXPATHLEN]; // this buffer will be used for composing long filenames for stat()
    char *pathwithslashp = &pathwithslash[0];
    strcpy(pathwithslash, RelativePath());
    if(pathwithslash[strlen(pathwithslash)-1] != '/' ) strcat(pathwithslash, "/");
    size_t pathwithslash_len = strlen(pathwithslash);

    while((entp = io.readdir(dirp)) != NULL)
    {
        if(_checker && _checker())
        {
            io.closedir(dirp);
            return 0;
        }
        
        if(entp->d_ino == 0) continue; // apple's documentation suggest to skip such files
        if(entp->d_namlen == 1 && entp->d_name[0] ==  '.') continue; // do not process self entry
        if(entp->d_namlen == 2 && entp->d_name[0] ==  '.' && entp->d_name[1] ==  '.' ) // special case for dot-dot directory
        {
            if(_flags & VFSFlags::F_NoDotDot) continue;
            need_to_add_dot_dot = false;
            
            if(strcmp(pathwithslash, "/") == 0)
                continue; // skip .. for root directory
            
            // TODO: handle situation when ".." is not the #0 entry
            
            // it's very nice that sometimes OSX can not set a valid flags on ".." file in a mount point
            // so for now - just fix it by hand
            if(entp->d_type == 0)
                entp->d_type = DT_DIR; // a very-very strange bugfix
        }
        
        m_Items.emplace_back();
        
        VFSNativeListingItem &current = m_Items.back();
        current.unix_type = entp->d_type;
        current.inode  = entp->d_ino;
        current.namelen = entp->d_namlen;
        if(current.namelen < 14)
        {
            memcpy(&current.namebuf[0], &entp->d_name[0], current.namelen+1);
        }
        else
        {
            char *news = (char*)malloc(current.namelen+1);
            memcpy(news, &entp->d_name[0], current.namelen+1);
            *(char**)(&current.namebuf[0]) = news;
        }
    }
    
    io.closedir(dirp);
    
    if(need_to_add_dot_dot)
    {
        // ?? do we need to handle properly the usual ".." appearance, since we have a fix-up way anyhow?
        // add ".." entry by hand
        VFSNativeListingItem current = {};
        current.unix_type = DT_DIR;
        current.inode  = 0;
        current.namelen = 2;
        memcpy(&current.namebuf[0], "..", current.namelen+1);
        current.size = VFSListingItem::InvalidSize;
        m_Items.emplace_front(current);
    }
    
    // stat files, find extenstions any any and create CFString name representations in several threads
    dispatch_apply(m_Items.size(), dispatch_get_global_queue(0, 0), ^(size_t n) {
        VFSNativeListingItem *current = &m_Items[n];
        if(_checker && _checker()) return;
        char filename[MAXPATHLEN];
        const char *entryname = current->Name();
        memcpy(filename, pathwithslashp, pathwithslash_len);
        memcpy(filename + pathwithslash_len, entryname, current->namelen+1);
        
        // stat the file
        struct stat stat_buffer;
        if(io.stat(filename, &stat_buffer) == 0)
        {
            current->atime = stat_buffer.st_atimespec.tv_sec;
            current->mtime = stat_buffer.st_mtimespec.tv_sec;
            current->ctime = stat_buffer.st_ctimespec.tv_sec;
            current->btime = stat_buffer.st_birthtimespec.tv_sec;
            current->unix_mode  = stat_buffer.st_mode;
            current->unix_flags = stat_buffer.st_flags;
            current->unix_uid   = stat_buffer.st_uid;
            current->unix_gid   = stat_buffer.st_gid;
            if( (stat_buffer.st_mode & S_IFMT) != S_IFDIR )
                current->size  = stat_buffer.st_size;
            else
                current->size = VFSListingItem::InvalidSize;
            // add other stat info here. there's a lot more
        }
        
        // parse extension if any
        // here we skip possible cases like
        // filename. and .filename
        // in such cases we think there's no extension at all
        for(int i = int(current->namelen) - 2; i > 0; --i)
            if(entryname[i] == '.') {
                current->extoffset = i+1;
                break;
            }
        
        // create CFString name representation
        current->cf_name = CFStringCreateWithUTF8StringNoCopy(entryname, current->namelen);
        
        // if we're dealing with a symlink - read it's content to know the real file path
        if( current->unix_type == DT_LNK )
        {
            char linkpath[MAXPATHLEN];
            ssize_t sz = io.readlink(filename, linkpath, MAXPATHLEN);
            if(sz != -1) {
                linkpath[sz] = 0;
                char *s = (char*)malloc(sz+1);
                memcpy(s, linkpath, sz+1);
                current->symlink = s;
            }
            else {
                current->symlink = strdup("");
            }
            
            // stat the original file so we can extract some interesting info from it
            struct stat link_stat_buffer;
            if(io.lstat(filename, &link_stat_buffer) == 0 &&
                (link_stat_buffer.st_flags & UF_HIDDEN) )
                current->unix_flags |= UF_HIDDEN; // current only using UF_HIDDEN flag
        }
    });

    // load display names
    if(_flags & VFSFlags::F_LoadDisplayNames)
        if(auto native_fs_info = NativeFSManager::Instance().VolumeFromPath(RelativePath())) {
            auto &dnc = DisplayNamesCache::Instance();
            lock_guard<mutex> lock(dnc);
            for(auto &it: m_Items)
                if(it.IsDir() && !it.IsDotDot()) {
                    auto &dn = dnc.DisplayNameForNativeFS(native_fs_info->basic.fs_id,
                                                          it.Inode(),
                                                          RelativePath(),
                                                          it.Name(),
                                                          it.CFName()
                                                          );
                    if(dn.str != nullptr) {
                        it.cf_displayname = dn.str;
                        CFRetain(it.cf_displayname);
                    }
                }
        }

    if(_checker && _checker())
        return VFSError::Cancelled;
    
    return VFSError::Ok;
}

VFSListingItem& VFSNativeListing::At(size_t _position)
{
    assert(_position < m_Items.size());
    return m_Items[_position];
}

const VFSListingItem& VFSNativeListing::At(size_t _position) const
{
    assert(_position < m_Items.size());
    return m_Items[_position];
}

int VFSNativeListing::Count() const
{
    return (int)m_Items.size();
}
