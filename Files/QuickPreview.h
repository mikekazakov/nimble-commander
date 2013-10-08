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

- (void)PreviewItem:(const char *)_path vfs:(std::shared_ptr<VFSHost>)_host;

@end
