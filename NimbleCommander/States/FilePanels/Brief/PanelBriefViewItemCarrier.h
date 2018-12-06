// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class PanelBriefViewItem;
struct PanelBriefViewItemLayoutConstants;

@interface PanelBriefViewItemCarrier : NSView

@property (nonatomic, weak) PanelBriefViewItem                 *controller;
@property (nonatomic)       NSColor                            *background;
@property (nonatomic)       NSString                           *filename;
@property (nonatomic)       NSColor                            *filenameColor;
@property (nonatomic)       NSImage                            *icon;
@property (nonatomic)       bool                                isSymlink;
@property (nonatomic)       PanelBriefViewItemLayoutConstants   layoutConstants;
@property (nonatomic)       std::pair<int16_t, int16_t>         qsHighlight;
@property (nonatomic)       bool                                highlighted;

- (void) setupFieldEditor:(NSScrollView*)_editor;

@end
