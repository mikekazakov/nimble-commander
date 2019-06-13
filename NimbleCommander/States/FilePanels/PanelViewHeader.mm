// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewHeader.h"
#include <Utility/Layout.h>
#include <Utility/ObjCpp.h>
#include <Utility/ColoredSeparatorLine.h>
#include <Utility/VerticallyCenteredTextFieldCell.h>

using namespace nc::panel;

static NSString *SortLetter(data::SortMode _mode) noexcept;
static void ChangeForegroundColor(NSButton *_button, NSColor *_new_color);
static void ChangeAttributedTitle(NSButton *_button, NSString *_new_text);
static bool IsDark( NSColor *_color );

@interface NCPanelViewHeader()
@property (nonatomic) IBOutlet NSMenu *sortMenuPopup;
@end

@implementation NCPanelViewHeader
{
    NSTextField         *m_PathTextField;
    NSSearchField       *m_SearchTextField;
    NSTextField         *m_SearchMatchesField;
    ColoredSeparatorLine*m_SeparatorLine;
    NSColor             *m_Background;
    NSString            *m_SearchPrompt;
    NSButton            *m_SortButton;
    NSProgressIndicator *m_BusyIndicator;
    data::SortMode      m_SortMode;
    std::function<void(data::SortMode)> m_SortModeChangeCallback;
    std::function<void(NSString*)> m_SearchRequestChangeCallback;
    std::unique_ptr<nc::panel::HeaderTheme> m_Theme;
    bool                m_Active;     
}

@synthesize sortMode = m_SortMode;
@synthesize sortModeChangeCallback = m_SortModeChangeCallback;

- (id) initWithFrame:(NSRect)frameRect
               theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Theme = std::move(_theme);
        m_SearchPrompt = nil;
        m_Active = false;
        
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
        m_SearchTextField.delegate = self;
        auto search_tf_cell = (NSSearchFieldCell*)m_SearchTextField.cell;
        search_tf_cell.cancelButtonCell.target = self;
        search_tf_cell.cancelButtonCell.action = @selector(onSearchFieldDiscardButton:);
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
        m_BusyIndicator.style = NSProgressIndicatorSpinningStyle;
        m_BusyIndicator.controlSize = NSSmallControlSize;
        m_BusyIndicator.displayedWhenStopped = false;
        if( IsDark(m_Theme->ActiveBackgroundColor()) )
            m_BusyIndicator.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];        
        [self addSubview:m_BusyIndicator positioned:NSWindowAbove relativeTo:m_PathTextField];
        
        [self setupAppearance];
        [self setupLayout];
        
        __weak NCPanelViewHeader* weak_self = self;
        m_Theme->ObserveChanges([weak_self]{
            if( auto strong_self = weak_self )
                [strong_self setupAppearance];
        });
    }
    return self;
}

- (void) setupAppearance
{
    const auto font = m_Theme->Font();
    m_PathTextField.font = font;
    m_SearchTextField.font = font;
    m_SeparatorLine.borderColor = m_Theme->SeparatorColor();
    m_SortButton.font = font;
    
    const bool active = m_Active;
    m_Background = active ? m_Theme->ActiveBackgroundColor() : m_Theme->InactiveBackgroundColor();
    
    const auto text_color = active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
    m_PathTextField.textColor = text_color;
    
    ChangeForegroundColor(m_SortButton, text_color);
    
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
        @"V:|-(==0)-[m_PathTextField]-(==0)-[m_SeparatorLine(==1)]-(==0)-|"
        options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"V:|-(==0)-[m_SortButton]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"|-(==0)-[m_SortButton(==20)]-(==0)-[m_PathTextField]-(==2)-|"
        options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
        @"[m_BusyIndicator]-(==2)-|"
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
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"|-(0)-[m_SeparatorLine]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"[m_SearchMatchesField(==50)]-(20)-|" options:0 metrics:nil views:views]];
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

- (void)setupBindings
{
    static const auto isnil = @{NSValueTransformerNameBindingOption:NSIsNilTransformerName};
    static const auto isnotnil = @{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName};
    [m_SearchTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchMatchesField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_PathTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
    [m_SortButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
    [m_BusyIndicator bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
}

- (void)removeBindings
{
    [m_SearchTextField unbind:@"hidden"];
    [m_SearchMatchesField unbind:@"hidden"];
    [m_PathTextField unbind:@"hidden"];
    [m_SortButton unbind:@"hidden"];
    [m_BusyIndicator unbind:@"hidden"];
}

- (void)viewDidMoveToSuperview
{
    if( self.superview )
        [self setupBindings];
    else
        [self removeBindings];

}

- (void)setSearchRequestChangeCallback:(std::function<void (NSString *)>)searchRequestChangeCallback
{
    m_SearchRequestChangeCallback = move(searchRequestChangeCallback);
}

- (std::function<void (NSString *)>)searchRequestChangeCallback
{
    return m_SearchRequestChangeCallback;
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

- (void) onSearchFieldDiscardButton:(id)[[maybe_unused]]_sender
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
        if( v.length > 0) {
            if( m_SearchRequestChangeCallback )
                m_SearchRequestChangeCallback(v);
        }
        else
            [self onSearchFieldDiscardButton:m_SearchTextField];
    }
}

- (void) onSearchFieldAction:(id)[[maybe_unused]]_sender
{
}

- (void) onSortButtonAction:(id)[[maybe_unused]]_sender
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
                case 2: i.state = m_SortMode.extensionless_dirs ? NSOnState : NSOffState; break;
                case 3: i.state = m_SortMode.case_sens ? NSOnState : NSOffState; break;
                case 4: i.state = m_SortMode.numeric_sort ? NSOnState : NSOffState; break;
            }
    }

    [self.sortMenuPopup popUpMenuPositioningItem:nil
                                      atLocation:NSMakePoint(m_SortButton.bounds.size.width, 0)
                                          inView:m_SortButton];
}

