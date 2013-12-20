//
//  FilePanelMainSplitView.mm
//  Files
//
//  Created by Michael G. Kazakov on 05.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FilePanelMainSplitView.h"
#import "PanelView.h"
#import "ModernPanelViewPresentation.h"
#import "ClassicPanelViewPresentation.h"

@implementation FilePanelMainSplitView
{
    PanelView *m_BasicViews[2]; // if there's no overlays - this will be nils
                             // if any part becomes overlayed - basic view is backed up in this array
    
//    __weak NSView *m_Overlays[2];
    double m_Prop;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        [self setVertical:true];
        [self setDividerStyle:NSSplitViewDividerStyleThin];
        [self setDelegate:self];
        m_Prop = 0.5;
    }
    return self;
}

- (CGFloat)dividerThickness
{
    return [self AnyCollapsed] ? 1 : 0;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
    m_Prop = proposedPosition / [self frame].size.width;
    
    PanelView *v;
    if(m_BasicViews[0]) v = m_BasicViews[0];
    else if(m_BasicViews[1]) v = m_BasicViews[1];
    else v = [[self subviews] objectAtIndex:0];
    
    if(dynamic_cast<ModernPanelViewPresentation*>([v Presentation]))
    {
        return proposedPosition;
    }
    else
    {
        float gran = dynamic_cast<ClassicPanelViewPresentation*>([v Presentation])->Granularity();
        float rest = fmod(proposedPosition, gran);
        return proposedPosition - rest;
    }
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSRect newFrame  = [splitView frame];
    
    if (newFrame.size.width == oldSize.width) {                 // if the width hasn't changed
        [splitView adjustSubviews];                             // tell sender to adjust subviews
        return;
    }
    
    PanelView *v;
    if(m_BasicViews[0]) v = m_BasicViews[0];
    else if(m_BasicViews[1]) v = m_BasicViews[1];
    else v = [[self subviews] objectAtIndex:0];
        
    if(ClassicPanelViewPresentation *p = dynamic_cast<ClassicPanelViewPresentation*>([v Presentation]))
    {
        NSRect leftRect  = [[[splitView subviews] objectAtIndex:0] frame];
        NSRect rightRect = [[[splitView subviews] objectAtIndex:1] frame];
        
        float gran = p->Granularity();
        float center_x = m_Prop * newFrame.size.width;
        float rest = fmod(center_x, gran);
        
        leftRect.origin = NSMakePoint(0, 0);
        leftRect.size.height = newFrame.size.height;
        leftRect.size.width = center_x - rest;
        [[[splitView subviews] objectAtIndex:0] setFrame:leftRect];
        
        rightRect.origin.y = 0;
        rightRect.origin.x = leftRect.size.width + 1;
        rightRect.size.height = newFrame.size.height;
        rightRect.size.width = newFrame.size.width - leftRect.size.width;
        [[[splitView subviews] objectAtIndex:1] setFrame:rightRect];
    }
    else
        [splitView adjustSubviews];
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return [splitView frame].size.width - 100;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 100;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return YES;
}

- (bool) LeftCollapsed
{
    auto views = [self subviews];
    if(views.count == 0) return false;
    return [self isSubviewCollapsed:[views objectAtIndex:0]];
}

- (bool) RightCollapsed
{
    auto views = [self subviews];
    if(views.count < 2) return false;
    return [self isSubviewCollapsed:[views objectAtIndex:1]];
}

- (bool) AnyCollapsed
{
    auto views = [self subviews];
    if(views.count == 0) return false;
    return [self isSubviewCollapsed:[views objectAtIndex:0]] ||
        [self isSubviewCollapsed:[views objectAtIndex:1]];
}

- (bool) AnyCollapsedOrOverlayed
{
    if(m_BasicViews[0] != nil || m_BasicViews[1] != nil)
        return true;
    
    auto views = [self subviews];
    if(views.count == 0)
        return false;
    return [self isSubviewCollapsed:[views objectAtIndex:0]] ||
        [self isSubviewCollapsed:[views objectAtIndex:1]];
}

- (void) SwapViews
{
    NSView *left = [[self subviews] objectAtIndex:0];
    NSView *right = [[self subviews] objectAtIndex:1];

    NSRect leftrect = [left frame];
    NSRect rightrect = [right frame];
    
    NSArray *views = [NSArray arrayWithObjects:right, left, nil];
    [self setSubviews:views];
    
    [left setFrame:rightrect];
    [right setFrame:leftrect];

    swap(m_BasicViews[0], m_BasicViews[1]);
    [m_BasicViews[0] setFrame:leftrect];
    [m_BasicViews[1] setFrame:rightrect];
}

- (void) SetBasicViews:(PanelView*)_v1 second:(PanelView*)_v2
{
    [self addSubview:_v1];
    [self addSubview:_v2];
}

- (void) SetLeftOverlay:(NSView*)_o
{
    NSRect leftRect = [[[self subviews] objectAtIndex:0] frame];
    if(_o != nil)
    {
        [_o setFrame:leftRect];
        if(m_BasicViews[0])
        {
            [self replaceSubview:[[self subviews] objectAtIndex:0] with:_o];
        }
        else
        {
            m_BasicViews[0] = [[self subviews] objectAtIndex:0];
            [self replaceSubview:m_BasicViews[0] with:_o];
        }
    }
    else
    {
        if(m_BasicViews[0] != nil)
        {
            [m_BasicViews[0] setFrame:leftRect];
            [self replaceSubview:[[self subviews] objectAtIndex:0] with:m_BasicViews[0]];
            m_BasicViews[0] = nil;
        }
    }
}

- (void) SetRightOverlay:(NSView*)_o
{
    NSRect rightRect = [[[self subviews] objectAtIndex:1] frame];
    if(_o != nil)
    {
        [_o setFrame:rightRect];
        
        if(m_BasicViews[1])
        {
            [self replaceSubview:[[self subviews] objectAtIndex:1] with:_o];
        }
        else
        {
            m_BasicViews[1] = [[self subviews] objectAtIndex:1];
            [self replaceSubview:m_BasicViews[1] with:_o];
        }
    }
    else
    {
        if(m_BasicViews[1] != nil)
        {
            [m_BasicViews[1] setFrame:rightRect];
            [self replaceSubview:[[self subviews] objectAtIndex:1] with:m_BasicViews[1]];
            m_BasicViews[1] = nil;
        }
    }
//    [[[self subviews] objectAtIndex:1] setFrame:rightRect];
}

- (bool) AnyOverlayed
{
    return m_BasicViews[0] != nil || m_BasicViews[1] != nil;
}

- (bool) LeftOverlayed
{
    return m_BasicViews[0] != nil;
}

- (bool) RightOverlayed
{
    return m_BasicViews[1] != nil;
}

- (bool) IsViewCollapsedOrOverlayed:(NSView*)_v
{
    if(m_BasicViews[0] == _v ||
       m_BasicViews[1] == _v)
        return true;
    
    return [self isSubviewCollapsed:_v];
}

@end

