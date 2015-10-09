//
//  MassCopySheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"
#import "SheetController.h"

struct FileCopyOperationOptions;

@interface MassCopySheetController : SheetController<NSTextFieldDelegate>
@property (strong) IBOutlet NSButton *CopyButton;
@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSTextField *DescriptionText;
@property (strong) IBOutlet NSButton *DisclosureTriangle;
@property (strong) IBOutlet NSTextField *DisclosureLabel;
@property (strong) IBOutlet NSButton *PreserveSymlinksCheckbox;
@property (strong) IBOutlet NSButton *CopyXattrsCheckbox;
@property (strong) IBOutlet NSButton *CopyFileTimesCheckbox;
@property (strong) IBOutlet NSButton *CopyUNIXFlagsCheckbox;
@property (strong) IBOutlet NSButton *CopyUnixOwnersCheckbox;
@property (strong) IBOutlet NSButton *CopyButtonStringStub;
@property (strong) IBOutlet NSButton *RenameButtonStringStub;
@property (strong) IBOutlet NSBox *DisclosureGroup;
@property bool isValidInput;

@property (readonly) string                     resultDestination;
@property (readonly) VFSHostPtr                 resultHost;
@property (readonly) FileCopyOperationOptions   resultOptions;

- (instancetype) initWithItems:(vector<VFSFlexibleListingItem>)_source_items
                     sourceVFS:(const VFSHostPtr&)_source_host
               sourceDirectory:(const string&)_source_directory
            initialDestination:(const string&)_initial_destination
                destinationVFS:(const VFSHostPtr&)_destination_host
              operationOptions:(const FileCopyOperationOptions&)_options;

- (IBAction)OnDisclosureTriangle:(id)sender;
- (IBAction)OnCopy:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end
