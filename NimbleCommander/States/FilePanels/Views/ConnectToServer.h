// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>

namespace nc::bootstrap {
class ActivationManager;
}

@interface ConnectToServer : SheetController <NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithNetworkConnectionsManager:(NetworkConnectionsManager &)_manager
                            activationManager:(nc::bootstrap::ActivationManager &)_am;

@property(readonly, nonatomic) std::optional<NetworkConnectionsManager::Connection> connection;

@end
