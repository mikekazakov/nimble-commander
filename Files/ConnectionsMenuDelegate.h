//
//  ConnectionsMenuDelegate.h
//  Files
//
//  Created by Michael G. Kazakov on 28/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "NetworkConnectionsManager.h"

@interface ConnectionsMenuDelegateInfoWrapper : NSObject
@property (nonatomic, readonly) NetworkConnectionsManager::Connection object;
@end

@interface ConnectionsMenuDelegate : NSObject<NSMenuDelegate>
@property (strong) IBOutlet NSMenuItem *recentConnectionsMenuItem;

@end
