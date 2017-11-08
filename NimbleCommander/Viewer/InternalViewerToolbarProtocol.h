// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@protocol InternalViewerToolbarProtocol <NSObject>

@required
- (IBAction)onInternalViewerToolbarSettings:(id)sender;
@property (nonatomic) IBOutlet NSToolbar *internalViewerToolbar;
@property (nonatomic) IBOutlet NSSearchField *internalViewerToolbarSearchField;
@property (nonatomic) IBOutlet NSProgressIndicator *internalViewerToolbarSearchProgressIndicator;
@property (nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarEncodingsPopUp;
@property (nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarModePopUp;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarPositionButton;
@property (nonatomic) IBOutlet NSTextField *internalViewerToolbarFileSizeLabel;
@property (nonatomic) IBOutlet NSPopover *internalViewerToolbarPopover;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarWordWrapCheckBox;

@end
