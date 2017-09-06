#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include "ConnectionSheetProtocol.h"

@interface WebDAVConnectionSheetController : SheetController <ConnectionSheetProtocol,
                                                              NSTextFieldDelegate>

@property (nonatomic) NetworkConnectionsManager::Connection connection;
@property (nonatomic) string password;
@property (nonatomic) bool setupMode;

@end
