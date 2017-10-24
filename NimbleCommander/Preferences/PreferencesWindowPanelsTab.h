//
//  PreferencesWindowPanelsTab.h
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>


@interface PreferencesWindowPanelsTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                            NSTableViewDataSource,
                                                            NSTableViewDelegate,
                                                            NSTextFieldDelegate>

@end
