//
//  PanelController+Menu.h
//  Files
//
//  Created by Michael G. Kazakov on 24.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"
#import "SavedNetworkConnectionsManager.h"

@interface PanelController (Menu)

- (IBAction)OnGoBack:(id)sender;
- (void) showGoToFTPSheet:(shared_ptr<SavedNetworkConnectionsManager::FTPConnection>)_current; // current may be nullptr
- (void) showGoToSFTPSheet:(shared_ptr<SavedNetworkConnectionsManager::SFTPConnection>)_current; // current may be nullptr
- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (void)GoToSavedConnection:(shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>)connection;
- (IBAction)OnDeleteSavedConnectionItem:(id)sender;
- (IBAction)OnEditSavedConnectionItem:(id)sender;
- (IBAction)OnFileViewCommand:(id)sender;

- (IBAction)OnBatchRename:(id)sender;

@end
