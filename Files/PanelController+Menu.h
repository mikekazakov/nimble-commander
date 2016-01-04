//
//  PanelController+Menu.h
//  Files
//
//  Created by Michael G. Kazakov on 24.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "PanelController.h"
#include "NetworkConnectionsManager.h"

@interface PanelController (Menu)

- (IBAction)OnGoBack:(id)sender;
- (void) showGoToFTPSheet:(optional<NetworkConnectionsManager::Connection>)_current;
- (void) showGoToSFTPSheet:(optional<NetworkConnectionsManager::Connection>)_current;
- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (void)GoToSavedConnection:(NetworkConnectionsManager::Connection)connection;
- (IBAction)OnDeleteSavedConnectionItem:(id)sender;
- (IBAction)OnEditSavedConnectionItem:(id)sender;
- (IBAction)OnFileViewCommand:(id)sender;

- (IBAction)OnBatchRename:(id)sender;

@end
