//
//  BatchRenameSheetRangeSelectionPopoverController.h
//  Files
//
//  Created by Michael G. Kazakov on 17/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BatchRenameSheetRangeSelectionPopoverController : NSViewController<NSPopoverDelegate,NSTextFieldDelegate>

@property (strong) void (^handler)(NSRange _range);
@property (strong) NSString *string;


@property (strong) IBOutlet NSTextField *textField;


@property (weak) NSPopover *enclosingPopover;
- (IBAction)OnOK:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end
