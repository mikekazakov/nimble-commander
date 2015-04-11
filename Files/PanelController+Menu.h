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

- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (void)GoToSavedConnection:(shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>)connection;
- (IBAction)OnDeleteSavedConnectionItem:(id)sender;
- (IBAction)OnFileViewCommand:(id)sender;

@end
