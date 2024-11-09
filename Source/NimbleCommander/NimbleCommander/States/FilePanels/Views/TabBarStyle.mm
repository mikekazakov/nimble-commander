// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#import "TabBarStyle.h"
#import <MMTabBarView/MMTabStyle.h>
#import <MMTabBarView/MMAttachedTabBarButton.h>
#import <MMTabBarView/MMTabBarView.h>
#import <MMTabBarView/NSView+MMTabBarViewExtensions.h>
#import <MMTabBarView/NSBezierPath+MMTabBarViewExtensions.h>
#import <MMTabBarView/MMOverflowPopUpButton.h>
#import <MMTabBarView/MMTabBarView.Private.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <Base/mach_time.h>
#include <Utility/ObjCpp.h>

static const auto g_TabCloseSize = NSMakeSize(12, 12);
using namespace std::literals;

static NSImage *MakeTabCloseFreeImage()
{
    auto handler = []([[maybe_unused]] NSRect rc) -> BOOL {
        [nc::CurrentTheme().FilePanelsTabsPictogramColor() set];
        NSBezierPath *const bezier = [NSBezierPath bezierPath];
        [bezier moveToPoint:NSMakePoint(2.5, 2.5)];
        [bezier lineToPoint:NSMakePoint(9.5, 9.5)];
        [bezier moveToPoint:NSMakePoint(2.5, 9.5)];
        [bezier lineToPoint:NSMakePoint(9.5, 2.5)];
        [bezier stroke];
        return true;
    };
    return [NSImage imageWithSize:g_TabCloseSize flipped:false drawingHandler:handler];
}
static auto g_TabCloseFreeImage = MakeTabCloseFreeImage();

static NSImage *MakeTabCloseHoverImage()
{
    auto handler = [](NSRect rc) -> BOOL {
        [[nc::CurrentTheme().FilePanelsTabsPictogramColor() colorWithAlphaComponent:0.1] set];
        NSBezierPath *bezier = [NSBezierPath bezierPathWithRoundedRect:rc xRadius:2 yRadius:2];
        [bezier fill];

        [nc::CurrentTheme().FilePanelsTabsPictogramColor() set];
        bezier = [NSBezierPath bezierPath];
        [bezier moveToPoint:NSMakePoint(2.5, 2.5)];
        [bezier lineToPoint:NSMakePoint(9.5, 9.5)];
        [bezier moveToPoint:NSMakePoint(2.5, 9.5)];
        [bezier lineToPoint:NSMakePoint(9.5, 2.5)];
        [bezier stroke];
        return true;
    };
    return [NSImage imageWithSize:g_TabCloseSize flipped:false drawingHandler:handler];
}
static auto g_TabCloseHoverImage = MakeTabCloseHoverImage();

static NSImage *MakeTabClosePressedImage()
{
    auto handler = [](NSRect rc) -> BOOL {
        [[nc::CurrentTheme().FilePanelsTabsPictogramColor() colorWithAlphaComponent:0.2] set];
        NSBezierPath *bezier = [NSBezierPath bezierPathWithRoundedRect:rc xRadius:2 yRadius:2];
        [bezier fill];

        [nc::CurrentTheme().FilePanelsTabsPictogramColor() set];
        bezier = [NSBezierPath bezierPath];
        [bezier moveToPoint:NSMakePoint(2.5, 2.5)];
        [bezier lineToPoint:NSMakePoint(9.5, 9.5)];
        [bezier moveToPoint:NSMakePoint(2.5, 9.5)];
        [bezier lineToPoint:NSMakePoint(9.5, 2.5)];
        [bezier stroke];
        return true;
    };

    return [NSImage imageWithSize:g_TabCloseSize flipped:false drawingHandler:handler];
}
static auto g_TabClosePressedImage = MakeTabClosePressedImage();

static NSBezierPath *MakePlusShape()
{
    NSBezierPath *const bezier = [NSBezierPath bezierPath];
    [bezier moveToPoint:NSMakePoint(11.5, 6)];
    [bezier lineToPoint:NSMakePoint(11.5, 17)];
    [bezier moveToPoint:NSMakePoint(6, 11.5)];
    [bezier lineToPoint:NSMakePoint(17, 11.5)];
    return bezier;
}

static NSImage *MakeTabAddFreeImage()
{
    auto handler = []([[maybe_unused]] NSRect rc) -> BOOL {
        [nc::CurrentTheme().FilePanelsTabsPictogramColor() set];
        [MakePlusShape() stroke];
        return true;
    };
    return [NSImage imageWithSize:NSMakeSize(23, 23) flipped:false drawingHandler:handler];
}
static auto g_TabAddFreeImage = MakeTabAddFreeImage();

