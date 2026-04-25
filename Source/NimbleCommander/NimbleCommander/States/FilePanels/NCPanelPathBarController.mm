#import "NCPanelPathBarController.h"

#import "NCPanelPathBarView.h"
#include "NCPanelPathBarPresentation.h"
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>

using namespace nc::panel;

static std::vector<PanelHeaderBreadcrumb> NCPlainPathBreadcrumbs(NSString *path)
{
    PanelHeaderBreadcrumb breadcrumb;
    breadcrumb.label = path ?: @"";
    breadcrumb.is_current_directory = true;
    return {breadcrumb};
}

static NSString *NCPathDisplayStringForSelection(NSString *display_path)
{
    if( display_path.length <= 1 )
        return display_path ?: @"";
    if( [display_path hasSuffix:@"/"] )
        return [display_path substringToIndex:display_path.length - 1];
    return display_path;
}

@interface NCPanelPathBarController ()
- (void)setPlainDisplayPath:(NSString *)displayPath;
- (void)setDisplayPath:(NSString *)displayPath directoryContext:(const PanelPathContext &)directoryContext;
- (void)refreshPathBarContent;
- (void)beginFullPathSelection;
- (void)endFullPathSelectionUI;
- (void)removeOutsideClickMonitorIfNeeded;
- (void)handleOutsideMouseDownWhileFullPathSelection:(NSEvent *)event;
- (nullable NSString *)posixPathForContextMenuAtPoint:(NSPoint)pointInBreadcrumbsCoords;
- (NSMenu *)contextMenuForPOSIXPath:(NSString *)path;
- (void)handleContextMenuItem:(NSMenuItem *)item;
- (void)activateOwningPanelIfNeeded;
@end

@implementation NCPanelPathBarController {
    NCPanelPathBarView *m_View;
    std::vector<PanelHeaderBreadcrumb> m_Breadcrumbs;
    NSString *m_PlainPath;
    NSString *m_FullPathForSelection;
    NSString *m_POSIXPathForActions;
    id m_OutsideClickMonitor;
    NSFont *m_Font;
    NSColor *m_TextColor;
    NSColor *m_SeparatorColor;
    NSColor *m_HoverFillColor;
    double m_HoverPadX;
    double m_HoverPadY;
    unsigned m_HoverCornerRadius;
    double m_SeparatorVerticalNudgeCoefficient;
}

@synthesize defaultResponder;
@synthesize directoryContextProvider = _directoryContextProvider;
@synthesize navigateToVFSPathCallback = _navigateToVFSPathCallback;
@synthesize contextMenuAction = _contextMenuAction;
@synthesize fullPathSelectionActive = _fullPathSelectionActive;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_View = [[NCPanelPathBarView alloc] initWithFrame:NSZeroRect];
        _fullPathSelectionActive = false;
        m_HoverPadX = 0;
        m_HoverPadY = 0;
        m_HoverCornerRadius = 0;
        m_SeparatorVerticalNudgeCoefficient = 0.;

        __weak NCPanelPathBarController *weak_self = self;
        m_View.onCancelFullPathSelection = ^{
            if( NCPanelPathBarController *const controller = weak_self )
                [controller cancelFullPathSelectionIfActive];
        };

        __weak NCPanelBreadcrumbsView *weak_breadcrumbs = m_View.breadcrumbsView;
        m_View.breadcrumbsView.menuForEventBlock = ^NSMenu *(NSEvent *event) {
            NCPanelPathBarController *const controller = weak_self;
            NCPanelBreadcrumbsView *const breadcrumbs = weak_breadcrumbs;
            if( controller == nil || breadcrumbs == nil || !controller.contextMenuAction )
                return nil;
            const NSPoint point = [breadcrumbs convertPoint:event.locationInWindow fromView:nil];
            NSString *const path = [controller posixPathForContextMenuAtPoint:point];
            if( path.length == 0 )
                return nil;
            return [controller contextMenuForPOSIXPath:path];
        };
    }
    return self;
}

- (NSView *)view
{
    return m_View;
}

- (void)dealloc
{
    [self removeOutsideClickMonitorIfNeeded];
}

