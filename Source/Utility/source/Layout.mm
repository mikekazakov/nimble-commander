// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>
#include "../include/Utility/Layout.h"

NSLayoutConstraint *LayoutConstraintForCenteringViewHorizontally(NSView *_a_view, NSView *_in_a_view)
{
    return [NSLayoutConstraint constraintWithItem:_a_view
                                        attribute:NSLayoutAttributeCenterX
                                        relatedBy:NSLayoutRelationEqual
                                           toItem:_in_a_view
                                        attribute:NSLayoutAttributeCenterX
                                       multiplier:1
                                         constant:0];
}

NSLayoutConstraint *LayoutConstraintForCenteringViewVertically(NSView *_a_view, NSView *_in_a_view)
{
    return [NSLayoutConstraint constraintWithItem:_a_view
                                        attribute:NSLayoutAttributeCenterY
                                        relatedBy:NSLayoutRelationEqual
                                           toItem:_in_a_view
                                        attribute:NSLayoutAttributeCenterY
                                       multiplier:1
                                         constant:0];
}
