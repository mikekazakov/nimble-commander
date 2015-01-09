//
//  ConnectionsMenuDelegate.h
//  Files
//
//  Created by Michael G. Kazakov on 28/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SavedNetworkConnectionsManager.h"

@interface ConnectionsMenuDelegateInfoWrapper : NSObject
@property (nonatomic, readonly) shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> object;
@end

@interface ConnectionsMenuDelegate : NSObject<NSMenuDelegate>
@property (strong) IBOutlet NSMenuItem *recentConnectionsMenuItem;

@end