- (void)applyTheme:(const HeaderTheme &)theme active:(bool)active
{
    m_Font = theme.Font();
    m_TextColor = active ? theme.ActiveTextColor() : theme.TextColor();
    m_SeparatorColor = theme.PathSeparatorColor();
    m_HoverFillColor = theme.PathAccentColor();
    m_HoverPadX = theme.PathHoverPadX();
    m_HoverPadY = theme.PathHoverPadY();
    m_HoverCornerRadius = theme.PathHoverCornerRadius();
    m_SeparatorVerticalNudgeCoefficient = theme.PathSeparatorVerticalNudgeCoefficient();

    m_View.pathTextView.font = m_Font;
    if( self.fullPathSelectionActive ) {
        m_View.pathTextView.textColor = m_TextColor;
        [m_View syncPathTextViewVerticalAlignmentWithFont:m_Font];
    }
    else {
        [self refreshPathBarContent];
    }
}

- (void)setDisplayPath:(NSString *)displayPath
{
    if( self.directoryContextProvider ) {
        const auto directory_context = self.directoryContextProvider();
        if( directory_context.has_value() ) {
            [self setDisplayPath:displayPath directoryContext:*directory_context];
            return;
        }
    }
    [self setPlainDisplayPath:displayPath];
}

- (void)setPlainDisplayPath:(NSString *)displayPath
{
    [self endFullPathSelectionUI];
    m_Breadcrumbs.clear();
    m_FullPathForSelection = nil;
    m_POSIXPathForActions = nil;
    m_PlainPath = [displayPath copy] ?: @"";
    [self refreshPathBarContent];
}

- (void)setDisplayPath:(NSString *)displayPath directoryContext:(const PanelPathContext &)directoryContext
{
    [self endFullPathSelectionUI];
    const auto breadcrumbs = BuildPanelHeaderBreadcrumbs(directoryContext);
    if( breadcrumbs.empty() ) {
        [self setPlainDisplayPath:displayPath];
        return;
    }

    m_Breadcrumbs = breadcrumbs;
    m_FullPathForSelection = [NCPathDisplayStringForSelection(displayPath) copy];
    const auto posix_path = NormalizePanelHeaderPOSIXPathForActions(directoryContext.posix_path);
    m_POSIXPathForActions = [NSString stringWithUTF8StdString:posix_path];
    m_PlainPath = nil;
    [self refreshPathBarContent];
}

- (bool)cancelFullPathSelectionIfActive
{
    if( !self.fullPathSelectionActive )
        return false;
    [self endFullPathSelectionUI];
    if( m_View.window != nil && self.defaultResponder != nil )
        [m_View.window makeFirstResponder:self.defaultResponder];
    return true;
}

- (void)invalidate
{
    [self removeOutsideClickMonitorIfNeeded];
}

- (void)refreshPathBarContent
{
    if( self.fullPathSelectionActive )
        return;

    NCPanelBreadcrumbsView *const breadcrumbs_view = m_View.breadcrumbsView;
    breadcrumbs_view.hoveredSegmentIndex = -1;
    breadcrumbs_view.crumbFont = m_Font ?: [NSFont systemFontOfSize:13.];
    breadcrumbs_view.textColor = m_TextColor ?: NSColor.textColor;
    breadcrumbs_view.linkColor = breadcrumbs_view.textColor;
    breadcrumbs_view.separatorColor = m_SeparatorColor ?: NSColor.secondaryLabelColor;
    breadcrumbs_view.hoverFillColor = m_HoverFillColor;
    breadcrumbs_view.hoverPadX = m_HoverPadX;
    breadcrumbs_view.hoverPadY = m_HoverPadY;
    breadcrumbs_view.hoverCornerRadius = m_HoverCornerRadius;
    breadcrumbs_view.separatorVerticalNudgeCoefficient = m_SeparatorVerticalNudgeCoefficient;

    if( !m_Breadcrumbs.empty() ) {
        [breadcrumbs_view setBreadcrumbs:m_Breadcrumbs];
        breadcrumbs_view.crumbDelegate = self;
    }
    else {
        [breadcrumbs_view setBreadcrumbs:NCPlainPathBreadcrumbs(m_PlainPath ?: @"")];
        breadcrumbs_view.crumbDelegate = nil;
    }
    [m_View exitFullPathSelection];
}

- (void)removeOutsideClickMonitorIfNeeded
{
    if( m_OutsideClickMonitor != nil ) {
        [NSEvent removeMonitor:m_OutsideClickMonitor];
        m_OutsideClickMonitor = nil;
    }
}

- (void)handleOutsideMouseDownWhileFullPathSelection:(NSEvent *)event
{
    if( !self.fullPathSelectionActive )
        return;

    NSWindow *const event_window = event.window;
    if( event_window == nil )
        return;
    if( event_window != m_View.window ) {
        [self cancelFullPathSelectionIfActive];
        return;
    }

    const NSPoint point = event.locationInWindow;
    const NSRect bar_in_window = [m_View convertRect:m_View.bounds toView:nil];
    if( NSPointInRect(point, bar_in_window) )
        return;

    [self cancelFullPathSelectionIfActive];
}

