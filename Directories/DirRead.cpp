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

int FetchDirectoryListing(const char* _path, std::deque<DirectoryEntryInformation> *_target)
{
    _target->clear();
        
    DIR *dirp = opendir(_path);
    if(!dirp)
        return -1;
    
    dirent *entp;
    int num_of_entries = 0;

    bool need_to_add_dot_dot = true; // in some fancy situations there's no ".." entry in directory - we should insert it by hand
    
    char pathwithslash[__DARWIN_MAXPATHLEN]; // this buffer will be used for composing long filenames for stat()
    char *pathwithslashp = &pathwithslash[0];
    strcpy(pathwithslash, _path);
    if(_path[strlen(_path)-1] != '/' ) strcat(pathwithslash, "/");
    size_t pathwithslash_len = strlen(pathwithslash);

    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
    {
        if(entp->d_ino == 0) continue; // apple's documentation suggest to skip such files
        if(entp->d_namlen == 1 && strcmp(entp->d_name, ".") == 0) continue;
        if(entp->d_namlen == 2 && strcmp(entp->d_name, "..") == 0 && strcmp(_path, "/") == 0)
        {
            need_to_add_dot_dot = false;
            continue; // skip .. for root directory
        }
        ++num_of_entries;
        
        if(entp->d_namlen == 2 && strcmp(entp->d_name, "..") == 0) // special case for dot-dot directory
        {
            need_to_add_dot_dot = false;
            
            // TODO: handle situation when ".." is not the #0 entry

            // it's very nice that sometimes OSX can not set a valid flags on ".." file in a mount point
            // so for now - just fix it by hand
            if(entp->d_type == 0)
                entp->d_type = DT_DIR; // a very-very strange bugfix
        }
        
        _target->push_back(DirectoryEntryInformation());
        
        DirectoryEntryInformation &current = _target->back();
        memset(&current, 0, sizeof(DirectoryEntryInformation));
        current.type = entp->d_type;
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
        current.type = DT_DIR;
        current.ino  = 0;
        current.namelen = 2;
        memcpy(&current.namebuf[0], "..", current.namelen+1);
        current.size = DIRENTINFO_INVALIDSIZE;
        _target->insert(_target->begin(), current); // this can be looong on biiiiiig directories
    }

    // stat files, find extenstions any any and create CFString name representations in several threads
    
    dispatch_group_t statg = dispatch_group_create();
    dispatch_queue_t statq = dispatch_queue_create(0, DISPATCH_QUEUE_CONCURRENT);

    auto i = _target->begin(), e = _target->end();
    for(;i<e;++i)
    {
        DirectoryEntryInformation *current = &(*i);
        
        dispatch_group_async(statg, statq, ^{
            char filename[__DARWIN_MAXPATHLEN];
            memcpy(filename, pathwithslashp, pathwithslash_len);
            memcpy(filename + pathwithslash_len, current->namec(), current->namelen+1);
            
            // stat the file
            struct stat stat_buffer;
            if(stat(filename, &stat_buffer) == 0)
            {
                current->atime = stat_buffer.st_atimespec.tv_sec;
                current->mtime = stat_buffer.st_mtimespec.tv_sec;
                current->ctime = stat_buffer.st_ctimespec.tv_sec;
                current->btime = stat_buffer.st_birthtimespec.tv_sec;
                current->mode  = stat_buffer.st_mode;
                if( (stat_buffer.st_mode & S_IFMT) != S_IFDIR )
                    current->size  = stat_buffer.st_size;
                else
                    current->size = DIRENTINFO_INVALIDSIZE;
                    
                // add other stat info here. there's a lot more
            }

            // parse extension if any
            const char* s = current->namec();
            current->extoffset = -1;
            for(int i = current->namelen - 1; i >= 0; --i)
                if(s[i] == '.')
                {
                    if(i == current->namelen - 1 || i == 0)
                        break; // degenerate case, lets think that there's no extension at all
                    current->extoffset = i+1; // CHECK THIS! may be some bugs with UTF
                    break;
                }

            // create CFString name representation
            current->cf_name = CFStringCreateWithBytesNoCopy(0,
                                                            (UInt8*)current->name(),
                                                            current->namelen,
                                                            kCFStringEncodingUTF8,
                                                            false,
                                                            kCFAllocatorNull);

            // if we're dealing with a symlink - read it's content to know the real file path
            if( current->type == DT_LNK )
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
    }

    dispatch_group_wait(statg, DISPATCH_TIME_FOREVER);

    if(num_of_entries == 0)
        return -1; // something was very wrong

    return 0;
}

CFStringRef FileNameFromDirectoryEntryInformation(const DirectoryEntryInformation& _dirent)
{
    CFStringRef s = CFStringCreateWithBytes(0,
                                                  (UInt8*)_dirent.name(),
                                                  _dirent.namelen,
                                                  kCFStringEncodingUTF8,
                                                  false
                                            );
    return s;
}

CFStringRef FileNameNoCopyFromDirectoryEntryInformation(const DirectoryEntryInformation& _dirent)
{
    CFStringRef s = CFStringCreateWithBytesNoCopy(0,
                                                  (UInt8*)_dirent.name(),
                                                  _dirent.namelen,
                                                  kCFStringEncodingUTF8,
                                                  false,
                                                  kCFAllocatorNull);
    return s;
}


