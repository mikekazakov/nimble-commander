//
//  TermScrollView.h
//  Files
//
//  Created by Michael G. Kazakov on 20/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

@class TermView;
class TermScreen;

@interface TermScrollView : NSScrollView

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top;

@property (nonatomic, readonly) TermView    *view;
@property (nonatomic, readonly) TermScreen  &screen;

@end
