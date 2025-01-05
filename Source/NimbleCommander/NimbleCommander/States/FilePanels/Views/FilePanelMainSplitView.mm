// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/States/FilePanels/PanelView.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "FilePanelsTabbedHolder.h"
#include "FilePanelMainSplitView.h"
#include <Utility/ActionsShortcutsManager.h>
#include <Utility/ObjCpp.h>
#include <Base/dispatch_cpp.h>
#include <cmath>

static constexpr auto g_MidGuideGap = 24.;
static constexpr auto g_MinPanelWidth = 120;
static constexpr auto g_ResizingGran = 14.;
static constexpr auto g_DividerThickness = 1.;

@implementation FilePanelMainSplitView {
    // if there's no overlays - these will be nils
    // if any part becomes overlayed - basic view is backed up in this array
    FilePanelsTabbedHolder *m_BasicViews[2];
    nc::ThemesManager::ObservationTicket m_ThemeChangesObservation;
    double m_PreCollapseProp; // full width minus divider divided by left width
    const nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;
}

- (id)initWithFrame:(NSRect)_frame
    actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager
{
    self = [super initWithFrame:_frame];
    if( self ) {
        m_ActionsShortcutsManager = &_actions_shortcuts_manager;
        m_PreCollapseProp = 0.5;
        self.vertical = true;
        self.dividerStyle = NSSplitViewDividerStyleThin;
        self.delegate = self;

        FilePanelsTabbedHolder *th1 = [[FilePanelsTabbedHolder alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                            actionsShortcutsManager:*m_ActionsShortcutsManager];
        [self addSubview:th1];
        FilePanelsTabbedHolder *th2 = [[FilePanelsTabbedHolder alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                            actionsShortcutsManager:*m_ActionsShortcutsManager];
        [self addSubview:th2];

        __weak FilePanelMainSplitView *weak_self = self;
        m_ThemeChangesObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            nc::ThemesManager::Notifications::FilePanelsGeneral, [=] { [weak_self setNeedsDisplay:true]; });
    }
    return self;
}

- (CGFloat)dividerThickness
{
    return g_DividerThickness;
}

- (BOOL)isOpaque
{
    return true;
}

- (CGFloat)splitView:(NSSplitView *) [[maybe_unused]] splitView
    constrainSplitPosition:(CGFloat)proposedPosition
               ofSubviewAt:(NSInteger) [[maybe_unused]] dividerIndex
{
    auto mid = std::floor(self.frame.size.width / 2.);
    if( proposedPosition > mid - g_MidGuideGap && proposedPosition < mid + g_MidGuideGap )
        return mid;

    return proposedPosition;
}

- (void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
    // I've no idea why this isn't triggered automatically.
    // Without this adjustment the subviews sometimes end up with .5 coords when switching between
    // Retina and non-Retina.
    [self adjustSubviews];
}

- (CGFloat)splitView:(NSSplitView *)splitView
    constrainMaxCoordinate:(CGFloat) [[maybe_unused]] proposedMaximumPosition
               ofSubviewAt:(NSInteger) [[maybe_unused]] dividerIndex
{
    return splitView.frame.size.width - g_MinPanelWidth;
}

- (CGFloat)splitView:(NSSplitView *) [[maybe_unused]] splitView
    constrainMinCoordinate:(CGFloat) [[maybe_unused]] proposedMinimumPosition
               ofSubviewAt:(NSInteger) [[maybe_unused]] dividerIndex
{
    return g_MinPanelWidth;
}

- (void)drawDividerInRect:(NSRect)rect
{
    if( auto c = nc::CurrentTheme().FilePanelsGeneralSplitterColor() ) {
        [c set];
        if( c.alphaComponent == 1. )
            NSRectFill(rect);
        else
            NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
    }
    else
        NSDrawWindowBackground(rect);
}

- (BOOL)splitView:(NSSplitView *) [[maybe_unused]] splitView canCollapseSubview:(NSView *) [[maybe_unused]] subview
{
    return true;
}

- (bool)isLeftCollapsed
{
    if( self.subviews.count == 0 )
        return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:0]];
}

- (bool)isRightCollapsed
{
    if( self.subviews.count < 2 )
        return false;
    return [self isSubviewCollapsed:[self.subviews objectAtIndex:1]];
}

- (bool)anyCollapsed
{
    if( self.subviews.count == 0 )
        return false;
    return [self isSubviewCollapsed:self.subviews[0]] || [self isSubviewCollapsed:self.subviews[1]];
}

