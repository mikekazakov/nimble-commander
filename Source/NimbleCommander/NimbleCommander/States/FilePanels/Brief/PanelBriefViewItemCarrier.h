// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Panel/PanelDataItemVolatileData.h>

@class PanelBriefViewItem;
@class NCPanelViewFieldEditor;
struct PanelBriefViewItemLayoutConstants;

@interface PanelBriefViewItemCarrier : NSView

@property(nonatomic, weak) PanelBriefViewItem *controller;
@property(nonatomic) NSColor *backgroundColor;
@property(nonatomic) NSColor *tagAccentColor;
@property(nonatomic) NSString *filename;
@property(nonatomic) NSColor *filenameColor;
@property(nonatomic) NSImage *icon;
@property(nonatomic) bool isSymlink;
@property(nonatomic) PanelBriefViewItemLayoutConstants layoutConstants;
@property(nonatomic) nc::panel::data::QuickSearchHiglight qsHighlight;
@property(nonatomic) bool highlighted;

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor;

@end
