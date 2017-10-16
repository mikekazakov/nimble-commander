//
//  TermScrollView.h
//  Files
//
//  Created by Michael G. Kazakov on 20/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

@class TermView;
namespace nc::term {
    class Screen;
    class Settings;
}


@interface TermScrollView : NSScrollView

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top;
- (id)initWithFrame:(NSRect)frameRect
        attachToTop:(bool)top
        settings:(shared_ptr<nc::term::Settings>)settings;

@property (nonatomic, readonly) TermView    *view;
@property (nonatomic, readonly) nc::term::Screen  &screen;

@end
