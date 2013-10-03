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
#import "Common.h"
#import "TemporaryNativeFileStorage.h"

static const uint64_t g_MaxFileSizeForVFSQL = 64*1024*1024; // 64mb

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
    if([QuickPreview IsVisible])
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
            struct stat st;
            if(_host->Stat(path.c_str(), st, 0, 0) < 0)
                return;
            if(st.st_size > g_MaxFileSizeForVFSQL)
                return;
            
            char tmp[MAXPATHLEN];
            if(!TemporaryNativeFileStorage::Instance().CopySingleFile(path.c_str(), _host, tmp))
                return;
            
            NSString *fn = [NSString stringWithUTF8String:tmp];
            dispatch_async(dispatch_get_main_queue(), ^{
                [m_Data UpdateItem:[NSURL fileURLWithPath:fn] OriginalPath:path];
                [[QLPreviewPanel sharedPreviewPanel] reloadData];
            });
        });
    }
}

+ (void)UpdateData
{
    [QLPreviewPanel sharedPreviewPanel].dataSource = m_Data;
}

@end
