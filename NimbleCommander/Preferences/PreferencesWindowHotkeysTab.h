// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

class ExternalToolsStorage;

@interface PreferencesWindowHotkeysTab : NSViewController<RHPreferencesViewControllerProtocol,
                                                            NSTableViewDataSource,
                                                            NSTableViewDelegate,
                                                            NSTextFieldDelegate>

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage;

@end
