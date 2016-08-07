#pragma once

#include "BigFileView.h"

@interface InternalViewerController : NSObject<BigFileViewDelegateProtocol, NSSearchFieldDelegate>

// UI wiring
@property (nonatomic) BigFileView           *view;
@property (nonatomic) NSSearchField         *searchField;
@property (nonatomic) NSProgressIndicator   *searchProgressIndicator;
@property (nonatomic) NSPopUpButton         *encodingsPopUp;
@property (nonatomic) NSPopUpButton         *modePopUp;

- (void) setFile:(string)path at:(VFSHostPtr)vfs;
- (bool) performBackgroundOpening;
- (void) show;

+ (unsigned) fileWindowSize;

@end
