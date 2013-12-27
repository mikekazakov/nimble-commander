//
//  PanelController+Navigation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (Navigation)

- (void) AsyncGoToVFSPathStack:(const VFSPathStack&)_path
                     withFlags:(int)_flags
                      andFocus:(string)_filename;

- (void) OnGoBack;
- (void) OnGoForward;

@end
