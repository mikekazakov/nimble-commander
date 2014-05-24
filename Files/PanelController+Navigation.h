//
//  PanelController+Navigation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (Navigation)

- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
          async:(bool)_asynchronous;

- (void) GoToVFSPathStack:(const VFSPathStack&)_stack;
// some params later

@end
