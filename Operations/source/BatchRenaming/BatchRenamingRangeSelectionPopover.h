// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
