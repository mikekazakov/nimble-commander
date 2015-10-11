//
//  VFSNativeListing.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "DisplayNamesCache.h"
#import "NativeFSManager.h"
#import "VFSNativeListing.h"
#import "VFSNativeHost.h"
#import "Common.h"
#import "RoutedIO.h"

static_assert(sizeof(VFSNativeListingItem) == 136, "");
static_assert(sizeof(VFSNativeListing)==64, "");

VFSNativeListing::VFSNativeListing(const char *_path):
    VFSListing(_path, VFSNativeHost::SharedHost())
{
}

VFSNativeListing::~VFSNativeListing()
{
}

int VFSNativeListing::LoadListingData(int _flags, VFSCancelChecker _checker)
{
    assert(!m_Items);
    
    auto &io = RoutedIO::InterfaceForAccess(RelativePath(), R_OK);
    
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
    strcpy(pathwithslash, RelativePath());
    if(pathwithslash[strlen(pathwithslash)-1] != '/' ) strcat(pathwithslash, "/");

    
    vector< tuple<string, uint64_t, uint8_t > > dirents; // name, inode, entry_type
    dirents.reserve(64);
    
    while((entp = io.readdir(dirp)) != NULL) {
        if(_checker && _checker()) {
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
        
        dirents.emplace_back(string(entp->d_name, entp->d_namlen), entp->d_ino, entp->d_type);
    }
    io.closedir(dirp);
    
    m_Count = unsigned( dirents.size() + (need_to_add_dot_dot ? 1 : 0) );
    m_Items = make_unique<VFSNativeListingItem[]>( m_Count );
    
    if(need_to_add_dot_dot) {
        // ?? do we need to handle properly the usual ".." appearance, since we have a fix-up way anyhow?
        // add ".." entry by hand
        auto &current = m_Items[0];
        current.unix_type = DT_DIR;
        current.inode  = 0;
        current.name = "..";
        current.size = VFSListingItem::InvalidSize;
    }
    
    for(size_t n = 0, e = dirents.size(); n!=e; ++n ) {
        auto &i = dirents[n];
        auto &current = m_Items[n];
        current.name = move(get<0>(i));
        current.inode  = get<1>(i);
        current.unix_type = get<2>(i);
    }
    
    dirents.clear();
    dirents.shrink_to_fit();
    
    // stat files, find extenstions any any and create CFString name representations in several threads
    dispatch_apply(m_Count, dispatch_get_global_queue(0, 0), [&](size_t n) {
        if(_checker && _checker()) return;

        VFSNativeListingItem &current = m_Items[n];
        string filename = pathwithslash + current.name;
        
        // stat the file
        struct stat stat_buffer;
        if(io.stat(filename.c_str(), &stat_buffer) == 0) {
            current.atime = stat_buffer.st_atimespec.tv_sec;
            current.mtime = stat_buffer.st_mtimespec.tv_sec;
            current.ctime = stat_buffer.st_ctimespec.tv_sec;
            current.btime = stat_buffer.st_birthtimespec.tv_sec;
            current.unix_mode  = stat_buffer.st_mode;
            current.unix_flags = stat_buffer.st_flags;
            current.unix_uid   = stat_buffer.st_uid;
            current.unix_gid   = stat_buffer.st_gid;
            if( (stat_buffer.st_mode & S_IFMT) != S_IFDIR )
                current.size  = stat_buffer.st_size;
            else
                current.size = VFSListingItem::InvalidSize;
            // add other stat info here. there's a lot more
        }
        
        // parse extension if any
        // here we skip possible cases like
        // filename. and .filename
        // in such cases we think there's no extension at all
        const char *entryname = current.Name();
        for(int i = int(current.name.length()) - 2; i > 0; --i)
            if(entryname[i] == '.') {
                current.extoffset = i+1;
                break;
            }
        
        // create CFString name representation
        current.cf_name = CFStringCreateWithUTF8StdStringNoCopy(current.name);
        
        // if we're dealing with a symlink - read it's content to know the real file path
        if( current.unix_type == DT_LNK )
        {
            char linkpath[MAXPATHLEN];
            ssize_t sz = io.readlink(filename.c_str(), linkpath, MAXPATHLEN);
            if(sz != -1) {
                linkpath[sz] = 0;
                current.symlink = linkpath;
            }
            
            // stat the original file so we can extract some interesting info from it
            struct stat link_stat_buffer;
            if(io.lstat(filename.c_str(), &link_stat_buffer) == 0 &&
                (link_stat_buffer.st_flags & UF_HIDDEN) )
                current.unix_flags |= UF_HIDDEN; // current only using UF_HIDDEN flag
        }
    });

    // load display names
//    if(_flags & VFSFlags::F_LoadDisplayNames)
//        if(auto native_fs_info = NativeFSManager::Instance().VolumeFromPath(RelativePath())) {
//            auto &dnc = DisplayNamesCache::Instance();
//            lock_guard<mutex> lock(dnc);
//            for(unsigned n = 0, e = m_Count; n != e; ++n) {
//                auto &it = m_Items[n];
//                if(it.IsDir() && !it.IsDotDot()) {
//                    auto &dn = dnc.DisplayNameForNativeFS(native_fs_info->basic.fs_id,
//                                                          it.Inode(),
//                                                          RelativePath(),
//                                                          it.Name(),
//                                                          it.CFName()
//                                                          );
//                    if(dn.str != nullptr) {
//                        it.cf_displayname = dn.str;
//                        CFRetain(it.cf_displayname);
//                    }
//                }
//            }
//        }

    if(_checker && _checker())
        return VFSError::Cancelled;
    
    return VFSError::Ok;
}

VFSListingItem& VFSNativeListing::At(size_t _position)
{
    assert(_position < m_Count);
    return m_Items[_position];
}

const VFSListingItem& VFSNativeListing::At(size_t _position) const
{
    assert(_position < m_Count);
    return m_Items[_position];
}

int VFSNativeListing::Count() const
{
    return (int)m_Count;
}
