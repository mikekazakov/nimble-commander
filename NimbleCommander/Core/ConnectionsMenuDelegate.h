// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class NetworkConnectionsManager;

@interface ConnectionsMenuDelegate : NSObject<NSMenuDelegate>

- (instancetype) initWithManager:(std::function<NetworkConnectionsManager&()>)_callback;

@end
