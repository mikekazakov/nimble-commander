#pragma once

#include "BigFileView.h"

@interface InternalViewerController : NSObject<BigFileViewDelegateProtocol>

@property (strong) BigFileView *view;

- (void) setFile:(string)path at:(VFSHostPtr)vfs;
- (bool) performBackgroundOpening;
- (void) show;

+ (unsigned) fileWindowSize;

@end
