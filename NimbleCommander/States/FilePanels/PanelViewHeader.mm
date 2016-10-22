#include <Utility/Layout.h>
#include "../../../Files/PanelView.h"
#include "../../../Files/PanelController.h"
#include "PanelViewHeader.h"

@implementation PanelViewHeader
{
    NSTextField         *m_PathTextField;
    NSSearchField       *m_SearchTextField;
    NSTextField         *m_SearchMatchesField;
    NSBox               *m_SeparatorLine;
    NSColor             *m_Background;
    NSString            *m_SearchPrompt;
    __weak PanelView    *m_PanelView;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_SearchPrompt = nil;
        
        m_PathTextField= [[NSTextField alloc] initWithFrame:NSRect()];
        m_PathTextField.translatesAutoresizingMaskIntoConstraints = false;
        m_PathTextField.bordered = false;
        m_PathTextField.editable = false;
        m_PathTextField.drawsBackground = false;
        m_PathTextField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_PathTextField.usesSingleLineMode = true;
        m_PathTextField.alignment = NSTextAlignmentCenter;
        m_PathTextField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        [self addSubview:m_PathTextField];
        
        m_SearchTextField= [[NSSearchField alloc] initWithFrame:NSRect()];
        m_SearchTextField.translatesAutoresizingMaskIntoConstraints = false;
//        m_SearchTextField.delegate = self;
        m_SearchTextField.sendsWholeSearchString = false;
        m_SearchTextField.target = self;
        m_SearchTextField.action = @selector(onSearchFieldAction:);
        m_SearchTextField.bordered = false;
        m_SearchTextField.bezeled = true;
        m_SearchTextField.editable = true;
        m_SearchTextField.drawsBackground = false;
        m_SearchTextField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        m_SearchTextField.focusRingType = NSFocusRingTypeNone;
        m_SearchTextField.alignment = NSTextAlignmentCenter;
        ((NSSearchFieldCell*)m_SearchTextField.cell).cancelButtonCell.target = self;
        ((NSSearchFieldCell*)m_SearchTextField.cell).cancelButtonCell.action = @selector(onSearchFieldDiscardButton:);
//        [((NSSearchFieldCell*)m_SearchTextField.cell).cancelButtonCell setButtonType:NSButtonTypeMomentaryLight];
//        - (void)setButtonType:(NSButtonType)type;
        //- (void)setButtonType:(NSButtonType)type;
//        m_SearchTextField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
//        m_SearchTextField.cell.wraps = false;
        
//        NSTextFieldCellz
        
//- (void) onSearchFieldDiscardButton:(id)sender
        
        [self addSubview:m_SearchTextField];
        
        
//        NSSearchFieldCell
        
        
        m_SearchMatchesField= [[NSTextField alloc] initWithFrame:NSRect()];
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
        
        m_SeparatorLine = [[NSBox alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
        m_SeparatorLine.boxType = NSBoxSeparator;
        [self addSubview:m_SeparatorLine];
   
        [self setupLayout];
    }
    return self;
}

- (void) setupLayout
{
    NSDictionary *views = NSDictionaryOfVariableBindings(m_PathTextField, m_SearchTextField, m_SeparatorLine, m_SearchMatchesField);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_PathTextField]-(==0)-[m_SeparatorLine(<=1)]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==40)-[m_PathTextField]-(0)-|" options:0 metrics:nil views:views]];
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

-(void) dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
//    [NSNotificationCenter.defaultCenter removeObserver:self];
}


- (void)drawRect:(NSRect)dirtyRect
{
//    const auto bounds = self.bounds;
    if( m_Background  ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
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
        
    }
    else {
        [m_SearchTextField unbind:@"hidden"];
        [m_SearchMatchesField unbind:@"hidden"];
        [m_PathTextField unbind:@"hidden"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        m_Background = active ? NSColor.controlAlternatingRowBackgroundColors[0] : nil;
        [self setNeedsDisplay:true];
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
    int a = 10;
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

@end
