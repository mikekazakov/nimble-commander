// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <Panel/NetworkConnectionsManager.h>

@interface ConnectToServer : SheetController <NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithNetworkConnectionsManager:(nc::panel::NetworkConnectionsManager &)_manager;

@property(readonly, nonatomic) std::optional<nc::panel::NetworkConnectionsManager::Connection> connection;

@end