static NSImage *MakeTabAddHoverImage()
{
    auto handler = [](NSRect rc) -> BOOL {
        [[nc::CurrentTheme().FilePanelsTabsPictogramColor() colorWithAlphaComponent:0.1] set];
        NSBezierPath *const bezier = [NSBezierPath bezierPathWithRect:rc];
        [bezier fill];

        [nc::CurrentTheme().FilePanelsTabsPictogramColor() set];
        [MakePlusShape() stroke];
        return true;
    };

    return [NSImage imageWithSize:NSMakeSize(23, 23) flipped:false drawingHandler:handler];
}
static auto g_TabAddHoverImage = MakeTabAddHoverImage();

static NSImage *MakeTabAddPressedImage()
{
    auto handler = [](NSRect rc) -> BOOL {
        [[nc::CurrentTheme().FilePanelsTabsPictogramColor() colorWithAlphaComponent:0.2] set];
        NSBezierPath *const bezier = [NSBezierPath bezierPathWithRect:rc];
        [bezier fill];

        [nc::CurrentTheme().FilePanelsTabsPictogramColor() set];
        [MakePlusShape() stroke];
        return true;
    };
    return [NSImage imageWithSize:NSMakeSize(23, 23) flipped:false drawingHandler:handler];
}
static auto g_TabAddPressedImage = MakeTabAddPressedImage();

@implementation TabBarStyle {
    nc::ThemesManager::ObservationTicket m_Observation;
}

+ (NSString *)name
{
    return @"NC";
}

- (NSString *)name
{
    return [[self class] name];
}

- (id)init
{
    self = [super init];
    if( self ) {
    }
    return self;
}

- (BOOL)needsResizeTabsToFitTotalWidth
{
    return true;
}

