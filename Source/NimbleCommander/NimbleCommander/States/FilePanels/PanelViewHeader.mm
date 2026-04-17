// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewHeader.h"
#include "PanelViewHeaderPathBarBreadcrumbs.h"
#import "NCPanelPathBarView.h"
#import "NCPanelBreadcrumbsView.h"
#import "NCPanelPathSegment.h"
#include <Utility/Layout.h>
#include <Utility/ObjCpp.h>
#include <Utility/ColoredSeparatorLine.h>

using namespace nc::panel;

// Fixed strip height (do not change with theme font). Must match -[PanelView headerBarHeight] (20).
static constexpr CGFloat NCPanelViewHeaderPathBarFixedHeight = 20.;

static NSString *SortLetter(data::SortMode _mode) noexcept;
static void ChangeButtonAttrString(NSButton *_button, NSColor *_new_color, NSFont *_font);
static void ChangeAttributedTitle(NSButton *_button, NSString *_new_text);
static bool IsDark(NSColor *_color);

static NSArray<NCPanelPathSegment *> *PanelHeaderMakePathSegments(const std::vector<PanelHeaderBreadcrumb> &_crumbs)
{
    NSMutableArray<NCPanelPathSegment *> *const out = [NSMutableArray array];
    NSInteger last_nonempty = -1;
    for( NSInteger i = static_cast<NSInteger>(_crumbs.size()) - 1; i >= 0; --i ) {
        if( _crumbs[static_cast<size_t>(i)].label.length ) {
            last_nonempty = i;
            break;
        }
    }
    NSInteger crumb_idx = -1;
    for( const auto &crumb : _crumbs ) {
        ++crumb_idx;
        if( !crumb.label.length )
            continue;
        NCPanelPathSegment *const s = [NCPanelPathSegment new];
        s.title = crumb.label;
        if( crumb.navigate_to_vfs_path ) {
            NSString *const p = [NSString stringWithUTF8String:crumb.navigate_to_vfs_path->c_str()];
            s.navigatePOSIXPath = p;
        }
        s.isCurrentDirectory = (crumb_idx == last_nonempty);
        [out addObject:s];
    }
    return out;
}

static NSArray<NCPanelPathSegment *> *PanelHeaderMakePlainSegments(NSString *_path)
{
    NCPanelPathSegment *const s = [NCPanelPathSegment new];
    s.title = _path ?: @"";
    s.isCurrentDirectory = YES;
    return @[s];
}

@interface NCPanelViewHeader () <NCPanelBreadcrumbsViewDelegate>
@property(nonatomic) IBOutlet NSMenu *sortMenuPopup;
- (void)refreshPathBarContent;
- (void)pathBarApplyEditedPOSIXPath:(NSString *)path;
@end

@implementation NCPanelViewHeader {
    NSView *m_PathArea;
    NCPanelPathBarView *m_PathBar;
    NSTextField *m_SearchTextField;
    NSTextField *m_SearchMatchesField;
    NSButton *m_SearchMagGlassButton;
    NSButton *m_SearchClearButton;

    ColoredSeparatorLine *m_SeparatorLine;
    NSColor *m_Background;
    NSString *m_SearchPrompt;
    NSButton *m_SortButton;
    NSProgressIndicator *m_BusyIndicator;
    data::SortMode m_SortMode;
    std::function<void(data::SortMode)> m_SortModeChangeCallback;
    std::function<void(NSString *)> m_SearchRequestChangeCallback;
    std::unique_ptr<nc::panel::HeaderTheme> m_Theme;
    bool m_Active;

    bool m_PathBarInteractive;
    bool m_PathBarFullPathSelectionActive;
    std::vector<PanelHeaderBreadcrumb> m_LastBreadcrumbs;
    NSString *m_LastPlainPath;
    NSString *m_LastFullPathForEditing;
    NSString *m_LastPOSIXPathForActions;
    std::function<void(const std::string &)> m_PathNavigateCallback;
    id m_PathBarOutsideClickMonitor;
    NSLayoutConstraint *m_StripHeightConstraint;
    NSLayoutConstraint *m_PathAreaBottomConstraint;
}

