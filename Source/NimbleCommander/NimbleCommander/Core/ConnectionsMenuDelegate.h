// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>

namespace nc::panel {
class NetworkConnectionsManager;
}

@interface ConnectionsMenuDelegate : NSObject <NSMenuDelegate>

- (instancetype)initWithManager:(std::function<nc::panel::NetworkConnectionsManager &()>)_callback;

@end