- (bool)anyCollapsedOrOverlayed
{
    if( m_BasicViews[0] != nil || m_BasicViews[1] != nil )
        return true;

    if( self.subviews.count == 0 )
        return false;
    return [self isSubviewCollapsed:self.subviews[0]] || [self isSubviewCollapsed:self.subviews[1]];
}

- (void)swapViews
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

- (FilePanelsTabbedHolder *)leftTabbedHolder
{
    if( m_BasicViews[0] )
        return m_BasicViews[0];
    assert(self.subviews.count == 2);
    assert(nc::objc_cast<FilePanelsTabbedHolder>(self.subviews[0]));
    return self.subviews[0];
}

- (FilePanelsTabbedHolder *)rightTabbedHolder
{
    if( m_BasicViews[1] )
        return m_BasicViews[1];
    assert(self.subviews.count == 2);
    assert(nc::objc_cast<FilePanelsTabbedHolder>(self.subviews[1]));
    return self.subviews[1];
}

- (NSView *)leftOverlay
{
    if( m_BasicViews[0] == nil )
        return nil;
    return self.subviews[0];
}

- (NSView *)rightOverlay
{
    if( m_BasicViews[1] == nil )
        return nil;
    return self.subviews[1];
}

- (void)setLeftOverlay:(NSView *)_o
{
    NSRect leftRect = [self.subviews[0] frame];
    if( _o != nil ) {
        _o.frame = leftRect;
        if( m_BasicViews[0] ) {
            [self replaceSubview:self.subviews[0] with:_o];
        }
        else {
            m_BasicViews[0] = self.subviews[0];
            [self replaceSubview:m_BasicViews[0] with:_o];
        }
    }
    else {
        if( m_BasicViews[0] != nil ) {
            m_BasicViews[0].frame = leftRect;
            [self replaceSubview:self.subviews[0] with:m_BasicViews[0]];
            m_BasicViews[0] = nil;
        }
    }
}

- (void)setRightOverlay:(NSView *)_o
{
    NSRect rightRect = [self.subviews[1] frame];
    if( _o != nil ) {
        _o.frame = rightRect;

        if( m_BasicViews[1] ) {
            [self replaceSubview:self.subviews[1] with:_o];
        }
        else {
            m_BasicViews[1] = self.subviews[1];
            [self replaceSubview:m_BasicViews[1] with:_o];
        }
    }
    else {
        if( m_BasicViews[1] != nil ) {
            m_BasicViews[1].frame = rightRect;
            [self replaceSubview:self.subviews[1] with:m_BasicViews[1]];
            m_BasicViews[1] = nil;
        }
    }
}

- (bool)anyOverlayed
{
    return m_BasicViews[0] != nil || m_BasicViews[1] != nil;
}

- (bool)isLeftOverlayed
{
    return m_BasicViews[0] != nil;
}

- (bool)isRightOverlayed
{
    return m_BasicViews[1] != nil;
}

- (bool)isViewCollapsedOrOverlayed:(NSView *)_v
{
    if( m_BasicViews[0] == _v || m_BasicViews[1] == _v )
        return true;

    return [self isSubviewCollapsed:_v];
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    struct Tags {
        int move_left = -1;
        int move_right = -1;
    };
    static const Tags tags = [&] {
        Tags t;
        t.move_left = m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.move_left").value();
        t.move_right = m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.move_right").value();
        return t;
    }();

    const std::optional<int> event_action_tag = m_ActionsShortcutsManager->FirstOfActionTagsFromShortcut(
        {reinterpret_cast<const int *>(&tags), sizeof(tags) / sizeof(int)},
        nc::utility::ActionShortcut::EventData(_event));

    if( event_action_tag == tags.move_left ) {
        [self OnViewPanelsPositionMoveLeft:self];
        return true;
    }

    if( event_action_tag == tags.move_right ) {
        [self OnViewPanelsPositionMoveRight:self];
        return true;
    }

    return [super performKeyEquivalent:_event];
}

- (IBAction)OnViewPanelsPositionMoveLeft:(id) [[maybe_unused]] sender
{
    dispatch_assert_main_queue();
    if( self.isLeftCollapsed ) {
        NSBeep();
        return;
    }
    if( self.isRightCollapsed ) {
        [self expandRightView];
        return;
    }

    NSView *v1 = self.subviews[0];
    NSView *v2 = self.subviews[1];
    NSRect left = v1.frame;
    NSRect right = v2.frame;

    auto gran = g_ResizingGran;

    left.size.width -= gran;
    right.origin.x -= gran;
    right.size.width += gran;
    if( left.size.width < 0 ) {
        right.origin.x -= left.size.width;
        right.size.width += left.size.width;
        left.size.width = 0;
    }

    if( left.size.width < g_MinPanelWidth ) {
        [self collapseLeftView];
        if( auto h = nc::objc_cast<FilePanelsTabbedHolder>(v2) )
            [self.window makeFirstResponder:h.current];
        else
            [self.window makeFirstResponder:v2];
        return;
    }

    v1.frame = left;
    v2.frame = right;
    [self setNeedsLayout:true];
}

