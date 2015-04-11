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
#import "FilePanelsTabbedHolder.h"
#import "AppDelegate.h"
#import "Common.h"

static CGColorRef DividerColor(bool _wnd_active)
{
    static CGColorRef act = CGColorCreateGenericRGB(176/255.0, 176/255.0, 176/255.0, 1.0);
    static CGColorRef inact = CGColorCreateGenericRGB(225/255.0, 225/255.0, 225/255.0, 1.0);
    return _wnd_active ? act : inact;
}

@implementation FilePanelMainSplitView
{
    FilePanelsTabbedHolder *m_BasicViews[2]; // if there's no overlays - this will be nils
                                             // if any part becomes overlayed - basic view is backed up in this array
    double m_Prop;
    double m_DividerThickness;
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
        m_DividerThickness = 1.;
        
        FilePanelsTabbedHolder *th1 = [[FilePanelsTabbedHolder alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        [self addSubview:th1];
        FilePanelsTabbedHolder *th2 = [[FilePanelsTabbedHolder alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        [self addSubview:th2];

        [self observeValueForKeyPath:@"skin" ofObject:AppDelegate.me change:nil context:nullptr];
        [AppDelegate.me addObserver:self forKeyPath:@"skin" options:0 context:NULL];
    }
    return self;
}

- (void) dealloc
{
    [AppDelegate.me removeObserver:self forKeyPath:@"skin"];
}

- (CGFloat)dividerThickness
{
    return self.anyCollapsed ? 1 : m_DividerThickness;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
    m_Prop = proposedPosition / self.frame.size.width;
    
    if(AppDelegate.me.skin == ApplicationSkin::Modern)
        return proposedPosition;
    else if(ClassicPanelViewPresentation *p = dynamic_cast<ClassicPanelViewPresentation*>(self.leftTabbedHolder.current.presentation)) {
        float gran = p->Granularity();
        float rest = fmod(proposedPosition, gran);
        return proposedPosition - rest;
    }
    return proposedPosition;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSRect newFrame  = splitView.frame;
    
    // if the width hasn't changed - tell sender to adjust subviews
    // this is also true for modern presentation - default behaviour that case
    if (newFrame.size.width == oldSize.width || AppDelegate.me.skin == ApplicationSkin::Modern) {
        [splitView adjustSubviews];
        return;
    }
    
    [self resizeSubviewsManually];
}

- (void)resizeSubviewsManually
{
    NSRect newFrame = self.frame;
    if(ClassicPanelViewPresentation *p = dynamic_cast<ClassicPanelViewPresentation*>(self.leftTabbedHolder.current.presentation)) {
        NSRect leftRect  = [self.subviews[0] frame];
        NSRect rightRect = [self.subviews[1] frame];
        
        float gran = p->Granularity();
        float center_x = m_Prop * newFrame.size.width;
        float rest = fmod(center_x, gran);
        
        leftRect.origin = NSMakePoint(0, 0);
        leftRect.size.height = newFrame.size.height;
        leftRect.size.width = center_x - rest;
        [self.subviews[0] setFrame:leftRect];
        
        rightRect.origin.y = 0;
        rightRect.origin.x = leftRect.size.width + 1;
        rightRect.size.height = newFrame.size.height;
        rightRect.size.width = newFrame.size.width - leftRect.size.width;
        [self.subviews[1] setFrame:rightRect];
        return;
    }
    [self adjustSubviews];
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return splitView.frame.size.width - 100;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 100;
}

- (void)drawDividerInRect:(NSRect)rect
{
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSaveGState(context);    
    CGContextSetFillColorWithColor(context, DividerColor(self.window.isKeyWindow));
    CGContextFillRect(context, rect);
    CGContextRestoreGState(context);
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return YES;
}

- (bool) isLeftCollapsed
{
    if(self.subviews.count == 0) return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:0]];
}

- (bool) isRightCollapsed
{
    if(self.subviews.count < 2) return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:1]];
}

- (bool) anyCollapsed
{
    if(self.subviews.count == 0)
        return false;
    return [self isSubviewCollapsed:self.subviews[0]] || [self isSubviewCollapsed:self.subviews[1]];
}

- (bool) anyCollapsedOrOverlayed
{
    if(m_BasicViews[0] != nil || m_BasicViews[1] != nil)
        return true;
    
    if(self.subviews.count == 0)
        return false;
    return [self isSubviewCollapsed:self.subviews[0]] || [self isSubviewCollapsed:self.subviews[1]];
}

- (void) SwapViews
{
    NSView *left = self.subviews[0];
    NSView *right = self.subviews[1];

    NSRect leftrect = left.frame;
    NSRect rightrect = right.frame;
    
    self.subviews = @[right, left];
    
    left.frame = rightrect;
    right.frame = leftrect;

    swap(m_BasicViews[0], m_BasicViews[1]);
    m_BasicViews[0].frame = leftrect;
    m_BasicViews[1].frame = rightrect;
}

- (FilePanelsTabbedHolder*) leftTabbedHolder
{
    if(m_BasicViews[0])
        return m_BasicViews[0];
    assert( self.subviews.count == 2 );
    assert( objc_cast<FilePanelsTabbedHolder>(self.subviews[0]) );
    return self.subviews[0];
}

