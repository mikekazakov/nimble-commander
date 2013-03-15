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

int FetchDirectoryListing(const char* _path, std::deque<DirectoryEntryInformation> *_target)
{
    _target->clear();
    
    DIR *dirp = opendir(_path);
    if(!dirp)
        return -1;
    
    struct stat stat_buffer;
    dirent *entp;
    DirectoryEntryInformation current;
    int num_of_entries = 0;

    bool need_to_add_dot_dot = true; // in some fancy situations there's no ".." entry in directory - we should insert it by hand
    
    
    char full_filename[__DARWIN_MAXPATHLEN]; // this buffer will be used for composing long filenames for stat()
    strcpy(full_filename, _path);
    if(_path[strlen(_path)-1] != '/' ) strcat(full_filename, "/");
    char *full_filename_var = full_filename + strlen(full_filename);
    
    while((entp = readdir(dirp)) != NULL)
    {
        if(entp->d_ino == 0) continue;
        if(strcmp(entp->d_name, ".") == 0) continue;
        if(strcmp(entp->d_name, "..") == 0 && strcmp(_path, "/") == 0)
        {
            need_to_add_dot_dot = false;
            continue; // skip .. for root directory
        }
        ++num_of_entries;
        
        if(strcmp(entp->d_name, "..") == 0) // special case for dot-dot directory
        {
            need_to_add_dot_dot = false;
            
            // TODO: handle situation when ".." is not the #0 entry

            // it's very nice that sometimes OSX can not set a valid flags on ".." file in a mount point
            // so for now - just fix it by hand
            if(entp->d_type == 0)
                entp->d_type = DT_DIR; // a very-very strange bugfix
        }

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
        
        // stat the file
        strcpy(full_filename_var, entp->d_name);
        memset(&stat_buffer, 0, sizeof(stat_buffer));        
        if(stat(full_filename, &stat_buffer) == 0)
        {
            current.size = stat_buffer.st_size;
            current.atime = stat_buffer.st_atimespec.tv_sec;
            current.mtime = stat_buffer.st_mtimespec.tv_sec;
            current.ctime = stat_buffer.st_ctimespec.tv_sec;
            current.btime = stat_buffer.st_birthtimespec.tv_sec;
            
            // add other stat info here. there's a lot more
        }

        if(entp->d_type == DT_DIR)
            current.size = DIRENTINFO_INVALIDSIZE;

        // parse extension if any
        current.extoffset = -1;
        for(int i = entp->d_namlen - 1; i >= 0; --i)
            if(entp->d_name[i] == '.')
            {
                if(i == entp->d_namlen - 1 || i == 0)
                    break; // degenerate case, lets think that there's no extension at all
                current.extoffset = i+1; // CHECK THIS! may be some bugs with UTF
                break;
            }
        
        _target->push_back(current);
    }

    closedir(dirp);
    
    if(need_to_add_dot_dot)
    {
        // ?? do we need to handle properly the usual ".." appearance, since we have a fix-up way anyhow?
        // add ".." entry by hand
        memset(&current, 0, sizeof(DirectoryEntryInformation));
        current.type = DT_DIR;
        current.ino  = 0;
        current.namelen = 2;
        memcpy(&current.namebuf[0], "..", current.namelen+1);
        current.size = DIRENTINFO_INVALIDSIZE;
        _target->insert(_target->begin(), current); // this can be looong on biiiiiig directories
    }
    
    
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


