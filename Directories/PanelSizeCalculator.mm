//
//  PanelSizeCalculator.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 16.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelSizeCalculator.h"
#import "PanelController.h"
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

// return -1 on error
static int64_t DirectorySizeCalculateRec(char *_path, size_t _path_len, bool *_iscancelling, PanelController *_panel)
{
    if(_panel.isStopDirectorySizeCounting)
    {
        *_iscancelling = true;
        return -1;
    }

    DIR *dirp = opendir(_path);
    if( dirp == 0 )
        return -1;

    int64_t mysize = 0;
    dirent *entp;

    _path[_path_len] = '/';
    _path[_path_len+1] = 0;
    char *var = _path + _path_len + 1;
    
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
    {
        if(_panel.isStopDirectorySizeCounting)
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
            int64_t ret = DirectorySizeCalculateRec(_path, _path_len + entp->d_namlen + 1, _iscancelling, _panel);
            if(ret > 0 )
                mysize += ret;
            if(*_iscancelling)
                goto cleanup;
        }
        else if(entp->d_type == DT_REG || entp->d_type == DT_LNK)
        {
            struct stat st;
            if(lstat(_path, &st) == 0)
                mysize += st.st_size;
        }
    }
    
cleanup:
    closedir(dirp);
    _path[_path_len] = 0;    
    return mysize;
}

void PanelDirectorySizeCalculate( FlexChainedStringsChunk *_dirs, const char *_root_path, PanelController *_panel)
{
    if(_panel.isStopDirectorySizeCounting)
        return;

    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _root_path);
    char *var = path + strlen(path);
    
    for(const auto &i: *_dirs)
    {
        memcpy(var, i.str(), i.len+1);
        
        int64_t size = DirectorySizeCalculateRec(path, strlen(path), &iscancelling, _panel);

        if(iscancelling || _panel.isStopDirectorySizeCounting) // check if we need to quit
            goto cleanup;

        if(size >= 0)
            [_panel DidCalculatedDirectorySizeForEntry:i.str() size:size];
    }
    
cleanup:
    FlexChainedStringsChunk::FreeWithDescendants(&_dirs);
    free((void*)_root_path);
}