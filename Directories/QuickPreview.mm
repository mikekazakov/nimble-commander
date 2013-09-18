//
//  QuickPreview.m
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import <Quartz/Quartz.h>

#import "QuickPreview.h"
#import "PanelView.h"

static const uint64_t g_MaxFileSizeForVFSQL = 64*1024*1024; // 64mb
static const char *g_QLPref = "info.filesmanager.vfs_ql.";

static bool ExtensionFromPath(const char* _path, char *_buf)
{
    const char* last_sl  = strrchr(_path, '/');
    const char* last_dot = strrchr(_path, '.');
    if(!last_sl || !last_dot) return false;
    if(last_dot == last_sl+1) return false;
    if(last_dot == _path + strlen(_path) - 1) return false;
    strcpy(_buf, last_dot+1);
    return true;
}

static bool FilenameFromPath(const char* _path, char *_buf)
{
    const char* last_sl  = strrchr(_path, '/');
    if(!last_sl) return false;
    if(last_sl == _path + strlen(_path) - 1) return false;
    strcpy(_buf, last_sl+1);
    return true;
}

static void DoTempQlPurge()
{
    // purge any of ours QL files, which are older than 24 hours
    NSString *temp_dir = NSTemporaryDirectory();
    DIR *dirp = opendir([temp_dir fileSystemRepresentation]);
    if(!dirp)
        return;
    
    dirent *entp;
    while((entp = readdir(dirp)) != NULL)
    {
        if( strncmp(entp->d_name, g_QLPref, strlen(g_QLPref)) == 0 )
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
                       DoTempQlPurge();
    });
}

@interface QuickPreviewItem : NSObject <QLPreviewItem>
@property NSURL *previewItemURL;
@end

@implementation QuickPreviewItem
@end

///////////////////////////////////////////////////////////////////////////////////////////////
@interface QuickPreviewData : NSObject <QLPreviewPanelDataSource>
- (void)UpdateItem:(NSURL *)_path OriginalPath:(std::string)_orig;
- (const std::string&) OriginalPath;
@end

@implementation QuickPreviewData
{
    QuickPreviewItem *m_Item;
    std::string       m_OrigPath;
}

- (id)init
{
    self = [super init];
    if (self) m_Item = [QuickPreviewItem new];
    return self;
}

- (void)UpdateItem:(NSURL *)_path OriginalPath:(std::string)_orig
{
    if ([_path isEqual:m_Item.previewItemURL]) return;
    if(m_OrigPath == _orig) return;
    
    m_Item = [QuickPreviewItem new]; // what for should we change our object any time?
    m_Item.previewItemURL = _path;
    m_OrigPath = _orig;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return 1;
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    assert(index == 0);
    return m_Item;
}

- (const std::string&) OriginalPath
{
    return m_OrigPath;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////
@implementation QuickPreview
static QuickPreviewData *m_Data;

+ (void)initialize
{
    m_Data = [[QuickPreviewData alloc] init];
}

+ (void)Show
{
    [[QLPreviewPanel sharedPreviewPanel] orderFront:nil];
    [[QLPreviewPanel sharedPreviewPanel] setDataSource:m_Data];
}

+ (void)Hide
{
    [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
}

+ (BOOL)IsVisible
{
    return [[QLPreviewPanel sharedPreviewPanel] isVisible];
}

+ (void)PreviewItem:(const char *)_path vfs:(std::shared_ptr<VFSHost>)_host sender:(PanelView *)_panel
{
    NSWindow *window = [_panel window];
    if (![window isKeyWindow])
        return;

    // may cause collisions of same filenames on different vfs, nevermind for now
    if([m_Data OriginalPath] == _path) return;
    
    if(_host->IsNativeFS())
    {
        [m_Data UpdateItem:[NSURL fileURLWithPath:[NSString stringWithUTF8String:_path]]
              OriginalPath:_path
         ];
        [[QLPreviewPanel sharedPreviewPanel] reloadData];
    }
    else
    {
        std::string path = _path;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if(_host->IsDirectory(path.c_str(), 0, 0))
                return;
            
            char fname[MAXPATHLEN];
            if(!FilenameFromPath(path.c_str(), fname))
                return;
            
            std::shared_ptr<VFSFile> vfs_file;
            if(_host->CreateFile(path.c_str(), &vfs_file, 0) < 0)
                return;
            if(vfs_file->Open(VFSFile::OF_Read) < 0)
                return;
            if(vfs_file->Size() > g_MaxFileSizeForVFSQL)
                return;
            
            NSData *data = vfs_file->ReadFile();
            if(!data)
                return;
            vfs_file.reset();
            
            NSString *temp_dir = NSTemporaryDirectory();
            char pattern_buf[MAXPATHLEN];
            sprintf(pattern_buf, "%s%sXXXXXX", [temp_dir fileSystemRepresentation], g_QLPref);
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
                    [m_Data UpdateItem:[NSURL fileURLWithPath:fn] OriginalPath:path];
                    [[QLPreviewPanel sharedPreviewPanel] reloadData];
                });
                // old temp files will be purged on next app start
            }
            else
            {
                unlink(pattern_buf);
            }
        });
    }
}

+ (void)UpdateData
{
    [QLPreviewPanel sharedPreviewPanel].dataSource = m_Data;
}

+ (void)StartBackgroundTempPurging
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        DoTempQlPurge();
    });
}

@end
