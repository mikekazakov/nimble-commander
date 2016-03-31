//
//  PreferencesWindowHotkeysTab.h
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"

@interface PreferencesWindowHotkeysTab : NSViewController<RHPreferencesViewControllerProtocol,
                                                            NSTableViewDataSource,
                                                            NSTableViewDelegate>

@end
