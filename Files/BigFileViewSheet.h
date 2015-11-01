//
//  BigFileViewSheet.h
//  Files
//
//  Created by Michael G. Kazakov on 21/09/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "SheetController.h"
#include "BigFileView.h"
#include "vfs/VFS.h"

@interface BigFileViewSheet : SheetController

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs;

- (bool) open; // call it from bg thread!
- (void) selectBlockAt:(uint64_t)off length:(uint64_t)len; // should be called upon init
- (IBAction)OnClose:(id)sender;
- (IBAction)OnMode:(id)sender;
- (IBAction)OnEncoding:(id)sender;

@property (strong) IBOutlet BigFileView *view;
@property (strong) IBOutlet NSSegmentedControl *mode;
@property (strong) IBOutlet NSPopUpButton *encoding;

@end
