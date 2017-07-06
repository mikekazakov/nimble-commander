#pragma once
#import <Cocoa/Cocoa.h>

@interface NCOpsBatchRenamingRangeSelectionPopover : NSViewController<NSPopoverDelegate,NSTextFieldDelegate>

@property (strong) void (^handler)(NSRange _range);
@property (strong) NSString *string;


@property (strong) IBOutlet NSTextField *textField;


@property (weak) NSPopover *enclosingPopover;
- (IBAction)OnOK:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end