@synthesize sortMode = m_SortMode;
@synthesize sortModeChangeCallback = m_SortModeChangeCallback;
@synthesize defaultResponder;
@synthesize sortMenuPopup;
@synthesize pathNavigateToVFSPathCallback = m_PathNavigateCallback;
@synthesize pathBarContextMenuAction;

- (void)dealloc
{
    [self removePathBarOutsideClickMonitorIfNeeded];
}

- (id)initWithFrame:(NSRect)frameRect theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Theme = std::move(_theme);
        m_SearchPrompt = nil;
        m_Active = false;
        m_PathBarInteractive = false;
        m_PathBarFullPathSelectionActive = false;
        m_StripHeightConstraint = nil;
        m_PathAreaBottomConstraint = nil;

        m_PathArea = [[NSView alloc] initWithFrame:NSRect()];
        m_PathArea.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_PathArea];

        m_PathBar = [[NCPanelPathBarView alloc] initWithFrame:NSRect()];
        m_PathBar.translatesAutoresizingMaskIntoConstraints = false;
        [m_PathArea addSubview:m_PathBar];

        [NSLayoutConstraint activateConstraints:@[
            [m_PathBar.leadingAnchor constraintEqualToAnchor:m_PathArea.leadingAnchor],
            [m_PathBar.trailingAnchor constraintEqualToAnchor:m_PathArea.trailingAnchor],
            [m_PathBar.topAnchor constraintEqualToAnchor:m_PathArea.topAnchor],
            [m_PathBar.bottomAnchor constraintEqualToAnchor:m_PathArea.bottomAnchor],
        ]];

        __weak NCPanelViewHeader *weak_path_header = self;
        m_PathBar.onCommitEditedPath = ^(NSString *path) {
            if( NCPanelViewHeader *const h = weak_path_header )
                [h pathBarApplyEditedPOSIXPath:path];
        };
        m_PathBar.onCancelFullPathEdit = ^{
            if( NCPanelViewHeader *const h = weak_path_header )
                [h cancelPathBarFullPathSelection];
        };

        m_SearchTextField = [[NSTextField alloc] initWithFrame:NSRect()];
        m_SearchTextField.stringValue = @"";
        m_SearchTextField.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchTextField.target = self;
        m_SearchTextField.action = @selector(onSearchFieldAction:);
        m_SearchTextField.bordered = false;
        m_SearchTextField.bezeled = false;
        m_SearchTextField.editable = true;
        m_SearchTextField.drawsBackground = false;
        m_SearchTextField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SearchTextField.maximumNumberOfLines = 1;
        m_SearchTextField.alignment = NSTextAlignmentCenter;
        m_SearchTextField.focusRingType = NSFocusRingTypeNone;
        m_SearchTextField.delegate = self;
        [self addSubview:m_SearchTextField];

        m_SearchMatchesField = [[NSTextField alloc] initWithFrame:NSRect()];
        m_SearchMatchesField.stringValue = @"";
        m_SearchMatchesField.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchMatchesField.bordered = false;
        m_SearchMatchesField.editable = false;
        m_SearchMatchesField.drawsBackground = false;
        m_SearchMatchesField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SearchMatchesField.maximumNumberOfLines = 1;
        m_SearchMatchesField.alignment = NSTextAlignmentRight;
        [self addSubview:m_SearchMatchesField];

        m_SearchClearButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SearchClearButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchClearButton.image = [NSImage imageWithSystemSymbolName:@"xmark.circle.fill"
                                              accessibilityDescription:nil];
        m_SearchClearButton.imageScaling = NSImageScaleProportionallyDown;
        m_SearchClearButton.refusesFirstResponder = true;
        m_SearchClearButton.bordered = false;
        m_SearchClearButton.target = self;
        m_SearchClearButton.action = @selector(onSearchFieldDiscardButton:);
        [self addSubview:m_SearchClearButton];

        m_SearchMagGlassButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SearchMagGlassButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchMagGlassButton.image = [NSImage imageWithSystemSymbolName:@"magnifyingglass"
                                                 accessibilityDescription:nil];
        m_SearchMagGlassButton.imageScaling = NSImageScaleProportionallyDown;
        m_SearchMagGlassButton.refusesFirstResponder = true;
        m_SearchMagGlassButton.bordered = false;
        m_SearchMagGlassButton.enabled = false;
        [self addSubview:m_SearchMagGlassButton];

        m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_SeparatorLine];

        m_SortButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SortButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SortButton.title = @"N";
        m_SortButton.bordered = false;
        m_SortButton.buttonType = NSButtonTypeMomentaryChange;
        [m_SortButton sendActionOn:NSEventMaskLeftMouseDown];
        m_SortButton.action = @selector(onSortButtonAction:);
        m_SortButton.target = self;
        m_SortButton.enabled = true;
        [self addSubview:m_SortButton];

        m_BusyIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
        m_BusyIndicator.translatesAutoresizingMaskIntoConstraints = false;
        m_BusyIndicator.indeterminate = true;
        m_BusyIndicator.style = NSProgressIndicatorStyleSpinning;
        m_BusyIndicator.controlSize = NSControlSizeSmall;
        m_BusyIndicator.displayedWhenStopped = false;
        if( IsDark(m_Theme->ActiveBackgroundColor()) )
            m_BusyIndicator.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        [self addSubview:m_BusyIndicator positioned:NSWindowAbove relativeTo:m_PathArea];

        [self setupAppearance];
        [self setupLayout];

        // Own strip height here so it does not depend on PanelView adding an external height constraint.
        m_StripHeightConstraint = [self.heightAnchor constraintEqualToConstant:NCPanelViewHeaderPathBarFixedHeight];
        m_StripHeightConstraint.priority = NSLayoutPriorityRequired;
        m_StripHeightConstraint.identifier = @"NCPanelViewHeader.StripHeight";
        m_StripHeightConstraint.active = YES;

        __weak NCPanelViewHeader *weak_self = self;
        m_Theme->ObserveChanges([weak_self] {
            if( auto strong_self = weak_self )
                [strong_self setupAppearance];
        });
    }
    return self;
}