- (FilePanelsTabbedHolder*) rightTabbedHolder
{
    if(m_BasicViews[1])
        return m_BasicViews[1];
    assert( self.subviews.count == 2 );
    assert( objc_cast<FilePanelsTabbedHolder>(self.subviews[1]) );
    return self.subviews[1];
}

- (NSView*)leftOverlay
{
    if(m_BasicViews[0] == nil)
        return nil;
    return self.subviews[0];
}

- (NSView*)rightOverlay
{
    if(m_BasicViews[1] == nil)
        return nil;
    return self.subviews[1];
}

- (void)setLeftOverlay:(NSView*)_o
{
    NSRect leftRect = [self.subviews[0] frame];
    if(_o != nil) {
        _o.frame = leftRect;
        if(m_BasicViews[0]) {
            [self replaceSubview:self.subviews[0] with:_o];
        }
        else {
            m_BasicViews[0] = self.subviews[0];
            [self replaceSubview:m_BasicViews[0] with:_o];
        }
    }
    else {
        if(m_BasicViews[0] != nil) {
            m_BasicViews[0].frame = leftRect;
            [self replaceSubview:self.subviews[0] with:m_BasicViews[0]];
            m_BasicViews[0] = nil;
        }
    }
}

- (void)setRightOverlay:(NSView*)_o
{
    NSRect rightRect = [self.subviews[1] frame];
    if(_o != nil) {
        _o.frame = rightRect;
        
        if(m_BasicViews[1]) {
            [self replaceSubview:self.subviews[1] with:_o];
        }
        else {
            m_BasicViews[1] = self.subviews[1];
            [self replaceSubview:m_BasicViews[1] with:_o];
        }
    }
    else {
        if(m_BasicViews[1] != nil) {
            m_BasicViews[1].frame = rightRect;
            [self replaceSubview:self.subviews[1] with:m_BasicViews[1]];
            m_BasicViews[1] = nil;
        }
    }
}

- (bool) anyOverlayed
{
    return m_BasicViews[0] != nil || m_BasicViews[1] != nil;
}

- (bool) isLeftOverlayed
{
    return m_BasicViews[0] != nil;
}

- (bool) isRightOverlayed
{
    return m_BasicViews[1] != nil;
}

- (bool) isViewCollapsedOrOverlayed:(NSView*)_v
{
    if(m_BasicViews[0] == _v || m_BasicViews[1] == _v)
        return true;
    
    return [self isSubviewCollapsed:_v];
}

- (double) granularityForKeyResizing
{
    FilePanelsTabbedHolder *v;
    if(m_BasicViews[0]) v = m_BasicViews[0];
    else if(m_BasicViews[1]) v = m_BasicViews[1];
    else v = (FilePanelsTabbedHolder *)[self.subviews objectAtIndex:0];
    
    if(ClassicPanelViewPresentation *p = dynamic_cast<ClassicPanelViewPresentation*>(v.current.presentation))
        return p->Granularity();
    return 14.;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == AppDelegate.me && [keyPath isEqualToString:@"skin"]) {
        m_DividerThickness = AppDelegate.me.skin == ApplicationSkin::Classic ? 0 : 1;
        dispatch_to_main_queue_after(1ms, [=]{ [self resizeSubviewsManually]; });
    }
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    auto mod = theEvent.modifierFlags;
    mod &= ~NSAlphaShiftKeyMask;
    mod &= ~NSNumericPadKeyMask;
    mod &= ~NSFunctionKeyMask;
    auto unicode = [characters characterAtIndex:0];
    
    if(unicode == NSLeftArrowFunctionKey &&
       ((mod & NSDeviceIndependentModifierFlagsMask) == NSControlKeyMask ||
        (mod & NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSAlternateKeyMask)) &&
       !self.anyCollapsed) {
        NSView *v1 = self.subviews[0];
        NSView *v2 = self.subviews[1];
        NSRect left  = v1.frame;
        NSRect right = v2.frame;
        
        auto gran = self.granularityForKeyResizing;
        
        left.size.width -= gran;
        right.origin.x -= gran;
        right.size.width += gran;
        if(left.size.width < 0) {
            right.origin.x -= left.size.width;
            right.size.width += left.size.width;
            left.size.width = 0;
        }
        v1.frame = left;
        v2.frame = right;
        return true;
    }
    else if(unicode == NSRightArrowFunctionKey &&
            ((mod & NSDeviceIndependentModifierFlagsMask) == NSControlKeyMask ||
             (mod & NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSAlternateKeyMask)) &&
            !self.anyCollapsed) {
        NSView *v1 = self.subviews[0];
        NSView *v2 = self.subviews[1];
        NSRect left  = v1.frame;
        NSRect right = v2.frame;
        
        auto gran = self.granularityForKeyResizing;
        
        left.size.width += gran;
        right.origin.x += gran;
        right.size.width -= gran;
        if(right.size.width < 0) {
            left.size.width += right.size.width;
            right.origin.x -= right.size.width;
            right.size.width = 0;
        }
        v1.frame = left;
        v2.frame = right;
        return true;
    }
    
    return [super performKeyEquivalent:theEvent];
}

@end

