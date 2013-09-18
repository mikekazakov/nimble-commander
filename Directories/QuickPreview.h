//
//  QuickPreview.h
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VFS.h"

@class PanelView;

@interface QuickPreview : NSObject

+ (void)Show;
+ (void)Hide;
+ (BOOL)IsVisible;
+ (void)PreviewItem:(const char *)_path vfs:(std::shared_ptr<VFSHost>)_host sender:(PanelView *)_panel;
+ (void)UpdateData;

+ (void)StartBackgroundTempPurging;
@end