- (BOOL)panelPathBarIsInteractive
{
    return m_PathBarInteractive;
}

- (BOOL)panelPathBarFullPathSelectionActive
{
    return m_PathBarFullPathSelectionActive;
}

- (BOOL)pathBarConsumeCancelIfFullPathSelectionActive
{
    if( !m_PathBarFullPathSelectionActive )
        return NO;
    [self cancelPathBarFullPathSelection];
    return YES;
}

- (void)removePathBarOutsideClickMonitorIfNeeded
{
    if( m_PathBarOutsideClickMonitor != nil ) {
        [NSEvent removeMonitor:m_PathBarOutsideClickMonitor];
        m_PathBarOutsideClickMonitor = nil;
    }
}

- (void)handleOutsideMouseDownWhilePathBarFullPathSelection:(NSEvent *)event
{
    if( !m_PathBarFullPathSelectionActive )
        return;
    NSWindow *const event_window = event.window;
    if( !event_window )
        return;
    if( event_window != self.window ) {
        [self cancelPathBarFullPathSelection];
        return;
    }
    const NSPoint p = event.locationInWindow;
    const NSRect bar_in_window = [m_PathBar convertRect:m_PathBar.bounds toView:nil];
    if( NSPointInRect(p, bar_in_window) )
        return;
    [self cancelPathBarFullPathSelection];
}

