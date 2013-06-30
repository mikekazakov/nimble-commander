//
//  FileLinkAlterSymlinkSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^FileLinkAlterSymlinkSheetCompletionHandler)(int result);

@interface FileLinkAlterSymlinkSheetController : NSWindowController

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *SourcePath;

- (IBAction)OnOk:(id)sender;
- (IBAction)OnCancel:(id)sender;

- (void)ShowSheet:(NSWindow *)_window
       sourcepath:(NSString*)_src
         linkname:(NSString*)_link_name
          handler:(FileLinkAlterSymlinkSheetCompletionHandler)_handler;

@end
