//
//  FileDeletionSheetWindowController.h
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/SheetController.h>
#include "FileDeletionOperation.h"
#include "../../ButtonWithOptions.h"

@interface FileDeletionSheetController : SheetController

@property (strong) IBOutlet NSTextField *Label;
@property (strong) IBOutlet ButtonWithOptions *DeleteButton;
@property (strong) IBOutlet NSMenu *DeleteButtonMenu;

@property (nonatomic) bool allowMoveToTrash;
@property (nonatomic) FileDeletionOperationType defaultType;
@property (nonatomic) FileDeletionOperationType resultType;

- (id)initWithItems:(shared_ptr<vector<VFSListingItem>>)_items;

- (IBAction)OnDeleteAction:(id)sender;
- (IBAction)OnCancelAction:(id)sender;
- (IBAction)OnMenuItem:(NSMenuItem *)sender;

@end
