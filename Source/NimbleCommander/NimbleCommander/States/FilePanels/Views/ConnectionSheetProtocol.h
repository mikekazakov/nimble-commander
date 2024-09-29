// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Panel/NetworkConnectionsManager.h>

@protocol ConnectionSheetProtocol <NSObject>

@required
@property(nonatomic) nc::panel::NetworkConnectionsManager::Connection connection;
@property(nonatomic) std::string password;
@property(nonatomic) bool setupMode;

@end