- (IBAction)OnViewPanelsPositionMoveRight:(id) [[maybe_unused]] sender
{
    dispatch_assert_main_queue();
    if( self.isRightCollapsed ) {
        NSBeep();
        return;
    }
    if( self.isLeftCollapsed ) {
        [self expandLeftView];
        return;
    }

    NSView *v1 = self.subviews[0];
    NSView *v2 = self.subviews[1];
    NSRect left = v1.frame;
    NSRect right = v2.frame;

    auto gran = g_ResizingGran;

    left.size.width += gran;
    right.origin.x += gran;
    right.size.width -= gran;
    if( right.size.width < 0 ) {
        left.size.width += right.size.width;
        right.origin.x -= right.size.width;
        right.size.width = 0;
    }

    if( right.size.width < g_MinPanelWidth ) {
        [self collapseRightView];
        if( auto h = nc::objc_cast<FilePanelsTabbedHolder>(v1) )
            [self.window makeFirstResponder:h.current];
        else
            [self.window makeFirstResponder:v1];
        return;
    }

    v1.frame = left;
    v2.frame = right;
    [self setNeedsLayout:true];
}

- (void)collapseLeftView
{
    dispatch_assert_main_queue();
    if( self.isLeftCollapsed )
        return;
    NSView *right = [self.subviews objectAtIndex:1];
    NSView *left = [self.subviews objectAtIndex:0];
    left.hidden = true;
    right.frameSize = NSMakeSize(self.frame.size.width, right.frame.size.height);
    [self display];
}

- (void)expandLeftView
{
    dispatch_assert_main_queue();
    if( !self.isLeftCollapsed )
        return;

    NSView *left = [self.subviews objectAtIndex:0];
    NSView *right = [self.subviews objectAtIndex:1];
    left.hidden = false;

    NSRect left_frame = left.frame;
    NSRect right_frame = right.frame;
    const double full_width = self.frame.size.width;
    left_frame.size.width = std::round(full_width - g_DividerThickness) / m_PreCollapseProp;
    right_frame.origin.x = left_frame.size.width + g_DividerThickness;
    right_frame.size.width = full_width - right_frame.origin.x;

    left.frameSize = left_frame.size;
    right.frame = right_frame;
    [self display];
}

- (void)collapseRightView
{
    dispatch_assert_main_queue();
    if( self.isRightCollapsed )
        return;
    NSView *right = [self.subviews objectAtIndex:1];
    NSView *left = [self.subviews objectAtIndex:0];
    right.hidden = true;
    left.frameSize = NSMakeSize(self.frame.size.width, left.frame.size.height);
    [self display];
}

- (void)expandRightView
{
    dispatch_assert_main_queue();
    if( !self.isRightCollapsed )
        return;
    NSView *left = [self.subviews objectAtIndex:0];
    NSView *right = [self.subviews objectAtIndex:1];
    right.hidden = false;

    NSRect left_frame = left.frame;
    NSRect right_frame = right.frame;
    const double full_width = self.frame.size.width;
    left_frame.size.width = std::round(full_width - g_DividerThickness) / m_PreCollapseProp;
    right_frame.origin.x = left_frame.size.width + g_DividerThickness;
    right_frame.size.width = full_width - right_frame.origin.x;

    left.frameSize = left_frame.size;
    right.frame = right_frame;
    [self display];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)_item
{
    static const int move_left_tag =
        m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.move_left").value();
    static const int move_right_tag =
        m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.move_right").value();

    const long item_tag = _item.tag;
    if( item_tag == move_left_tag ) {
        return !self.isLeftCollapsed;
    }
    if( item_tag == move_right_tag ) {
        return !self.isRightCollapsed;
    }

    return true;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)_notification
{
    if( !self.isLeftCollapsed && !self.isRightCollapsed ) {
        NSView *left = [self.subviews objectAtIndex:0];
        const auto left_width = left.frame.size.width;
        const auto full_width = self.frame.size.width;
        if( left_width > 0. ) {
            m_PreCollapseProp = (full_width - g_DividerThickness) / left_width;
        }
    }
}

@end