- (void)beginPathBarFullPathSelection
{
    if( !m_PathBarInteractive )
        return;
    if( self.searchPrompt != nil )
        return;

    [self removePathBarOutsideClickMonitorIfNeeded];

    m_PathBar.breadcrumbsView.hoveredSegmentIndex = -1;

    NSString *const full = m_LastFullPathForEditing ?: @"";
    NSFont *const font = m_Theme->Font();
    NSColor *const text_color = m_Active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
    m_PathBarFullPathSelectionActive = true;
    [m_PathBar enterFullPathEditWithString:full font:font textColor:text_color];

    __weak NCPanelViewHeader *weak_header = self;
    m_PathBarOutsideClickMonitor =
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                              handler:^NSEvent *(NSEvent *event) {
                                                NCPanelViewHeader *const h = weak_header;
                                                if( !h || !h->m_PathBarFullPathSelectionActive )
                                                    return event;
                                                [h handleOutsideMouseDownWhilePathBarFullPathSelection:event];
                                                return event;
                                              }];
}

- (void)setupAppearance
{
    NSFont *const font = m_Theme->Font();
    m_PathBar.pathEditField.font = font;
    m_SearchTextField.font = font;
    m_SearchMatchesField.font = font;

    m_SeparatorLine.borderColor = m_Theme->SeparatorColor();
    if( m_PathAreaBottomConstraint != nil )
        m_PathAreaBottomConstraint.constant = -static_cast<CGFloat>(m_Theme->PathAreaBottomInset());

    const bool active = m_Active;
    m_Background = active ? m_Theme->ActiveBackgroundColor() : m_Theme->InactiveBackgroundColor();

    NSColor *text_color = active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
    m_SearchTextField.textColor = text_color;
    m_SearchMatchesField.textColor = text_color;

    ChangeButtonAttrString(m_SortButton, text_color, font);
    m_SearchClearButton.contentTintColor = text_color;
    m_SearchMagGlassButton.contentTintColor = text_color;
    self.needsDisplay = true;

    if( m_PathBarFullPathSelectionActive ) {
        m_PathBar.pathEditField.font = font;
        m_PathBar.pathEditField.textColor = text_color;
        [m_PathBar syncPathEditFieldVerticalAlignmentWithFont:font];
    }
    else {
        [self refreshPathBarContent];
    }
}

- (void)refreshPathBarContent
{
    if( m_PathBarFullPathSelectionActive )
        return;
    m_PathBar.breadcrumbsView.hoveredSegmentIndex = -1;
    NSFont *const font = m_Theme->Font();
    NSColor *const text_color = m_Active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
    NSColor *const accent = m_Theme->PathAccentColor();
    NSColor *const sep = m_Theme->PathSeparatorColor();
    NCPanelBreadcrumbsView *const bv = m_PathBar.breadcrumbsView;
    bv.crumbFont = font;
    bv.textColor = text_color;
    bv.linkColor = text_color;
    bv.separatorColor = sep;
    bv.hoverFillColor = accent;
    bv.hoverPadX = m_Theme->PathHoverPadX();
    bv.hoverPadYTop = m_Theme->PathHoverPadYTop();
    bv.hoverPadYBottom = m_Theme->PathHoverPadYBottom();
    bv.hoverCornerRadius = m_Theme->PathHoverCornerRadius();

    __weak NCPanelViewHeader *weak_self = self;
    __weak NCPanelBreadcrumbsView *weak_bv = bv;
    bv.menuForEventBlock = ^NSMenu *(NSEvent *event) {
        NCPanelBreadcrumbsView *const b = weak_bv;
        NCPanelViewHeader *const h = weak_self;
        if( !b || !h || !h.pathBarContextMenuAction )
            return nil;
        const NSPoint p = [b convertPoint:event.locationInWindow fromView:nil];
        NSString *const path = [h posixPathForPathBarContextMenuAtPoint:p];
        if( path.length == 0 )
            return nil;
        return [h pathBarContextMenuForPOSIXPath:path];
    };

    if( m_PathBarInteractive && !m_LastBreadcrumbs.empty() ) {
        bv.segments = PanelHeaderMakePathSegments(m_LastBreadcrumbs);
        bv.crumbDelegate = self;
    }
    else {
        bv.segments = PanelHeaderMakePlainSegments(m_LastPlainPath ?: @"");
        bv.crumbDelegate = nil;
    }
    [m_PathBar exitFullPathEdit];
}

