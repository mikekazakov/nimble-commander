// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

@interface NCOpsBatchRenamingRangeSelectionPopover : NSViewController <NSPopoverDelegate, NSTextFieldDelegate>

@property(strong, nonatomic) void (^handler)(NSRange _range);
@property(strong, nonatomic) NSString *string;
@property(strong, nonatomic) IBOutlet NSTextField *textField;

@property(weak, nonatomic) NSPopover *enclosingPopover;
- (IBAction)OnOK:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end
