//
//  FileDeletionSheetWindowController.h
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FileDeletionOperation.h"

struct FlexChainedStringsChunk;

typedef void (^FileDeletionSheetCompletionHandler)(int result);

@interface FileDeletionSheetController : NSWindowController

@property (weak) IBOutlet NSTextField *Label;
@property (weak) IBOutlet NSButton *DeleteButton;
@property (weak) IBOutlet NSPopUpButton *DeleteTypeButton;
- (IBAction)OnDeleteAction:(id)sender;
- (IBAction)OnCancelAction:(id)sender;

- (id)init;

- (void)ShowSheet:(NSWindow *)_window Files:(FlexChainedStringsChunk *)_files
             Type:(FileDeletionOperationType)_type
          Handler:(FileDeletionSheetCompletionHandler)_handler;

- (FileDeletionOperationType)GetType;

@end