- (void)pathBarApplyEditedPOSIXPath:(NSString *)path
{
    const char *const raw = path.UTF8String;
    std::string utf8 = raw ? std::string(raw) : std::string();
    utf8 = NormalizePanelHeaderPOSIXPathForActions(utf8);
    if( m_PathNavigateCallback )
        m_PathNavigateCallback(utf8);
    [self cancelPathBarFullPathSelection];
}

- (void)setupLayout
{
    NSDictionary *views = NSDictionaryOfVariableBindings(m_PathArea,
                                                         m_SearchTextField,
                                                         m_SeparatorLine,
                                                         m_SearchMatchesField,
                                                         m_SearchClearButton,
                                                         m_SearchMagGlassButton,
                                                         m_SortButton,
                                                         m_BusyIndicator);
    [self addConstraints:[NSLayoutConstraint
                             constraintsWithVisualFormat:@"|-(==0)-[m_SortButton(==20)]-(==0)-[m_PathArea]-(==2)-|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_BusyIndicator]-(==2)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_SeparatorLine]-(0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint
                             constraintsWithVisualFormat:@"|-(4)-[m_SearchMagGlassButton(==15)]-[m_SearchTextField]-[m_"
                                                         @"SearchMatchesField]-[m_SearchClearButton(==15)]-(4)-|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];

    [m_SearchTextField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];

    [m_SearchMatchesField setContentHuggingPriority:NSLayoutPriorityRequired
                                     forOrientation:NSLayoutConstraintOrientationHorizontal];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_SeparatorLine(==1)]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_BusyIndicator]-(==2)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];

    m_PathAreaBottomConstraint = [m_PathArea.bottomAnchor constraintEqualToAnchor:m_SeparatorLine.topAnchor
                                                                          constant:-static_cast<CGFloat>(
                                                                                       m_Theme->PathAreaBottomInset())];
    [NSLayoutConstraint activateConstraints:@[
        [m_PathArea.topAnchor constraintEqualToAnchor:self.topAnchor],
        m_PathAreaBottomConstraint,
    ]];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchTextField, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchMagGlassButton, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchMatchesField, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchClearButton, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SortButton, self)];
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)canDrawSubviewsIntoLayer
{
    return true;
}

- (void)drawRect:(NSRect) [[maybe_unused]] dirtyRect
{
    if( m_Background && m_Background != NSColor.clearColor ) {
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(self.bounds));
    }
    else {
        NSDrawWindowBackground(self.bounds);
    }
}

- (void)setPath:(NSString *)_path
{
    [self setPlainHeaderPath:_path];
}

- (void)setPlainHeaderPath:(NSString *)_path
{
    [self endPathBarFullPathSelectionUI];
    m_PathBarInteractive = false;
    m_LastBreadcrumbs.clear();
    m_LastFullPathForEditing = nil;
    m_LastPOSIXPathForActions = nil;
    m_LastPlainPath = [_path copy] ?: @"";
    [self refreshPathBarContent];
}

- (void)setInteractiveBreadcrumbs:(const std::vector<PanelHeaderBreadcrumb> &)_breadcrumbs
               fullPathForEditing:(NSString *)_full_path_for_editing
              posixPathForActions:(NSString *)_posix_path_for_actions
{
    [self endPathBarFullPathSelectionUI];
    m_PathBarInteractive = !_breadcrumbs.empty();
    m_LastBreadcrumbs = _breadcrumbs;
    m_LastFullPathForEditing = [_full_path_for_editing copy];
    m_LastPOSIXPathForActions = [_posix_path_for_actions copy];
    m_LastPlainPath = nil;
    [self refreshPathBarContent];
}

- (void)endPathBarFullPathSelectionUI
{
    [self removePathBarOutsideClickMonitorIfNeeded];
    m_PathBarFullPathSelectionActive = false;
    [m_PathBar exitFullPathEdit];
    [self refreshPathBarContent];
}

