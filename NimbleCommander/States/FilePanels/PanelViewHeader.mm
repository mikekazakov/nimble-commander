#include <Utility/Layout.h>
#include <Utility/ColoredSeparatorLine.h>
#include <Utility/VerticallyCenteredTextFieldCell.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "PanelView.h"
#include "PanelController.h"
#include "PanelViewHeader.h"

static NSString *SortLetter(PanelDataSortMode _mode)
{
    switch( _mode.sort ) {
        case PanelDataSortMode::SortByName:         return @"n";
        case PanelDataSortMode::SortByNameRev:      return @"N";
        case PanelDataSortMode::SortByExt:          return @"e";
        case PanelDataSortMode::SortByExtRev:       return @"E";
        case PanelDataSortMode::SortBySize:         return @"s";
        case PanelDataSortMode::SortBySizeRev:      return @"S";
        case PanelDataSortMode::SortByModTime:      return @"m";
        case PanelDataSortMode::SortByModTimeRev:   return @"M";
        case PanelDataSortMode::SortByBirthTime:    return @"b";
        case PanelDataSortMode::SortByBirthTimeRev: return @"B";
        case PanelDataSortMode::SortByAddTime:      return @"a";
        case PanelDataSortMode::SortByAddTimeRev:   return @"A";
        default:                                    return @"?";
    }
}

@interface PanelViewHeader()
@property (strong) IBOutlet NSMenu *sortMenuPopup;
@end

@implementation PanelViewHeader
{
    NSTextField         *m_PathTextField;
    NSSearchField       *m_SearchTextField;
    NSTextField         *m_SearchMatchesField;
    ColoredSeparatorLine*m_SeparatorLine;
    NSColor             *m_Background;
    NSString            *m_SearchPrompt;
    NSButton            *m_SortButton;
    NSProgressIndicator *m_BusyIndicator;
    __weak PanelView    *m_PanelView;
    PanelDataSortMode    m_SortMode;
    function<void(PanelDataSortMode)> m_SortModeChangeCallback;
    ThemesManager::ObservationTicket    m_ThemeObservation;    
}

@synthesize sortMode = m_SortMode;
@synthesize sortModeChangeCallback = m_SortModeChangeCallback;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_SearchPrompt = nil;
        
        m_PathTextField= [[NSTextField alloc] initWithFrame:NSRect()];
        m_PathTextField.translatesAutoresizingMaskIntoConstraints = false;
        m_PathTextField.cell = [VerticallyCenteredTextFieldCell new];
        m_PathTextField.stringValue = @"";
        m_PathTextField.bordered = false;
        m_PathTextField.editable = false;
        m_PathTextField.drawsBackground = false;
        m_PathTextField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_PathTextField.usesSingleLineMode = true;
        m_PathTextField.alignment = NSTextAlignmentCenter;
        [self addSubview:m_PathTextField];
        
        m_SearchTextField= [[NSSearchField alloc] initWithFrame:NSRect()];
        m_SearchTextField.stringValue = @"";
        m_SearchTextField.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchTextField.sendsWholeSearchString = false;
        m_SearchTextField.target = self;
        m_SearchTextField.action = @selector(onSearchFieldAction:);
        m_SearchTextField.bordered = false;
        m_SearchTextField.bezeled = true;
        m_SearchTextField.editable = true;
        m_SearchTextField.drawsBackground = false;
        m_SearchTextField.focusRingType = NSFocusRingTypeNone;
        m_SearchTextField.alignment = NSTextAlignmentCenter;
        ((NSSearchFieldCell*)m_SearchTextField.cell).cancelButtonCell.target = self;
        ((NSSearchFieldCell*)m_SearchTextField.cell).cancelButtonCell.action = @selector(onSearchFieldDiscardButton:);
        [self addSubview:m_SearchTextField];
        
        m_SearchMatchesField= [[NSTextField alloc] initWithFrame:NSRect()];
        m_SearchMatchesField.stringValue = @"";
        m_SearchMatchesField.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchMatchesField.bordered = false;
        m_SearchMatchesField.editable = false;
        m_SearchMatchesField.drawsBackground = false;
        m_SearchMatchesField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SearchMatchesField.usesSingleLineMode = true;
        m_SearchMatchesField.alignment = NSTextAlignmentRight;
        m_SearchMatchesField.font = [NSFont labelFontOfSize:11];
        m_SearchMatchesField.textColor = [NSColor disabledControlTextColor];
        [self addSubview:m_SearchMatchesField];
        
        m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = false;
        m_SeparatorLine.boxType = NSBoxSeparator;
        [self addSubview:m_SeparatorLine];
   
        m_SortButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SortButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SortButton.title = @"N";
        m_SortButton.bordered = false;
        m_SortButton.buttonType = NSMomentaryLightButton;
        m_SortButton.action = @selector(onSortButtonAction:);
        m_SortButton.target = self;
        m_SortButton.enabled = true;
        [self addSubview:m_SortButton];
        
        m_BusyIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
        m_BusyIndicator.translatesAutoresizingMaskIntoConstraints = false;
        m_BusyIndicator.indeterminate = true;
        m_BusyIndicator.style = NSProgressIndicatorSpinningStyle;
        m_BusyIndicator.controlSize = NSSmallControlSize;
        m_BusyIndicator.displayedWhenStopped = false;
        [self addSubview:m_BusyIndicator];
        
        [self setupAppearance];
        [self setupLayout];
        
        __weak PanelViewHeader* weak_self = self;
        m_ThemeObservation = AppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::FilePanelsHeader, [weak_self]{
            if( auto strong_self = weak_self ) {
                [strong_self setupAppearance];
                [strong_self observeValueForKeyPath:@"active" ofObject:nil change:nil context:nil];
            }
        });
    }
    return self;
}

