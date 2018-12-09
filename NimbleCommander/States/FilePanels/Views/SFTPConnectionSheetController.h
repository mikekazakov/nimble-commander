// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include "ConnectionSheetProtocol.h"

@interface SFTPConnectionSheetController : SheetController <ConnectionSheetProtocol,
                                                            NSTextFieldDelegate>

@property (nonatomic) NetworkConnectionsManager::Connection connection;
@property (nonatomic) std::string password;
@property (nonatomic) bool setupMode;

@end
