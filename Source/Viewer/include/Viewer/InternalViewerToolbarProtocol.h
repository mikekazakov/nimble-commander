// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@protocol InternalViewerToolbarProtocol <NSObject>

@required
- (IBAction)onInternalViewerToolbarSettings:(id)sender;
@property(nonatomic) IBOutlet NSToolbar *internalViewerToolbar;
@property(nonatomic) IBOutlet NSSearchField *internalViewerToolbarSearchField;
@property(nonatomic) IBOutlet NSProgressIndicator *internalViewerToolbarSearchProgressIndicator;
@property(nonatomic) IBOutlet NSPopover *internalViewerToolbarPopover;

@end
