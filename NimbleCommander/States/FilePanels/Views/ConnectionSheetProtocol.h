#pragma once

#include <NimbleCommander/Core/NetworkConnectionsManager.h>

@protocol ConnectionSheetProtocol<NSObject>

@required
@property (nonatomic) NetworkConnectionsManager::Connection connection;
@property (nonatomic) string password;

@end
