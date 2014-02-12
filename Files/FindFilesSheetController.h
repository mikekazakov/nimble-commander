//
//  FindFileSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 12.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "VFS.h"

@interface FindFilesSheetController : NSWindowController<NSTableViewDataSource, NSTableViewDelegate>


- (void)ShowSheet:(NSWindow *) _window
          withVFS:(shared_ptr<VFSHost>) _host
         fromPath:(string) _path;

- (IBAction)OnClose:(id)sender;
- (IBAction)OnSearch:(id)sender;

@property (strong) IBOutlet NSButton *CloseButton;
@property (strong) IBOutlet NSButton *SearchButton;
@property (strong) IBOutlet NSTextField *MaskTextField;
@property (strong) IBOutlet NSTextField *ContainingTextField;
@property (strong) IBOutlet NSTableView *TableView;

@end
