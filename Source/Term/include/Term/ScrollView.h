// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>

@class NCTermView;
namespace nc::term {
    class Screen;
    class Settings;
}


@interface NCTermScrollView : NSScrollView

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top;
- (id)initWithFrame:(NSRect)frameRect
        attachToTop:(bool)top
           settings:(std::shared_ptr<nc::term::Settings>)settings;

@property (nonatomic, readonly) NCTermView          *view;
@property (nonatomic, readonly) nc::term::Screen    &screen;
@property (nonatomic, readonly) NSEdgeInsets         viewInsets;
@property (nonatomic, readwrite) NSCursor           *customCursor;
@property (nonatomic, readwrite) std::function<void(int sx, int sy)> onScreenResized;

@end
