//
//  BriefSystemOverview.h
//  Files
//
//  Created by Michael G. Kazakov on 08.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VFS.h"

@interface BriefSystemOverview : NSView

- (void) UpdateVFSTarget:(const char*)_path host:(std::shared_ptr<VFSHost>)_host;

@end
