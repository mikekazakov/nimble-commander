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
#import "Common.h"
#import "TemporaryNativeFileStorage.h"

static const uint64_t g_MaxFileSizeForVFSQL = 64*1024*1024; // 64mb

@implementation QuickLookView
{
    string m_OrigPath;
    volatile bool        m_Closed;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect style:QLPreviewViewStyleNormal];
    if (self) {
        m_Closed = false;
        self.shouldCloseWithWindow = false;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (BOOL) acceptsFirstResponder
{
    return false;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)close
{
    [super close];
    m_Closed = true;
}

- (void)viewDidMoveToSuperview
{
    if(self.superview == nil)
        [self close];
}

- (void)PreviewItem:(string)_path vfs:(shared_ptr<VFSHost>)_host
{
    // may cause collisions of same filenames on different vfs, nevermind for now
    assert(!m_Closed);
    if(m_OrigPath == _path) return;
    
    m_OrigPath = _path;
    
    if(_host->IsNativeFS())
    {
        self.previewItem = [NSURL fileURLWithPath:[NSString stringWithUTF8String:_path.c_str()]];
    }
    else
    {
        string path = _path;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if(_host->IsDirectory(path.c_str(), 0, 0))
            {
                dispatch_to_main_queue( ^{ self.previewItem = nil; });
                return;
            }
            struct stat st;
            if(_host->Stat(path.c_str(), st, 0, 0) < 0)
            {
                dispatch_to_main_queue( ^{ self.previewItem = nil; });
                return;
            }
            if(st.st_size > g_MaxFileSizeForVFSQL)
            {
                dispatch_to_main_queue( ^{ self.previewItem = nil; });                
                return;
            }
            
            char tmp[MAXPATHLEN];
            if(!TemporaryNativeFileStorage::Instance().CopySingleFile(path.c_str(), _host, tmp))
                return;
            NSString *fn = [NSString stringWithUTF8String:tmp];
            if(!m_Closed)
                dispatch_to_main_queue( ^{
                    if(!m_Closed)
                        self.previewItem = [NSURL fileURLWithPath:fn];
                });
        });
    }
}

- (void)CreateBorder
{
    return; // mysteries of mystic mystery here
    if(self.subviews.count > 0)
    {
        NSView *subview = self.subviews[0];
    
        if(subview.subviews.count > 0)
        {
            NSView *subsubview = subview.subviews[0];
        
            [subsubview setWantsLayer:true];
            subsubview.layer.borderWidth = 1;
            subsubview.layer.cornerRadius = 2;
            static CGColorRef color = CGColorCreateGenericRGB(204/255.0, 204/255.0, 204/255.0, 0.5);
            subsubview.layer.borderColor = color;
        }
    }
}

- (void)frameDidChange
{
    NSView *subview = self.subviews[0];
    [subview setFrameSize:self.frame.size];
}

@end
