//
//  FileLinkNewSymlinkSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^FileLinkNewSymlinkSheetCompletionHandler)(int result);

@interface FileLinkNewSymlinkSheetController : NSWindowController

@property (strong) IBOutlet NSTextField *SourcePath;
@property (strong) IBOutlet NSTextField *LinkPath;

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;

- (void)ShowSheet:(NSWindow *)_window
         sourcepath:(NSString*)_src_path
         linkpath:(NSString*)_link_path
          handler:(FileLinkNewSymlinkSheetCompletionHandler)_handler;


@end
