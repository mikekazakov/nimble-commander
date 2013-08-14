//
//  PanelSizeCalculator.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 16.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelSizeCalculator.h"
#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import <sys/time.h>
#import <sys/xattr.h>
#import <sys/attr.h>
#import <sys/vnode.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <unistd.h>
#import <stdlib.h>

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

// return false on error or cancellation
static bool DirectorySizeCalculateRec(char *_path,
                                         size_t _path_len,
                                         bool *_iscancelling,
                                         PanelDirectorySizeCalculate_CancelChecker _checker,
                                         dispatch_queue_t _stat_queue,
                                         int64_t *_size_stock)
{
    if(_checker())
    {
        *_iscancelling = true;
        return false;
    }

    DIR *dirp = opendir(_path);
    if( dirp == 0 )
        return false;

    dirent *entp;

    _path[_path_len] = '/';
    _path[_path_len+1] = 0;
    char *var = _path + _path_len + 1;
    
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
    {
        if(_checker())
        {
            *_iscancelling = true;
            goto cleanup;
        }
        
        if(entp->d_ino == 0) continue; // apple's documentation suggest to skip such files
        if(entp->d_namlen == 1 && entp->d_name[0] == '.') continue; // do not process self entry
        if(entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.') continue; // do not process parent entry

        memcpy(var, entp->d_name, entp->d_namlen+1);
        if(entp->d_type == DT_DIR)
        {
            DirectorySizeCalculateRec(_path,
                                      _path_len + entp->d_namlen + 1,
                                      _iscancelling,
                                      _checker,
                                      _stat_queue,
                                      _size_stock);
            if(*_iscancelling)
                goto cleanup;
        }
        else if(entp->d_type == DT_REG || entp->d_type == DT_LNK)
        {
            char *full_path = (char*) malloc(_path_len + entp->d_namlen + 2);
            memcpy(full_path, _path, _path_len + entp->d_namlen + 2);
            
            dispatch_async(_stat_queue, ^{
                if(*_iscancelling) return;

                struct stat st;
                
                if(lstat(full_path, &st) == 0)
                    *_size_stock += st.st_size;

                free(full_path);
            });
        }
    }
    
cleanup:
    closedir(dirp);
    _path[_path_len] = 0;
    return true;
}

void PanelDirectorySizeCalculate( FlexChainedStringsChunk *_dirs,
                                 const char *_root_path,
                                 bool _is_dotdot,
                                 PanelDirectorySizeCalculate_CancelChecker _checker,
                                 PanelDirectorySizeCalculate_CompletionHandler _handler)
{
    if(_checker())
        return;

    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _root_path);
    if(path[strlen(path)-1] != '/') strcat(path, "/");
    char *var = path + strlen(path);
    
    dispatch_queue_t stat_queue = dispatch_queue_create("info.filesmanager.Files.PanelDirectorySizeCalculate", 0);
    
    for(const auto &i: *_dirs)
    {
        memcpy(var, i.str(), i.len+1);
        
        int64_t total_size = 0;
        
        bool result = DirectorySizeCalculateRec(path,
                                                strlen(path),
                                                &iscancelling,
                                                _checker,
                                                stat_queue,
                                                &total_size);
        dispatch_sync(stat_queue, ^{});
        
        if(iscancelling || _checker()) // check if we need to quit
            goto cleanup;

        if(result)
            _handler(_is_dotdot?"..":i.str(), total_size);
    }
    
cleanup:
    dispatch_release(stat_queue);
    FlexChainedStringsChunk::FreeWithDescendants(&_dirs);
    free((void*)_root_path);
}