//
//  FileLinkNewHardlinkSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^FileLinkNewHardlinkSheetCompletionHandler)(int result);

@interface FileLinkNewHardlinkSheetController : NSWindowController

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *LinkName;

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;

- (void)ShowSheet:(NSWindow *)_window
       sourcename:(NSString*)_src
          handler:(FileLinkNewHardlinkSheetCompletionHandler)_handler;


@end
