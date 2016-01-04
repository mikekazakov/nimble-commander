//
//  SFTPConnectionSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 31/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "SheetController.h"
#include "NetworkConnectionsManager.h"

@interface SFTPConnectionSheetController : SheetController
@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *username;
@property (strong) NSString *password;
@property (strong) NSString *port;
@property (strong) NSString *keypath;
@property (strong) IBOutlet NSPopUpButton *saved;
- (IBAction)OnSaved:(id)sender;
- (IBAction)OnConnect:(id)sender;
- (IBAction)OnClose:(id)sender;
- (IBAction)OnChooseKey:(id)sender;
- (void)fillInfoFromStoredConnection:(NetworkConnectionsManager::Connection)_conn;
@property (readonly, nonatomic) NetworkConnectionsManager::Connection result;
@end
