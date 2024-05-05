// Copyright (C) 2014-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Utility/SheetController.h>
#include <Panel/UI/PanelViewPresentationItemsColoringFilter.h>

@interface PreferencesWindowPanelsTabColoringFilterSheet : SheetController

- (id)initWithFilter:(nc::panel::PresentationItemsColoringFilter)_filter;
- (IBAction)OnOK:(id)sender;

@property(nonatomic, readonly) nc::panel::PresentationItemsColoringFilter filter;
@property(nonatomic) IBOutlet NSButton *executable;
@property(nonatomic) IBOutlet NSButton *hidden;
@property(nonatomic) IBOutlet NSButton *directory;
@property(nonatomic) IBOutlet NSButton *symlink;
@property(nonatomic) IBOutlet NSButton *regular;
@property(nonatomic) IBOutlet NSButton *selected;
@property(nonatomic) IBOutlet NSTextField *mask;

@end