- (void)beginFullPathSelection
{
    if( m_Breadcrumbs.empty() )
        return;

    [self removeOutsideClickMonitorIfNeeded];

    m_View.breadcrumbsView.hoveredSegmentIndex = -1;
    _fullPathSelectionActive = true;
    [m_View enterFullPathSelectionWithString:(m_FullPathForSelection ?: @"")
                                        font:(m_Font ?: [NSFont systemFontOfSize:13.])
                                   textColor:(m_TextColor ?: NSColor.textColor)];

    __weak NCPanelPathBarController *weak_self = self;
    m_OutsideClickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                                                  handler:^NSEvent *(NSEvent *event) {
                                                                      NCPanelPathBarController *const controller = weak_self;
                                                                      if( controller != nil && controller.fullPathSelectionActive )
                                                                          [controller handleOutsideMouseDownWhileFullPathSelection:event];
                                                                      return event;
                                                                  }];
}

- (void)endFullPathSelectionUI
{
    [self removeOutsideClickMonitorIfNeeded];
    _fullPathSelectionActive = false;
    [m_View exitFullPathSelection];
    [self refreshPathBarContent];
}

- (nullable NSString *)posixPathForContextMenuAtPoint:(NSPoint)pointInBreadcrumbsCoords
{
    if( self.fullPathSelectionActive )
        return nil;

    NCPanelBreadcrumbsView *const breadcrumbs_view = m_View.breadcrumbsView;
    if( m_Breadcrumbs.empty() )
        return nil; // no real path to act on in plain/non-interactive mode
    return [breadcrumbs_view posixPathAtViewPoint:pointInBreadcrumbsCoords
                                fallbackPOSIXPath:m_POSIXPathForActions
                                        plainPath:m_PlainPath];
}

- (NSMenu *)contextMenuForPOSIXPath:(NSString *)path
{
    NSMenu *const menu = [[NSMenu alloc] initWithTitle:@""];
    auto add = ^(NSString *title, nc::panel::NCPanelPathBarContextCommand command) {
        NSMenuItem *const item = [[NSMenuItem alloc] initWithTitle:title
                                                            action:@selector(handleContextMenuItem:)
                                                     keyEquivalent:@""];
        item.target = self;
        item.tag = static_cast<NSInteger>(command);
        item.representedObject = path;
        [menu addItem:item];
    };
    add(NSLocalizedString(@"Open", @"Path bar context: open directory in panel"), nc::panel::NCPanelPathBarContextCommand::Open);
    add(NSLocalizedString(@"Open in New Tab", @"Path bar context: open directory in a new tab"),
        nc::panel::NCPanelPathBarContextCommand::OpenInNewTab);
    [menu addItem:[NSMenuItem separatorItem]];
    add(NSLocalizedString(@"Copy Path", @"Path bar context: copy POSIX path"), nc::panel::NCPanelPathBarContextCommand::CopyPath);
    return menu;
}

- (void)handleContextMenuItem:(NSMenuItem *)item
{
    NSString *const path = nc::objc_cast<NSString>(item.representedObject);
    if( path.length == 0 || !self.contextMenuAction )
        return;
    self.contextMenuAction(path, static_cast<nc::panel::NCPanelPathBarContextCommand>(item.tag));
}

- (void)activateOwningPanelIfNeeded
{
    if( m_View.window != nil && self.defaultResponder != nil )
        [m_View.window makeFirstResponder:self.defaultResponder];
}

- (void)breadcrumbsViewWillHandleMouseDown:(NCPanelBreadcrumbsView *)[[maybe_unused]]view
{
    [self activateOwningPanelIfNeeded];
}

- (void)breadcrumbsView:(NCPanelBreadcrumbsView *)[[maybe_unused]]view didActivatePOSIXPath:(NSString *)path
{
    if( path.length == 0 )
        return;
    const char *const raw = path.UTF8String;
    if( raw == nullptr )
        return;
    if( self.navigateToVFSPathCallback )
        self.navigateToVFSPathCallback(std::string{raw});
}

- (void)breadcrumbsViewDidActivateCurrentSegment:(NCPanelBreadcrumbsView *)[[maybe_unused]]view
{
    [self beginFullPathSelection];
}

- (void)breadcrumbsViewDidRequestFullPathSelection:(NCPanelBreadcrumbsView *)[[maybe_unused]]view
{
    [self beginFullPathSelection];
}

@end
