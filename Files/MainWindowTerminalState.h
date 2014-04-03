//
//  MainWindowTerminalState.h
//  Files
//
//  Created by Michael G. Kazakov on 26.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MainWindowStateProtocol.h"

@interface MainWindowTerminalState : NSScrollView<MainWindowStateProtocol>

- (void) SetInitialWD:(const char*)_wd;
- (void) ChDir:(const char*)_new_dir;
- (void) Execute:(const char *)_short_fn at:(const char*)_at;
- (void) Execute:(const char *)_short_fn at:(const char*)_at with_parameters:(const char*)_params;

- (void) Execute:(const char *)_full_fn with_parameters:(const char*)_params;

- (bool) IsAnythingRunning;
- (void) Terminate;

- (bool) GetCWD:(char *)_cwd;

@end