- (void)cancelPathBarFullPathSelection
{
    [self endPathBarFullPathSelectionUI];
    if( self.window && self.defaultResponder )
        [self.window makeFirstResponder:self.defaultResponder];
}

- (void)breadcrumbsView:(NCPanelBreadcrumbsView *) [[maybe_unused]] v didActivatePOSIXPath:(NSString *)path
{
    if( path.length == 0 )
        return;
    const char *const raw = path.UTF8String;
    if( !raw )
        return;
    const std::string utf8{raw};
    if( m_PathNavigateCallback )
        m_PathNavigateCallback(utf8);
}

- (void)breadcrumbsViewDidActivateCurrentSegment:(NCPanelBreadcrumbsView *) [[maybe_unused]] v
{
    [self beginPathBarFullPathSelection];
}

- (void)breadcrumbsViewDidRequestFullPathEdit:(NCPanelBreadcrumbsView *) [[maybe_unused]] v
{
    [self beginPathBarFullPathSelection];
}

- (nullable NSString *)posixPathForPathBarContextMenuAtPoint:(NSPoint)pInBreadcrumbsCoords
{
    if( m_PathBarFullPathSelectionActive )
        return nil;
    NCPanelBreadcrumbsView *const bv = m_PathBar.breadcrumbsView;
    if( bv.segments.count == 0 )
        return nil;
    if( !m_PathBarInteractive ) {
        NSString *const s = m_LastPlainPath ?: @"";
        return s.length ? s : nil;
    }
    return [bv posixPathAtViewPoint:pInBreadcrumbsCoords fallbackPOSIXPath:m_LastPOSIXPathForActions plainPath:m_LastPlainPath];
}

- (NSMenu *)pathBarContextMenuForPOSIXPath:(NSString *)path
{
    NSMenu *const menu = [[NSMenu alloc] initWithTitle:@""];
    auto add = ^(NSString *title, NCPanelPathBarContextCommand cmd) {
      NSMenuItem *const it = [[NSMenuItem alloc] initWithTitle:title
                                                        action:@selector(handlePathBarContextMenuItem:)
                                                 keyEquivalent:@""];
      it.target = self;
      it.tag = cmd;
      it.representedObject = path;
      [menu addItem:it];
    };
    add(NSLocalizedString(@"Open", @"Path bar context: open directory in panel"), NCPanelPathBarContextCommandOpen);
    add(NSLocalizedString(@"Open in New Tab", @"Path bar context: open directory in a new tab"),
        NCPanelPathBarContextCommandOpenInNewTab);
    [menu addItem:[NSMenuItem separatorItem]];
    add(NSLocalizedString(@"Copy Path", @"Path bar context: copy POSIX path"), NCPanelPathBarContextCommandCopyPath);
    return menu;
}

- (void)handlePathBarContextMenuItem:(NSMenuItem *)item
{
    NSString *const path = nc::objc_cast<NSString>(item.representedObject);
    if( path.length == 0 || !self.pathBarContextMenuAction )
        return;
    self.pathBarContextMenuAction(path, static_cast<NCPanelPathBarContextCommand>(item.tag));
}

