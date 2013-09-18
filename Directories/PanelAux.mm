//
//  PanelAux.mm
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import "PanelAux.h"
#import "Common.h"

static const uint64_t g_MaxFileSizeForVFSOpen = 64*1024*1024; // 64mb
static const char *g_OpenPref = "info.filesmanager.vfs_open.";

static void DoTempOpenPurge()
{
    // purge any of ours QL files, which are older than 24 hours
    NSString *temp_dir = NSTemporaryDirectory();
    DIR *dirp = opendir([temp_dir fileSystemRepresentation]);
    if(!dirp)
        return;
    
    dirent *entp;
    while((entp = readdir(dirp)) != NULL)
    {
        if( strncmp(entp->d_name, g_OpenPref, strlen(g_OpenPref)) == 0 )
        {
            char fn[MAXPATHLEN];
            strcpy(fn, [temp_dir fileSystemRepresentation]);
            if( fn[strlen(fn)-1] != '/') strcat(fn, "/");
            strcat(fn, entp->d_name);
            
            struct stat st;
            if( lstat(fn, &st) == 0 )
            {
                NSDate *file_date = [NSDate dateWithTimeIntervalSince1970:st.st_mtimespec.tv_sec];
                NSTimeInterval diff = [file_date timeIntervalSinceNow];
                if(diff < -60*60*24) // 24 hours
                    unlink(fn);
            }
        }
    }
    closedir(dirp);
    
    // schedule next purging in 6 hours
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60*60*6*NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       DoTempOpenPurge();
                   });
}

void PanelVFSFileWorkspaceOpener::StartBackgroundPurging()
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        DoTempOpenPurge();
    });
}

void PanelVFSFileWorkspaceOpener::Open(const char* _filename, std::shared_ptr<VFSHost> _host)
{
    std::string path = _filename;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_host->IsDirectory(path.c_str(), 0, 0))
            return;
        
        char fname[MAXPATHLEN];
        if(!GetFilenameFromPath(path.c_str(), fname))
            return;
        
        std::shared_ptr<VFSFile> vfs_file;
        if(_host->CreateFile(path.c_str(), &vfs_file, 0) < 0)
            return;
        if(vfs_file->Open(VFSFile::OF_Read) < 0)
            return;
        if(vfs_file->Size() > g_MaxFileSizeForVFSOpen)
            return;
        
        NSData *data = vfs_file->ReadFile();
        if(!data)
            return;
        vfs_file.reset();
        
        NSString *temp_dir = NSTemporaryDirectory();
        char pattern_buf[MAXPATHLEN];
        sprintf(pattern_buf, "%s%sXXXXXX", [temp_dir fileSystemRepresentation], g_OpenPref);
        int fd = mkstemp(pattern_buf);
        if(fd < 0)
            return;
        
        ssize_t left_write = [data length];
        const char *buf = (const char*)[data bytes];
        while(left_write > 0) {
            ssize_t res_write = write(fd, buf, left_write);
            if(res_write >= 0)
                left_write -= res_write;
            else
            {
                close(fd);
                unlink(pattern_buf);
                return;
            }
        }
        
        close(fd);
        
        char filename_ext[MAXPATHLEN];
        strcpy(filename_ext, pattern_buf);
        strcat(filename_ext, ".");
        strcat(filename_ext, fname);
        
        if(rename(pattern_buf, filename_ext) == 0)
        {
            NSString *fn = [NSString stringWithUTF8String:filename_ext];
            dispatch_async(dispatch_get_main_queue(), ^{
                bool success = [[NSWorkspace sharedWorkspace] openFile:fn];
                if (!success)
                    NSBeep();
            });
            // old temp files will be purged on next app start or after 6 hours
        }
        else
        {
            unlink(pattern_buf);
        }
    });
}
