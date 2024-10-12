// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <swiftToCxx/_SwiftCxxInteroperability.h>
#include <NimbleCommanderCommon-Swift.h>

#include <functional>

namespace nc::panel {
class ExternalToolsStorage;
}

@interface PreferencesWindowHotkeysTab : NSViewController <PreferencesViewControllerProtocol,
                                                           NSTableViewDataSource,
                                                           NSTableViewDelegate,
                                                           NSTextFieldDelegate>

- (id)initWithToolsStorage:(std::function<nc::panel::ExternalToolsStorage &()>)_tool_storage;

@end