- (void) setupAppearance
{
    m_PathTextField.font = CurrentTheme().FilePanelsHeaderFont();
    m_SearchTextField.font = CurrentTheme().FilePanelsHeaderFont();
    m_SeparatorLine.borderColor = CurrentTheme().FilePanelsHeaderSeparatorColor();
    m_SortButton.font = CurrentTheme().FilePanelsHeaderFont();
    self.needsDisplay = true;
}

- (void) setupLayout
{
    NSDictionary *views = NSDictionaryOfVariableBindings(m_PathTextField,
                                                         m_SearchTextField,
                                                         m_SeparatorLine,
                                                         m_SearchMatchesField,
                                                         m_SortButton,
                                                         m_BusyIndicator);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"V:|-(==0)-[m_PathTextField]-(==0)-[m_SeparatorLine(<=1)]-(==0)-|"
        options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"V:|-(==0)-[m_SortButton]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"|-(==0)-[m_SortButton(==20)]-(==0)-[m_PathTextField]-[m_BusyIndicator]-(==2)-|"
        options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"V:[m_BusyIndicator]-(==2)-|" options:0 metrics:nil views:views]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:m_SearchTextField
                                                     attribute:NSLayoutAttributeLeft
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeLeft
                                                    multiplier:1
                                                      constant:-2]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:m_SearchTextField
                                                     attribute:NSLayoutAttributeRight
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeRight
                                                    multiplier:1
                                                      constant:2]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:m_SearchTextField
                                                     attribute:NSLayoutAttributeTop
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeTop
                                                    multiplier:1
                                                      constant:-2]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:m_SearchTextField
                                                     attribute:NSLayoutAttributeBottom
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeBottom
                                                    multiplier:1
                                                      constant:1]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_SeparatorLine]-(0)-|" options:0 metrics:nil views:views]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_SearchMatchesField(==50)]-(20)-|" options:0 metrics:nil views:views]];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchMatchesField, self)];
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) canDrawSubviewsIntoLayer
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if( m_Background && m_Background != NSColor.clearColor ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    }
    else {
        NSDrawWindowBackground(dirtyRect);
    }
}

- (void) setPath:(NSString*)_path
{
    m_PathTextField.stringValue = _path;
}

