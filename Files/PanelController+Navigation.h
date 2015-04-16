//
//  PanelController+Navigation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (Navigation)

// TODO:
// wrap parameters into some request context object

// will not load previous view state if any
- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
          async:(bool)_asynchronous;

- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
loadPreviousState:(bool)_load_state
          async:(bool)_asynchronous;

// will load previous view state if any
- (void) GoToVFSPathStack:(const VFSPathStack&)_stack;
// some params later

- (void) RecoverFromInvalidDirectory;

@end
