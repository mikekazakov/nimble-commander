// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/States/FilePanels/PanelView.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include "FilePanelsTabbedHolder.h"
#include "FilePanelMainSplitView.h"
#include <Utility/ObjCpp.h>
#include <Habanero/dispatch_cpp.h>

static const auto g_MidGuideGap = 24.;
static const auto g_MinPanelWidth = 120;
static const auto g_ResizingGran = 14.;

@implementation FilePanelMainSplitView
{
    // if there's no overlays - these will be nils
    // if any part becomes overlayed - basic view is backed up in this array
    FilePanelsTabbedHolder *m_BasicViews[2];
    ThemesManager::ObservationTicket m_ThemeChangesObservation;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        self.vertical = true;
        self.dividerStyle = NSSplitViewDividerStyleThin;
        self.delegate = self;
        
        FilePanelsTabbedHolder *th1 = [[FilePanelsTabbedHolder alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        [self addSubview:th1];
        FilePanelsTabbedHolder *th2 = [[FilePanelsTabbedHolder alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        [self addSubview:th2];

        __weak FilePanelMainSplitView* weak_self = self;
        m_ThemeChangesObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::FilePanelsGeneral,
            [=]{ [weak_self setNeedsDisplay:true];});
    }
    return self;
}

- (CGFloat)dividerThickness
{
    return 1;
}

- (BOOL)isOpaque
{
    return true;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
    auto mid = std::floor(self.frame.size.width / 2.);
    if( proposedPosition > mid - g_MidGuideGap && proposedPosition < mid + g_MidGuideGap )
        return mid;
    
    return proposedPosition;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return splitView.frame.size.width - g_MinPanelWidth;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return g_MinPanelWidth;
}

- (void)drawDividerInRect:(NSRect)rect
{
    if( auto c = CurrentTheme().FilePanelsGeneralSplitterColor() ) {
        [c set];
        if( c.alphaComponent == 1. )
            NSRectFill(rect);
        else
            NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
    }
    else
        NSDrawWindowBackground(rect);
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

- (void) swapViews
{
    NSView *left = self.subviews[0];
    NSView *right = self.subviews[1];

    NSRect leftrect = left.frame;
    NSRect rightrect = right.frame;
    
    self.subviews = @[right, left];
    
    left.frame = rightrect;
    right.frame = leftrect;

    std::swap(m_BasicViews[0], m_BasicViews[1]);
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

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    const auto mod = theEvent.modifierFlags;
    const auto unicode = [characters characterAtIndex:0];
    
    static ActionsShortcutsManager::ShortCut hk_move_left, hk_move_right;
    static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater({&hk_move_left, &hk_move_right},
                                                                     {"menu.view.panels_position.move_left", "menu.view.panels_position.move_right"});
    
    if( hk_move_left.IsKeyDown(unicode, mod) ) {
        [self OnViewPanelsPositionMoveLeft:self];
        return true;
    }

    if( hk_move_right.IsKeyDown(unicode, mod) ) {
        [self OnViewPanelsPositionMoveRight:self];
        return true;
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (IBAction)OnViewPanelsPositionMoveLeft:(id)sender
{
    dispatch_assert_main_queue();
    if( self.anyCollapsed ) {
        if( self.isRightCollapsed )
            [self expandRightView];
        return;
    }
    
    NSView *v1 = self.subviews[0];
    NSView *v2 = self.subviews[1];
    NSRect left  = v1.frame;
    NSRect right = v2.frame;
    
    auto gran = g_ResizingGran;
    
    left.size.width -= gran;
    right.origin.x -= gran;
    right.size.width += gran;
    if(left.size.width < 0) {
        right.origin.x -= left.size.width;
        right.size.width += left.size.width;
        left.size.width = 0;
    }

    if( left.size.width < g_MinPanelWidth ) {
        [self collapseLeftView];
        if( auto h = objc_cast<FilePanelsTabbedHolder>(v2) )
            [self.window makeFirstResponder:h.current];
        else
            [self.window makeFirstResponder:v2];
        return;
    }

    v1.frame = left;
    v2.frame = right;
    [self setNeedsLayout:true];
}

- (IBAction)OnViewPanelsPositionMoveRight:(id)sender
{
    dispatch_assert_main_queue();
    if( self.anyCollapsed ) {
        if( self.isLeftCollapsed )
            [self expandLeftView];
        return;
    }
    
    NSView *v1 = self.subviews[0];
    NSView *v2 = self.subviews[1];
    NSRect left  = v1.frame;
    NSRect right = v2.frame;
    
    auto gran = g_ResizingGran;
    
    left.size.width += gran;
    right.origin.x += gran;
    right.size.width -= gran;
    if(right.size.width < 0) {
        left.size.width += right.size.width;
        right.origin.x -= right.size.width;
        right.size.width = 0;
    }
    
    if( right.size.width < g_MinPanelWidth ) {
        [self collapseRightView];
        if( auto h = objc_cast<FilePanelsTabbedHolder>(v1) )
            [self.window makeFirstResponder:h.current];
        else
            [self.window makeFirstResponder:v1];
        return;
    }
    
    v1.frame = left;
    v2.frame = right;
    [self setNeedsLayout:true];
}

- (void) collapseLeftView
{
    dispatch_assert_main_queue();    
    if( self.isLeftCollapsed )
        return;
    NSView *right = [self.subviews objectAtIndex:1];
    NSView *left  = [self.subviews objectAtIndex:0];
    left.hidden = true;
    right.frameSize = NSMakeSize(self.frame.size.width, right.frame.size.height);
    [self display];
}

- (void) expandLeftView
{
    dispatch_assert_main_queue();
    if( !self.isLeftCollapsed )
        return;

    NSView *left  = [self.subviews objectAtIndex:0];
    NSView *right = [self.subviews objectAtIndex:1];
    left.hidden = false;
    CGFloat dividerThickness = self.dividerThickness;
    NSRect leftFrame = left.frame;
    NSRect rightFrame = right.frame;
    rightFrame.size.width = rightFrame.size.width - leftFrame.size.width - dividerThickness;
    rightFrame.origin.x = leftFrame.size.width + dividerThickness;
    right.frame = rightFrame;
    [self display];
}

- (void) collapseRightView
{
    dispatch_assert_main_queue();
    if( self.isRightCollapsed )
        return;
    NSView *right = [self.subviews objectAtIndex:1];
    NSView *left  = [self.subviews objectAtIndex:0];
    right.hidden = true;
    left.frameSize = NSMakeSize(self.frame.size.width, left.frame.size.height);
    [self display];
}

- (void) expandRightView
{
    dispatch_assert_main_queue();
    if( !self.isRightCollapsed )
        return;
    NSView *left  = [self.subviews objectAtIndex:0];
    NSView *right = [self.subviews objectAtIndex:1];
    right.hidden = false;
    CGFloat dividerThickness = self.dividerThickness;
    NSRect leftFrame = left.frame;
    NSRect rightFrame = right.frame;
    leftFrame.size.width = leftFrame.size.width - rightFrame.size.width - dividerThickness;
    rightFrame.origin.x = leftFrame.size.width + dividerThickness;
    left.frameSize = leftFrame.size;
    right.frame = rightFrame;
    [self display];
}

@end

