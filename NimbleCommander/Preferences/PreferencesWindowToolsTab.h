//
//  PreferencesWindowToolsTab.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 6/24/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "../../Files/3rd_party/RHPreferences/RHPreferences/RHPreferences.h"
#include "../States/FilePanels/ExternalToolsSupport.h"

@interface PreferencesWindowToolsTab : NSViewController<RHPreferencesViewControllerProtocol,
                                                        NSTableViewDataSource,
                                                        NSTableViewDelegate>

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage;

@end
