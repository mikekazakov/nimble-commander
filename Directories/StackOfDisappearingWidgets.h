//
//  StackOfDisappearingWidgets.h
//  Files
//
//  Created by Michael G. Kazakov on 12.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

enum class StackOfDisappearingWidgetsOrientation
{
    LeftToRight,
    RightToLeft
};

@interface StackOfDisappearingWidgets : NSObject
- (id)initWithOrientation:(StackOfDisappearingWidgetsOrientation) _orientation AnchorView:(NSView*)_view SuperView:(NSView*)_sview;


- (void) AddWidget:(NSView*)_widget;
- (void) Done;

@end
