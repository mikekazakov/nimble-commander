// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>

@interface CalculateChecksumSheetController : SheetController<NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic) IBOutlet NSPopUpButton *HashMethod;
@property (nonatomic) IBOutlet NSTableView *Table;
@property (nonatomic) IBOutlet NSProgressIndicator *Progress;
@property (nonatomic) bool isWorking;
@property (nonatomic) bool sumsAvailable;
@property (nonatomic) bool didSaved;
@property (nonatomic, readonly) std::string savedFilename;
@property (nonatomic) IBOutlet NSTableColumn *filenameTableColumn;
@property (nonatomic) IBOutlet NSTableColumn *checksumTableColumn;

- (id)initWithFiles:(std::vector<std::string>)files
          withSizes:(std::vector<uint64_t>)sizes
             atHost:(const VFSHostPtr&)host
             atPath:(std::string)path;

- (IBAction)OnClose:(id)sender;
- (IBAction)OnCalc:(id)sender;
- (IBAction)OnSave:(id)sender;

@end
