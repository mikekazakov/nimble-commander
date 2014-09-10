//
//  CalculateChecksumSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 08/09/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SheetController.h"
#import "VFS.h"

@interface CalculateChecksumSheetController : SheetController<NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSPopUpButton *HashMethod;
@property (strong) IBOutlet NSTableView *Table;
@property (strong) IBOutlet NSProgressIndicator *Progress;
@property bool isWorking;
@property bool sumsAvailable;
@property (nonatomic) bool didSaved;
@property (nonatomic, readonly) string savedFilename;

- (id)initWithFiles:(vector<string>)files
          withSizes:(vector<uint64_t>)sizes
             atHost:(const VFSHostPtr&)host
             atPath:(string)path;

- (IBAction)OnClose:(id)sender;
- (IBAction)OnCalc:(id)sender;
- (IBAction)OnSave:(id)sender;

@end
