//
//  FTPConnectionSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 17.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SheetController.h"
#import "SavedNetworkConnectionsManager.h"

@interface FTPConnectionSheetController : SheetController
@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *username;
@property (strong) NSString *password;
@property (strong) NSString *path;
@property (strong) NSString *port;
@property (strong) IBOutlet NSPopUpButton *saved;
- (IBAction)OnSaved:(id)sender;
- (IBAction)OnConnect:(id)sender;
- (IBAction)OnClose:(id)sender;
- (void)fillInfoFromStoredConnection:(shared_ptr<SavedNetworkConnectionsManager::FTPConnection>)_conn;

@end
