//
//  MassCopySheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "chained_strings.h"
struct FileCopyOperationOptions;

typedef void (^MassCopySheetCompletionHandler)(int result);

@interface MassCopySheetController : NSWindowController
@property (strong) IBOutlet NSButton *CopyButton;
@property (strong) IBOutlet NSTextField *TextField;
- (IBAction)OnCopy:(id)sender;
- (IBAction)OnCancel:(id)sender;
@property (strong) IBOutlet NSTextField *DescriptionText;
@property (strong) IBOutlet NSButton *DisclosureTriangle;
- (IBAction)OnDisclosureTriangle:(id)sender;
@property (strong) IBOutlet NSTextField *DisclosureLabel;
@property (strong) IBOutlet NSButton *PreserveSymlinksCheckbox;
@property (strong) IBOutlet NSButton *CopyXattrsCheckbox;
@property (strong) IBOutlet NSButton *CopyFileTimesCheckbox;
@property (strong) IBOutlet NSButton *CopyUNIXFlagsCheckbox;
@property (strong) IBOutlet NSButton *CopyUnixOwnersCheckbox;
@property (strong) IBOutlet NSButton *CopyButtonStringStub;
@property (strong) IBOutlet NSButton *RenameButtonStringStub;



@property (strong) IBOutlet NSBox *DisclosureGroup;

- (void)ShowSheet:(NSWindow *)_window
         initpath:(NSString*)_path
        iscopying:(bool)_iscopying
            items:(shared_ptr<vector<string>>)_items
          handler:(MassCopySheetCompletionHandler)_handler;
// if _iscopying is false than dialog will think that user attempt to rename/move files
- (void)FillOptions:(FileCopyOperationOptions*) _opts;

@end
