//
//  PreferencesWindowToolsTab.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 6/24/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

class ExternalToolsStorage;

@interface PreferencesWindowToolsTab : NSViewController<RHPreferencesViewControllerProtocol,
                                                        NSTableViewDataSource,
                                                        NSTableViewDelegate>

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage;

@end
