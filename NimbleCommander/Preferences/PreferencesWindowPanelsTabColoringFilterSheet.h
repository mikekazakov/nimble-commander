//
//  PreferencesWindowPanelsTabColoringFilterSheet.h
//  Files
//
//  Created by Michael G. Kazakov on 05/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Utility/SheetController.h>
#include "../../Files/PanelViewPresentationItemsColoringFilter.h"

@interface PreferencesWindowPanelsTabColoringFilterSheet : SheetController

- (id) initWithFilter:(PanelViewPresentationItemsColoringFilter)_filter;
- (IBAction)OnOK:(id)sender;

@property (nonatomic, readonly) PanelViewPresentationItemsColoringFilter filter;
@property (strong) IBOutlet NSButton *executable;
@property (strong) IBOutlet NSButton *hidden;
@property (strong) IBOutlet NSButton *directory;
@property (strong) IBOutlet NSButton *symlink;
@property (strong) IBOutlet NSButton *regular;
@property (strong) IBOutlet NSButton *selected;
@property (strong) IBOutlet NSTextField *mask;


@end
