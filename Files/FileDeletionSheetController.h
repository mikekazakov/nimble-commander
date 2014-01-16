//
//  FileDeletionSheetWindowController.h
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FileDeletionOperation.h"
#import "ButtonWithOptions.h"
#import "chained_strings.h"

typedef void (^FileDeletionSheetCompletionHandler)(int result);

@interface FileDeletionSheetController : NSWindowController

@property (strong) IBOutlet NSTextField *Label;
@property (strong) IBOutlet ButtonWithOptions *DeleteButton;
@property (strong) IBOutlet NSMenu *DeleteButtonMenu;
- (IBAction)OnDeleteAction:(id)sender;
- (IBAction)OnCancelAction:(id)sender;
- (IBAction)OnMenuItem:(NSMenuItem *)sender;

- (id)init;

- (void)ShowSheet:(NSWindow *)_window Files:(chained_strings *)_files
             Type:(FileDeletionOperationType)_type
          Handler:(FileDeletionSheetCompletionHandler)_handler;

- (FileDeletionOperationType)GetType;

@end
