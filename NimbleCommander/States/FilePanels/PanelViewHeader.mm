#include <Utility/Layout.h>
#include "../../../Files/PanelView.h"
#include "PanelViewHeader.h"

@implementation PanelViewHeader
{
    NSTextField         *m_PathTextField;
    NSSearchField       *m_SearchTextField;
    NSBox               *m_SeparatorLine;
    NSColor             *m_Background;
    NSString            *m_SearchPrompt;
    int                 m_SearchMatches;
    __weak PanelView    *m_PanelView;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_SearchMatches = 0;
        m_SearchPrompt = nil;
        
        m_SeparatorLine = [[NSBox alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
        m_SeparatorLine.boxType = NSBoxSeparator;
        [self addSubview:m_SeparatorLine];
        
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
        m_SearchTextField.bordered = false;
        m_SearchTextField.bezeled = true;
        m_SearchTextField.editable = true;
        m_SearchTextField.drawsBackground = false;
        m_SearchTextField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        m_SearchTextField.focusRingType = NSFocusRingTypeNone;
        m_SearchTextField.alignment = NSTextAlignmentCenter;
//        m_SearchTextField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
//        m_SearchTextField.cell.wraps = false;
        
//        NSTextFieldCellz
        
        [self addSubview:m_SearchTextField];
        
   
        [self setupLayout];
    
        
//        m_PathTextField.hidden = true;
//        if( self.superview )
//        else
//            [m_DiscardButton unbind:@"hidden"];
        
    }
    return self;
}

- (void) setupLayout
{
    NSDictionary *views = NSDictionaryOfVariableBindings(m_PathTextField, m_SearchTextField, m_SeparatorLine);
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
                                                      constant:-1]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_SeparatorLine]-(0)-|" options:0 metrics:nil views:views]];
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
        [m_PathTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
    }
    else {
        [m_SearchTextField unbind:@"hidden"];
        [m_PathTextField unbind:@"hidden"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        m_Background = active ? NSColor.controlAlternatingRowBackgroundColors[0] : nil;
        [self setNeedsDisplay:true];
//        for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
//            [i setPanelActive:active];
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
    return m_SearchMatches;
}

- (void) setSearchMatches:(int)searchMatches
{
    // ...
}


//@property (nonatomic, readonly) NSString *searchPrompt;
//@property (nonatomic, readonly) int       searchMatches;


@end
