#include "DirRead.h"
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <dirent.h>
#include <stddef.h>
#include <fcntl.h>
#include <string.h>
#include <memory.h>
#include <stdlib.h>
#include <assert.h>

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

int FetchDirectoryListing(const char* _path,
                          std::deque<DirectoryEntryInformation> *_target,
                          FetchDirectoryListing_CancelChecker _checker)
{
    assert(sizeof(DirectoryEntryInformation) == 128);
    _target->clear();
        
    DIR *dirp = opendir(_path);
    if(!dirp)
        return errno;

    if(_checker && _checker())
    {
        closedir(dirp);
        return 0;
    }
    
    dirent *entp;

    bool need_to_add_dot_dot = true; // in some fancy situations there's no ".." entry in directory - we should insert it by hand
    
    char pathwithslash[__DARWIN_MAXPATHLEN]; // this buffer will be used for composing long filenames for stat()
    char *pathwithslashp = &pathwithslash[0];
    strcpy(pathwithslash, _path);
    if(_path[strlen(_path)-1] != '/' ) strcat(pathwithslash, "/");
    size_t pathwithslash_len = strlen(pathwithslash);

    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
    {
        if(_checker && _checker())
        {
            closedir(dirp);
            return 0;
        }
        
        if(entp->d_ino == 0) continue; // apple's documentation suggest to skip such files
        if(entp->d_namlen == 1 && entp->d_name[0] ==  '.') continue; // do not process self entry
        if(entp->d_namlen == 2 && entp->d_name[0] ==  '.' && entp->d_name[1] ==  '.') // special case for dot-dot directory
        {
            need_to_add_dot_dot = false;
            
            if(strcmp(_path, "/") == 0)
                continue; // skip .. for root directory

            // TODO: handle situation when ".." is not the #0 entry

            // it's very nice that sometimes OSX can not set a valid flags on ".." file in a mount point
            // so for now - just fix it by hand
            if(entp->d_type == 0)
                entp->d_type = DT_DIR; // a very-very strange bugfix
        }
        
        _target->push_back(DirectoryEntryInformation());
        
        DirectoryEntryInformation &current = _target->back();
        memset(&current, 0, sizeof(DirectoryEntryInformation));
        current.unix_type = entp->d_type;
        current.ino  = entp->d_ino;
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

    closedir(dirp);

    if(need_to_add_dot_dot)
    {
        // ?? do we need to handle properly the usual ".." appearance, since we have a fix-up way anyhow?
        // add ".." entry by hand
        DirectoryEntryInformation current;        
        memset(&current, 0, sizeof(DirectoryEntryInformation));
        current.unix_type = DT_DIR;
        current.ino  = 0;
        current.namelen = 2;
        memcpy(&current.namebuf[0], "..", current.namelen+1);
        current.size = DIRENTINFO_INVALIDSIZE;
        _target->insert(_target->begin(), current); // this can be looong on biiiiiig directories
    }

    // stat files, find extenstions any any and create CFString name representations in several threads    
    dispatch_apply(_target->size(), dispatch_get_global_queue(0, 0), ^(size_t n) {
        DirectoryEntryInformation *current = &(*_target)[n];
        if(_checker && _checker()) return;
        char filename[__DARWIN_MAXPATHLEN];
        const char *entryname = current->namec();
        memcpy(filename, pathwithslashp, pathwithslash_len);
        memcpy(filename + pathwithslash_len, entryname, current->namelen+1);
            
        // stat the file
        struct stat stat_buffer;
        if(stat(filename, &stat_buffer) == 0)
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
                current->size = DIRENTINFO_INVALIDSIZE;
            // add other stat info here. there's a lot more
        }

        // parse extension if any
        for(int i = current->namelen - 1; i >= 0; --i)
            if(entryname[i] == '.')
            {
                if(i == current->namelen - 1 || i == 0)
                    break; // degenerate case, lets think that there's no extension at all
                current->extoffset = i+1; // CHECK THIS! may be some bugs with UTF
                break;
            }
        
        // create CFString name representation
        current->cf_name = CFStringCreateWithBytesNoCopy(0,
                                                        (UInt8*)entryname,
                                                        current->namelen,
                                                        kCFStringEncodingUTF8,
                                                        false,
                                                        kCFAllocatorNull);

        // if we're dealing with a symlink - read it's content to know the real file path
        if( current->unix_type == DT_LNK )
        {
            char linkpath[__DARWIN_MAXPATHLEN];
            ssize_t sz = readlink(filename, linkpath, __DARWIN_MAXPATHLEN);
            if(sz != -1)
            {
                linkpath[sz] = 0;
                char *s = (char*)malloc(sz+1);
                memcpy(s, linkpath, sz+1);
                current->symlink = s;
            }
        }
    });

    if(_target->size() == 0)
        return -1; // something was very wrong

    return 0;
}

