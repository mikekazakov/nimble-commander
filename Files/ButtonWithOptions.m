//
//  ButtonWithOptions.m
//  Directories
//
//  Created by Pavel Dogurevich on 17.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "ButtonWithOptions.h"

@interface NSSegmentedCell ()
- (void)setMenuIndicatorShown:(BOOL)shown forSegment:(NSInteger)segment;
@end

@implementation ButtonWithOptions
{
    SEL m_Action;
    id m_Target;
    BOOL m_Default;
    BOOL m_Awaken;
}

- (void)MakeDefault
{
    m_Default = YES;
    
    if (m_Awaken)
    {
        [self.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
        self.selectedSegment = 0;
    }
}

- (void)awakeFromNib
{
    m_Action = self.action;
    m_Target = self.target;
    self.action = nil;
    self.target = nil;
    
    if (self.segmentCount != 2) self.segmentCount = 2;
    if (self.segmentStyle != NSSegmentStyleRounded)
        self.segmentStyle = NSSegmentStyleRounded;
    
    [self setWidth:18 forSegment:1];
    if (self.menu)
        [self setMenu:self.menu forSegment:1];
    
    // TODO: using private API! App could possibly be rejected by Apple (but not necessarily).
    // Any workarounds?
    if ([self.cell respondsToSelector:@selector(setMenuIndicatorShown:forSegment:)])
        [self.cell setMenuIndicatorShown:YES forSegment:1];
    
    if (!m_Default)
    {
        [self.cell setTrackingMode:NSSegmentSwitchTrackingMomentary];
    }
    else
    {
        [self.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
        self.selectedSegment = 0;
    }
    
    m_Awaken = YES;
}

- (BOOL)sendAction:(SEL)_action to:(id)_target
{
	NSInteger segment = [self selectedSegment];
	if (segment == 0)
    {
        _action = m_Action;
        _target = m_Target;
	}
	
	return [super sendAction:_action to:_target];
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    if (m_Default && m_Action && m_Target)
    {
        NSString *chars = _event.charactersIgnoringModifiers;
        if ([chars isEqual: @"\r"])
        {
            [super sendAction:m_Action to:m_Target];
            return YES;
        }
    }
    
    return [super performKeyEquivalent:_event];
}

@end
