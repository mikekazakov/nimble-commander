#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include "ConnectionSheetProtocol.h"

@interface NetworkShareSheetController : SheetController
    <NSTextFieldDelegate, ConnectionSheetProtocol>

@property (nonatomic) NetworkConnectionsManager::Connection connection;
@property (nonatomic) string password;
@property (nonatomic) bool setupMode;

@end