- (void)viewDidMoveToSuperview
{
    if( auto pv = objc_cast<PanelView>(self.superview) ) {
        m_PanelView = pv;
        [pv addObserver:self forKeyPath:@"active" options:0 context:NULL];
        [self observeValueForKeyPath:@"active" ofObject:pv change:nil context:nil];
        
        [m_SearchTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        [m_SearchMatchesField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
        [m_PathTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
        [m_SortButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
        [m_BusyIndicator bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
    }
    else {
        [m_PanelView removeObserver:self forKeyPath:@"active"];
        [m_SearchTextField unbind:@"hidden"];
        [m_SearchMatchesField unbind:@"hidden"];
        [m_PathTextField unbind:@"hidden"];
        [m_SortButton unbind:@"hidden"];
        [m_BusyIndicator bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( !m_PanelView )
        return;
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        m_Background = active ?
            CurrentTheme().FilePanelsHeaderActiveBackgroundColor() :
            CurrentTheme().FilePanelsHeaderInactiveBackgroundColor();
        [self setNeedsDisplay:true];
        
        NSColor *text_color = active ?
            CurrentTheme().FilePanelsHeaderActiveTextColor() :
            CurrentTheme().FilePanelsHeaderTextColor();
        m_PathTextField.textColor = text_color;
        
        NSMutableAttributedString *sort_title =
          [[NSMutableAttributedString alloc] initWithAttributedString:m_SortButton.attributedTitle];
        [sort_title addAttribute:NSForegroundColorAttributeName
                           value:text_color
                           range:NSMakeRange(0, sort_title.length)];
        m_SortButton.attributedTitle = sort_title;
    }
}

- (NSString*) searchPrompt
{
    return m_SearchPrompt;
}

- (void) setSearchPrompt:(NSString *)searchPrompt
{
    if( (m_SearchPrompt == searchPrompt) || (!m_SearchPrompt && !searchPrompt.length) )
        return;
    
    [self willChangeValueForKey:@"searchPrompt"];
    m_SearchPrompt = searchPrompt.length ? searchPrompt : nil;
    [self didChangeValueForKey:@"searchPrompt"];
    
    
    // ...
    m_SearchTextField.stringValue = m_SearchPrompt ? m_SearchPrompt : @"";
    [m_SearchTextField invalidateIntrinsicContentSize];
    [self layout];
}

- (int) searchMatches
{
    return m_SearchMatchesField.intValue;
}

- (void) setSearchMatches:(int)searchMatches
{
    m_SearchMatchesField.intValue = searchMatches;
}

- (void) onSearchFieldDiscardButton:(id)sender
{
    self.searchPrompt = nil;
    [self.window makeFirstResponder:m_PanelView];
    [((PanelController*)m_PanelView.delegate) QuickSearchClearFiltering];
}

- (void) onSearchFieldAction:(id)sender
{
    NSString *v = m_SearchTextField.stringValue;
    if( v.length > 0)
        [((PanelController*)m_PanelView.delegate) QuickSearchSetCriteria:v];
    else
        [self onSearchFieldDiscardButton:sender];
}

- (void) onSortButtonAction:(id)sender
{
    if( !self.sortMenuPopup ) {
        NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PanelViewHeaderSortPopup" bundle:nil];
        [nib instantiateWithOwner:self topLevelObjects:nil];
    }
    
    for( NSMenuItem *i in self.sortMenuPopup.itemArray ) {
        if( i.action == @selector(onSortPopupMenuSortByClicked:) )
            i.state = i.tag == m_SortMode.sort ? NSOnState : NSOffState;
        else if( i.action == @selector(onSortPopupMenuOptionsClicked:) )
            switch ( i.tag ) {
                case 1: i.state = m_SortMode.sep_dirs ? NSOnState : NSOffState; break;
                case 2: i.state = m_SortMode.case_sens ? NSOnState : NSOffState; break;
                case 3: i.state = m_SortMode.numeric_sort ? NSOnState : NSOffState; break;
            }
    }

    [self.sortMenuPopup popUpMenuPositioningItem:nil
                                      atLocation:NSMakePoint(m_SortButton.bounds.size.width, 0)
                                          inView:m_SortButton];
}

- (void) setSortMode:(PanelDataSortMode)_mode
{
    if( m_SortMode != _mode ) {
        m_SortMode = _mode;
        m_SortButton.title = SortLetter(_mode);
    }
}

- (IBAction)onSortPopupMenuSortByClicked:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) ) {
        PanelDataSortMode proposed = m_SortMode;
        proposed.sort = (PanelDataSortMode::Mode)item.tag;
        
        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (IBAction)onSortPopupMenuOptionsClicked:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) ) {
        PanelDataSortMode proposed = m_SortMode;
        switch ( item.tag ) {
            case 1: proposed.sep_dirs = !proposed.sep_dirs; break;
            case 2: proposed.case_sens = !proposed.case_sens; break;
            case 3: proposed.numeric_sort = !proposed.numeric_sort; break;
        }
        
        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (NSProgressIndicator *)busyIndicator
{
    return m_BusyIndicator;
}

@end
