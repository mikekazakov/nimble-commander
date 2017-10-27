// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SheetController.h>
#include "../States/FilePanels/PanelViewPresentationItemsColoringFilter.h"

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