static std::chrono::nanoseconds g_LastImagesRebuildTime{0};
- (NSSize)intrinsicContentSizeOfTabBarView:(MMTabBarView *)tabBarView
{
    if( !m_Observation ) {
        auto &tm = NCAppDelegate.me.themesManager;
        __weak MMTabBarView *v = tabBarView;
        m_Observation = tm.ObserveChanges(nc::ThemesManager::Notifications::FilePanelsTabs, [v] {
            if( g_LastImagesRebuildTime + 200ms < nc::base::machtime() ) {
                // make sure images will be rebuilt only by one object, not by all of them.
                g_TabCloseFreeImage = MakeTabCloseFreeImage();
                g_TabCloseHoverImage = MakeTabCloseHoverImage();
                g_TabClosePressedImage = MakeTabClosePressedImage();
                g_TabAddFreeImage = MakeTabAddFreeImage();
                g_TabAddHoverImage = MakeTabAddHoverImage();
                g_TabAddPressedImage = MakeTabAddPressedImage();
                g_LastImagesRebuildTime = nc::base::machtime();
            }

            if( MMTabBarView *const sv = v ) {
                [sv updateImages];
                [sv windowStatusDidChange:[[NSNotification alloc] initWithName:@"" object:nil userInfo:nil]];
                for( NSView *b in sv.subviews )
                    [b setNeedsDisplay:true];
            }
        });
    }

    return NSMakeSize(NSViewNoIntrinsicMetric, 24);
}

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{
    return 0.f;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{
    return 0.f;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{
    return 0.0f;
}

- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{
    return 24;
}

- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView
{
    return NSMakeSize(14, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
}

- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{
    return NSMakeSize(23, 23);
}

- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView
{
    NSRect theRect;
    NSSize buttonSize = tabBarView.addTabButtonSize;

    CGFloat xOffset = 0;
    MMAttachedTabBarButton *lastAttachedButton = tabBarView.lastAttachedButton;
    if( lastAttachedButton ) {
        xOffset += NSMaxX([lastAttachedButton stackingFrame]);
    }

    theRect = NSMakeRect(xOffset, NSMinY(tabBarView.bounds), buttonSize.width, buttonSize.height);

    return theRect;
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{

    if( orientation != MMTabBarHorizontalOrientation )
        return NO;

    return YES;
}

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton
                      ofTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{

    NSRect dragRect = [aButton stackingFrame];
    dragRect.size.width++;
    return dragRect;
}

- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
{

    [aButton setImage:g_TabAddFreeImage];
    [aButton setImagePosition:NSImageOnly];
    [aButton setAlternateImage:g_TabAddPressedImage];
    [aButton setRolloverImage:g_TabAddHoverImage];
}

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *) [[maybe_unused]] cell
{
    switch( type ) {
        case MMCloseButtonImageTypeStandard:
            return g_TabCloseFreeImage;
        case MMCloseButtonImageTypeRollover:
            return g_TabCloseHoverImage;
        case MMCloseButtonImageTypePressed:
            return g_TabClosePressedImage;
        case MMCloseButtonImageTypeDirty:
            return g_TabCloseFreeImage;
        case MMCloseButtonImageTypeDirtyRollover:
            return g_TabCloseHoverImage;
        case MMCloseButtonImageTypeDirtyPressed:
            return g_TabClosePressedImage;
        default:
            break;
    }
}

- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell
{
    static const auto paragraph_style = []() -> NSParagraphStyle * {
        NSMutableParagraphStyle *const ps = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
        ps.lineBreakMode = NSLineBreakByTruncatingTail;
        ps.alignment = NSTextAlignmentCenter;
        return ps;
    }();

    const auto attrs = @{
        NSFontAttributeName: nc::CurrentTheme().FilePanelsTabsFont(),
        NSForegroundColorAttributeName: nc::CurrentTheme().FilePanelsTabsTextColor(),
        NSParagraphStyleAttributeName: paragraph_style
    };
    return [[NSAttributedString alloc] initWithString:cell.title attributes:attrs];
}

- (void)drawTitleOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSRect rect = [cell titleRectForBounds:frame];

    const MMTabBarView *tabBarView = [controlView enclosingTabBarView];
    const bool wnd_active = [tabBarView isWindowActive];

    // draw title
    if( wnd_active ) {
        [cell.attributedStringValue drawInRect:rect];
    }
    else {
        // fiddle a bit with alpha
        NSMutableAttributedString *s =
            [[NSMutableAttributedString alloc] initWithAttributedString:cell.attributedStringValue];
        [s addAttribute:NSForegroundColorAttributeName
                  value:[nc::CurrentTheme().FilePanelsTabsTextColor() colorWithAlphaComponent:0.75]
                  range:NSMakeRange(0, s.length)];
        [s drawInRect:rect];
    }
}

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect
{
    const NSColor *bg_color = nc::CurrentTheme().FilePanelsTabsRegularNotKeyWndBackgroundColor();
    if( bg_color && bg_color != NSColor.clearColor ) {
        [bg_color set];
        NSRectFill(tabBarView.bounds);
    }
    else {
        NSDrawWindowBackground(tabBarView.bounds);
    }

    [nc::CurrentTheme().FilePanelsTabsSeparatorColor() set];
    NSBezierPath *bezier = [NSBezierPath bezierPath];
    [bezier moveToPoint:NSMakePoint(rect.origin.x, tabBarView.bounds.size.height - 0.5)];
    [bezier lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, tabBarView.bounds.size.height - 0.5)];
    [bezier stroke];
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *) [[maybe_unused]] cell
                 withFrame:(NSRect)frame
                    inView:(NSView *)controlView
{
    frame.size.height -= 1; // for horizontal divider drawn by drawBezelOfTabBarView

    MMAttachedTabBarButton *button = nc::objc_cast<MMAttachedTabBarButton>(controlView);

    const NSColor *bg_color = [&] {
        const MMTabBarView *const tabBarView = [controlView enclosingTabBarView];
        const bool wnd_active = [tabBarView isWindowActive];
        const bool tab_selected = [button state] == NSControlStateValueOn;
        const bool button_hovered = [button mouseHovered];
        // this might not work, check!!!:
        const bool tab_isfr =
            tab_selected && tabBarView.tabView.selectedTabViewItem.view == tabBarView.window.firstResponder;

        if( tab_selected ) {
            if( wnd_active ) {
                if( tab_isfr )
                    return nc::CurrentTheme().FilePanelsTabsSelectedKeyWndActiveBackgroundColor();
                else
                    return nc::CurrentTheme().FilePanelsTabsSelectedKeyWndInactiveBackgroundColor();
            }
            else
                return nc::CurrentTheme().FilePanelsTabsSelectedNotKeyWndBackgroundColor();
        }
        else {
            if( wnd_active ) {
                if( button_hovered )
                    return nc::CurrentTheme().FilePanelsTabsRegularKeyWndHoverBackgroundColor();
                else
                    return nc::CurrentTheme().FilePanelsTabsRegularKeyWndRegularBackgroundColor();
            }
            else
                return nc::CurrentTheme().FilePanelsTabsRegularNotKeyWndBackgroundColor();
        }
    }();

    if( bg_color && bg_color != NSColor.clearColor ) {
        [bg_color set];
        NSRectFill(frame);
    }
    else {
        NSDrawWindowBackground(frame);
    }

    [nc::CurrentTheme().FilePanelsTabsSeparatorColor() set];
    NSBezierPath *bezier = [NSBezierPath bezierPath];
    if( button.shouldDisplayLeftDivider ) {
        [bezier moveToPoint:NSMakePoint(NSMinX(frame) - 0.5, NSMinY(frame))];
        [bezier lineToPoint:NSMakePoint(NSMinX(frame) - 0.5, NSMaxY(frame))];
    }
    if( button.shouldDisplayRightDivider ) {
        [bezier moveToPoint:NSMakePoint(NSMaxX(frame) - 0.5, NSMinY(frame))];
        [bezier lineToPoint:NSMakePoint(NSMaxX(frame) - 0.5, NSMaxY(frame))];
    }
    [bezier stroke];
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *) [[maybe_unused]] overflowButton
                     ofTabBarView:(MMTabBarView *) [[maybe_unused]] tabBarView
                           inRect:(NSRect) [[maybe_unused]] rect
{
}

@end
