//
//  QuickPreview.h
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>
#import "VFS.h"

@interface QuickLookView : QLPreviewView

- (void)PreviewItem:(const string&)_path vfs:(const VFSHostPtr&)_host;

@end
