// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SheetController.h>
#include "../States/FilePanels/PanelViewPresentationItemsColoringFilter.h"

@interface PreferencesWindowPanelsTabColoringFilterSheet : SheetController

- (id) initWithFilter:(PanelViewPresentationItemsColoringFilter)_filter;
- (IBAction)OnOK:(id)sender;

@property (nonatomic, readonly) PanelViewPresentationItemsColoringFilter filter;
@property (nonatomic) IBOutlet NSButton *executable;
@property (nonatomic) IBOutlet NSButton *hidden;
@property (nonatomic) IBOutlet NSButton *directory;
@property (nonatomic) IBOutlet NSButton *symlink;
@property (nonatomic) IBOutlet NSButton *regular;
@property (nonatomic) IBOutlet NSButton *selected;
@property (nonatomic) IBOutlet NSTextField *mask;


@end
