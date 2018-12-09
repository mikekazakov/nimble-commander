// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/NetworkConnectionsManager.h>

@protocol ConnectionSheetProtocol<NSObject>

@required
@property (nonatomic) NetworkConnectionsManager::Connection connection;
@property (nonatomic) std::string password;
@property (nonatomic) bool setupMode;

@end
