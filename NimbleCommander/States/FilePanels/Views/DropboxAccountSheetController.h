#pragma once

#include <Utility/SheetController.h>
#include "ConnectionSheetProtocol.h"

@interface DropboxAccountSheetController : SheetController<ConnectionSheetProtocol>

@property (nonatomic) NetworkConnectionsManager::Connection connection;
@property (nonatomic) string password;

@end
