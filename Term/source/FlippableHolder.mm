// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FlippableHolder.h"

@implementation NCTermFlippableHolder
{
    bool m_Flipped;
}

- (id)initWithFrame:(NSRect)frameRect andView:(NSView*)view beFlipped:(bool)flipped
{
    self = [super initWithFrame:frameRect];
    if(self) {
        m_Flipped = flipped;

        view.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:view];
        
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[view]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(view)]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[view]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(view)]];
        self.translatesAutoresizingMaskIntoConstraints = false;
    }
    return self;
}

- (BOOL) isFlipped
{
    return m_Flipped;
}

-(BOOL) isOpaque
{
    return YES;
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    if( self.subviews.count > 0 &&
        [self.subviews[0] respondsToSelector:@selector(adjustScroll:)] )
        return [self.subviews[0] adjustScroll:proposedVisibleRect];
        
    return proposedVisibleRect;
}

@end
