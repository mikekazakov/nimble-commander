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
    
    double m_Prop;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        self.vertical = true;
        self.dividerStyle = NSSplitViewDividerStyleThin;
        self.delegate = self;
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
    m_Prop = proposedPosition / self.frame.size.width;
    
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
    NSRect newFrame  = splitView.frame;
    
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
        NSRect leftRect  = [[splitView.subviews objectAtIndex:0] frame];
        NSRect rightRect = [[splitView.subviews objectAtIndex:1] frame];
        
        float gran = p->Granularity();
        float center_x = m_Prop * newFrame.size.width;
        float rest = fmod(center_x, gran);
        
        leftRect.origin = NSMakePoint(0, 0);
        leftRect.size.height = newFrame.size.height;
        leftRect.size.width = center_x - rest;
        [[splitView.subviews objectAtIndex:0] setFrame:leftRect];
        
        rightRect.origin.y = 0;
        rightRect.origin.x = leftRect.size.width + 1;
        rightRect.size.height = newFrame.size.height;
        rightRect.size.width = newFrame.size.width - leftRect.size.width;
        [[splitView.subviews objectAtIndex:1] setFrame:rightRect];
    }
    else
        [splitView adjustSubviews];
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return splitView.frame.size.width - 100;
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
    if(self.subviews.count == 0) return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:0]];
}

- (bool) RightCollapsed
{
    if(self.subviews.count < 2) return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:1]];
}

- (bool) AnyCollapsed
{
    if(self.subviews.count == 0) return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:0]] ||
        [self isSubviewCollapsed:[self.subviews objectAtIndex:1]];
}

- (bool) AnyCollapsedOrOverlayed
{
    if(m_BasicViews[0] != nil || m_BasicViews[1] != nil)
        return true;
    
    if(self.subviews.count == 0)
        return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:0]] ||
        [self isSubviewCollapsed:[self.subviews objectAtIndex:1]];
}

- (void) SwapViews
{
    NSView *left = [self.subviews objectAtIndex:0];
    NSView *right = [self.subviews objectAtIndex:1];

    NSRect leftrect = left.frame;
    NSRect rightrect = right.frame;
    
    self.subviews = @[right, left];
    
    left.frame = rightrect;
    right.frame = leftrect;

    swap(m_BasicViews[0], m_BasicViews[1]);
    m_BasicViews[0].frame = leftrect;
    m_BasicViews[1].frame = rightrect;
}

- (void) SetBasicViews:(PanelView*)_v1 second:(PanelView*)_v2
{
    [self addSubview:_v1];
    [self addSubview:_v2];
}

- (NSView*)leftOverlay
{
    if(m_BasicViews[0] == nil)
        return nil;
    return [self.subviews objectAtIndex:0];
}

- (NSView*)rightOverlay
{
    if(m_BasicViews[1] == nil)
        return nil;
    return [self.subviews objectAtIndex:1];
}

- (void)setLeftOverlay:(NSView*)_o
{
    NSRect leftRect = [[self.subviews objectAtIndex:0] frame];
    if(_o != nil)
    {
        [_o setFrame:leftRect];
        if(m_BasicViews[0])
        {
            [self replaceSubview:[self.subviews objectAtIndex:0] with:_o];
        }
        else
        {
            m_BasicViews[0] = [self.subviews objectAtIndex:0];
            [self replaceSubview:m_BasicViews[0] with:_o];
        }
    }
    else
    {
        if(m_BasicViews[0] != nil)
        {
            m_BasicViews[0].frame = leftRect;
            [self replaceSubview:[self.subviews objectAtIndex:0] with:m_BasicViews[0]];
            m_BasicViews[0] = nil;
        }
    }
}

- (void)setRightOverlay:(NSView*)_o
{
    NSRect rightRect = [[self.subviews objectAtIndex:1] frame];
    if(_o != nil)
    {
        [_o setFrame:rightRect];
        
        if(m_BasicViews[1])
        {
            [self replaceSubview:[self.subviews objectAtIndex:1] with:_o];
        }
        else
        {
            m_BasicViews[1] = [self.subviews objectAtIndex:1];
            [self replaceSubview:m_BasicViews[1] with:_o];
        }
    }
    else
    {
        if(m_BasicViews[1] != nil)
        {
            m_BasicViews[1].frame = rightRect;
            [self replaceSubview:[self.subviews objectAtIndex:1] with:m_BasicViews[1]];
            m_BasicViews[1] = nil;
        }
    }
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

- (void)keyDown:(NSEvent *)event
{
    NSString* characters = event.charactersIgnoringModifiers;
    if ( characters.length != 1 ) {
        [super keyDown:event];
        return;
    }
    
    auto mod = event.modifierFlags;
    mod &= ~NSAlphaShiftKeyMask;
    mod &= ~NSNumericPadKeyMask;
    mod &= ~NSFunctionKeyMask;
    auto unicode = [characters characterAtIndex:0];
    
    if(unicode == NSLeftArrowFunctionKey &&
       ((mod & NSDeviceIndependentModifierFlagsMask) == NSControlKeyMask ||
        (mod & NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSAlternateKeyMask)) &&
       !self.AnyCollapsed)
    {
        NSView *v1 = [self.subviews objectAtIndex:0];
        NSView *v2 = [self.subviews objectAtIndex:1];
        NSRect left  = v1.frame;
        NSRect right = v2.frame;
        
        auto gran = self.granularityForKeyResizing;
  
        left.size.width -= gran;
        right.origin.x -= gran;
        right.size.width += gran;
        if(left.size.width < 0)
        {
            right.origin.x -= left.size.width;
            right.size.width += left.size.width;
            left.size.width = 0;
        }
        v1.frame = left;
        v2.frame = right;
        return;
    }
    else if(unicode == NSRightArrowFunctionKey &&
            ((mod & NSDeviceIndependentModifierFlagsMask) == NSControlKeyMask ||
             (mod & NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSAlternateKeyMask)) &&
            !self.AnyCollapsed)
    {
        NSView *v1 = [self.subviews objectAtIndex:0];
        NSView *v2 = [self.subviews objectAtIndex:1];
        NSRect left  = v1.frame;
        NSRect right = v2.frame;
        
        auto gran = self.granularityForKeyResizing;
        
        left.size.width += gran;
        right.origin.x += gran;
        right.size.width -= gran;
        if(right.size.width < 0)
        {
            left.size.width += right.size.width;
            right.origin.x -= right.size.width;
            right.size.width = 0;
        }
        v1.frame = left;
        v2.frame = right;
        return;
    }
    
    [super keyDown:event];
}

- (double) granularityForKeyResizing
{
    PanelView *v;
    if(m_BasicViews[0]) v = m_BasicViews[0];
    else if(m_BasicViews[1]) v = m_BasicViews[1];
    else v = (PanelView *)[self.subviews objectAtIndex:0];
    
    if(ClassicPanelViewPresentation *p = dynamic_cast<ClassicPanelViewPresentation*>(v.Presentation))
        return p->Granularity();
    return 14.;
}

@end

