//
//  FTPConnectionSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 17.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FTPConnectionSheetController : NSWindowController
@property (strong) NSString *server;
@property (strong) NSString *username;
@property (strong) NSString *password;
@property (strong) NSString *path;
@property (strong) NSString *port;

- (void)ShowSheet:(NSWindow *) _window
          handler:(void(^)())_on_connect;
- (IBAction)OnConnect:(id)sender;
- (IBAction)OnClose:(id)sender;

@end
