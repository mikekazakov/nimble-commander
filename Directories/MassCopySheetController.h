//
//  MassCopySheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^MassCopySheetCompletionHandler)(int result);

@interface MassCopySheetController : NSWindowController
@property (strong) IBOutlet NSButton *CopyButton;
@property (strong) IBOutlet NSTextField *TextField;
- (IBAction)OnCopy:(id)sender;
- (IBAction)OnCancel:(id)sender;
@property (strong) IBOutlet NSTextField *DescriptionText;

- (void)ShowSheet:(NSWindow *)_window initpath:(NSString*)_path iscopying:(bool)_iscopying handler:(MassCopySheetCompletionHandler)_handler;
// if _iscopying is false than dialog will think that user attempt to rename/move files

@end
