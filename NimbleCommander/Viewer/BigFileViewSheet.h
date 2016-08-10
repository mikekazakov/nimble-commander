//
//  BigFileViewSheet.h
//  Files
//
//  Created by Michael G. Kazakov on 21/09/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>
#include "../../Files/vfs/VFS.h"
#include "BigFileView.h"

@interface BigFileViewSheet : SheetController

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs;

- (bool) open; // call it from bg thread!
- (void) selectBlockAt:(uint64_t)off length:(uint64_t)len; // should be called upon init

@end
