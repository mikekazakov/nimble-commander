// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>
#include <Utility/Tags.h>
#include <span>

@interface NCPanelListViewTagsView : NSView

- (void)setTags:(std::span<const nc::utility::Tags::Tag>)_tags;

- (void)buildPresentation;

@end