- (void)setupBindings
{
    static const auto isnil = @{NSValueTransformerNameBindingOption: NSIsNilTransformerName};
    static const auto isnotnil = @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName};
    [m_SearchMagGlassButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchMatchesField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchClearButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_PathArea bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
    [m_SortButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
    [m_BusyIndicator bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
}

- (void)removeBindings
{
    [m_SearchMagGlassButton unbind:@"hidden"];
    [m_SearchTextField unbind:@"hidden"];
    [m_SearchMatchesField unbind:@"hidden"];
    [m_SearchClearButton unbind:@"hidden"];
    [m_PathArea unbind:@"hidden"];
    [m_SortButton unbind:@"hidden"];
    [m_BusyIndicator unbind:@"hidden"];
}

- (void)viewDidMoveToSuperview
{
    if( self.superview )
        [self setupBindings];
    else {
        [self removePathBarOutsideClickMonitorIfNeeded];
        [self removeBindings];
    }
}

- (void)setSearchRequestChangeCallback:(std::function<void(NSString *)>)searchRequestChangeCallback
{
    m_SearchRequestChangeCallback = std::move(searchRequestChangeCallback);
}

- (std::function<void(NSString *)>)searchRequestChangeCallback
{
    return m_SearchRequestChangeCallback;
}

- (NSString *)searchPrompt
{
    return m_SearchPrompt;
}

- (void)setSearchPrompt:(NSString *)searchPrompt
{
    if( (m_SearchPrompt == searchPrompt) || (!m_SearchPrompt && !searchPrompt.length) )
        return;

    [self willChangeValueForKey:@"searchPrompt"];
    m_SearchPrompt = searchPrompt.length ? searchPrompt : nil;
    [self didChangeValueForKey:@"searchPrompt"];

    m_SearchTextField.stringValue = m_SearchPrompt ? m_SearchPrompt : @"";
    [m_SearchTextField invalidateIntrinsicContentSize];
    [self layout];
}

- (int)searchMatches
{
    return m_SearchMatchesField.intValue;
}

- (void)setSearchMatches:(int)searchMatches
{
    m_SearchMatchesField.intValue = searchMatches;
}

- (void)onSearchFieldDiscardButton:(id) [[maybe_unused]] _sender
{
    self.searchPrompt = nil;
    [self.window makeFirstResponder:self.defaultResponder];
    if( m_SearchRequestChangeCallback )
        m_SearchRequestChangeCallback(nil);
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    if( obj.object == m_SearchTextField ) {
        NSString *v = m_SearchTextField.stringValue;
        if( v.length > 0 ) {
            if( m_SearchRequestChangeCallback )
                m_SearchRequestChangeCallback(v);
        }
        else
            [self onSearchFieldDiscardButton:m_SearchTextField];
    }
}

- (void)onSearchFieldAction:(id) [[maybe_unused]] _sender
{
}

- (void)onSortButtonAction:(id) [[maybe_unused]] _sender
{
    if( !self.sortMenuPopup ) {
        NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PanelViewHeaderSortPopup" bundle:nil];
        [nib instantiateWithOwner:self topLevelObjects:nil];
    }

    for( NSMenuItem *i in self.sortMenuPopup.itemArray ) {
        if( i.action == @selector(onSortPopupMenuSortByClicked:) )
            i.state = i.tag == m_SortMode.sort ? NSControlStateValueOn : NSControlStateValueOff;
        else if( i.action == @selector(onSortPopupMenuOptionsClicked:) )
            switch( i.tag ) {
                case 1:
                    i.state = m_SortMode.sep_dirs ? NSControlStateValueOn : NSControlStateValueOff;
                    break;
                case 2:
                    i.state = m_SortMode.extensionless_dirs ? NSControlStateValueOn : NSControlStateValueOff;
                    break;
                case 3:
                    i.state = m_SortMode.collation == data::SortMode::Collation::Natural ? NSControlStateValueOn
                                                                                         : NSControlStateValueOff;
                    break;
                case 4:
                    i.state = m_SortMode.collation == data::SortMode::Collation::CaseInsensitive
                                  ? NSControlStateValueOn
                                  : NSControlStateValueOff;
                    break;
                case 5:
                    i.state = m_SortMode.collation == data::SortMode::Collation::CaseSensitive ? NSControlStateValueOn
                                                                                               : NSControlStateValueOff;
                    break;
                default:
                    /* do nothing */;
            }
    }

    [self.sortMenuPopup popUpMenuPositioningItem:nil
                                      atLocation:NSMakePoint(m_SortButton.bounds.size.width, 0)
                                          inView:m_SortButton];
}

- (void)setSortMode:(data::SortMode)_mode
{
    if( m_SortMode == _mode )
        return;

    m_SortMode = _mode;
    ChangeAttributedTitle(m_SortButton, SortLetter(_mode));
}

- (IBAction)onSortPopupMenuSortByClicked:(id)sender
{
    if( auto item = nc::objc_cast<NSMenuItem>(sender) ) {
        const auto new_sort_mode = static_cast<data::SortMode::Mode>(item.tag);
        if( !data::SortMode::validate(new_sort_mode) )
            return;

        auto proposed = m_SortMode;
        proposed.sort = new_sort_mode;

        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (IBAction)onSortPopupMenuOptionsClicked:(id)sender
{
    if( auto item = nc::objc_cast<NSMenuItem>(sender) ) {
        auto proposed = m_SortMode;
        switch( item.tag ) {
            case 1:
                proposed.sep_dirs = !proposed.sep_dirs;
                break;
            case 2:
                proposed.extensionless_dirs = !proposed.extensionless_dirs;
                break;
            case 3:
                proposed.collation = data::SortMode::Collation::Natural;
                break;
            case 4:
                proposed.collation = data::SortMode::Collation::CaseInsensitive;
                break;
            case 5:
                proposed.collation = data::SortMode::Collation::CaseSensitive;
                break;
            default:
                /* do nothing */;
        }

        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (NSProgressIndicator *)busyIndicator
{
    return m_BusyIndicator;
}

- (void)setActive:(bool)active
{
    if( active == m_Active )
        return;
    m_Active = active;

    [self setupAppearance];
}

- (bool)active
{
    return m_Active;
}

- (void)cancelOperation:(id)_sender
{
    if( m_SearchPrompt != nil ) {
        [self onSearchFieldDiscardButton:m_SearchTextField];
        return;
    }

    if( m_PathBarFullPathSelectionActive ) {
        [self cancelPathBarFullPathSelection];
        return;
    }

    [super cancelOperation:_sender];
}

@end

static void ChangeButtonAttrString(NSButton *_button, NSColor *_new_color, NSFont *_font)
{
    NSMutableAttributedString *const sort_title =
        [[NSMutableAttributedString alloc] initWithAttributedString:_button.attributedTitle];
    const unsigned long length = sort_title.length;
    [sort_title addAttribute:NSForegroundColorAttributeName value:_new_color range:NSMakeRange(0, length)];
    [sort_title addAttribute:NSFontAttributeName value:_font range:NSMakeRange(0, length)];
    _button.attributedTitle = sort_title;
}

static void ChangeAttributedTitle(NSButton *_button, NSString *_new_text)
{
    const auto title = [[NSMutableAttributedString alloc] initWithAttributedString:_button.attributedTitle];
    [title replaceCharactersInRange:NSMakeRange(0, title.length) withString:_new_text];
    _button.attributedTitle = title;
}

static NSString *SortLetter(data::SortMode _mode) noexcept
{
    switch( _mode.sort ) {
        case data::SortMode::SortByName:
            return @"n";
        case data::SortMode::SortByNameRev:
            return @"N";
        case data::SortMode::SortByExt:
            return @"e";
        case data::SortMode::SortByExtRev:
            return @"E";
        case data::SortMode::SortBySize:
            return @"s";
        case data::SortMode::SortBySizeRev:
            return @"S";
        case data::SortMode::SortByModTime:
            return @"m";
        case data::SortMode::SortByModTimeRev:
            return @"M";
        case data::SortMode::SortByBirthTime:
            return @"b";
        case data::SortMode::SortByBirthTimeRev:
            return @"B";
        case data::SortMode::SortByAddTime:
            return @"a";
        case data::SortMode::SortByAddTimeRev:
            return @"A";
        case data::SortMode::SortByAccessTime:
            return @"x";
        case data::SortMode::SortByAccessTimeRev:
            return @"X";
        default:
            return @"?";
    }
}

static bool IsDark(NSColor *_color)
{
    const auto c = [_color colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    return c.brightnessComponent < 0.60;
}