- (void) setSortMode:(data::SortMode)_mode
{
    if( m_SortMode == _mode )
        return;
    
    m_SortMode = _mode;    
    ChangeAttributedTitle(m_SortButton, SortLetter(_mode));
}

- (IBAction)onSortPopupMenuSortByClicked:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) ) {
        auto proposed = m_SortMode;
        proposed.sort = (data::SortMode::Mode)item.tag;
        
        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (IBAction)onSortPopupMenuOptionsClicked:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) ) {
        auto proposed = m_SortMode;
        switch ( item.tag ) {
            case 1: proposed.sep_dirs = !proposed.sep_dirs; break;
            case 2: proposed.extensionless_dirs = !proposed.extensionless_dirs; break;
            case 3: proposed.case_sens = !proposed.case_sens; break;
            case 4: proposed.numeric_sort = !proposed.numeric_sort; break;
        }
        
        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (NSProgressIndicator *)busyIndicator
{
    return m_BusyIndicator;
}

- (void) setActive:(bool)active
{
    if( active == m_Active )
        return;
    m_Active = active;
    
    [self setupAppearance];
}

- (bool) active
{
    return m_Active;
}

@end

static void ChangeForegroundColor(NSButton *_button, NSColor *_new_color)
{
    const auto sort_title = [[NSMutableAttributedString alloc]
                             initWithAttributedString:_button.attributedTitle];
    [sort_title addAttribute:NSForegroundColorAttributeName
                       value:_new_color
                       range:NSMakeRange(0, sort_title.length)];
    _button.attributedTitle = sort_title;        
}

static void ChangeAttributedTitle(NSButton *_button, NSString *_new_text)
{
    const auto title = [[NSMutableAttributedString alloc]
                        initWithAttributedString:_button.attributedTitle];
    [title replaceCharactersInRange:NSMakeRange(0, title.length)
                         withString:_new_text];
    _button.attributedTitle = title;    
}

static NSString *SortLetter(data::SortMode _mode) noexcept
{
    switch( _mode.sort ) {
        case data::SortMode::SortByName:         return @"n";
        case data::SortMode::SortByNameRev:      return @"N";
        case data::SortMode::SortByExt:          return @"e";
        case data::SortMode::SortByExtRev:       return @"E";
        case data::SortMode::SortBySize:         return @"s";
        case data::SortMode::SortBySizeRev:      return @"S";
        case data::SortMode::SortByModTime:      return @"m";
        case data::SortMode::SortByModTimeRev:   return @"M";
        case data::SortMode::SortByBirthTime:    return @"b";
        case data::SortMode::SortByBirthTimeRev: return @"B";
        case data::SortMode::SortByAddTime:      return @"a";
        case data::SortMode::SortByAddTimeRev:   return @"A";
        default:                                 return @"?";
    }
}

static float Brightness( NSColor *_color )
{
    const auto c = [_color colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    return (float)c.brightnessComponent;
}

static bool IsDark( NSColor *_color )
{
    return Brightness(_color) < 0.60;
}
