#include <Utility/HexadecimalColor.h>
#include "PreferencesWindowThemesControls.h"

@implementation PreferencesWindowThemesTabColorControl
{
    NSColor     *m_Color;
    NSColorWell *m_ColorWell;
    NSTextField *m_Description;
}

- (id) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {
        m_Color = NSColor.blackColor;
    
        m_ColorWell = [[NSColorWell alloc] initWithFrame:NSRect()];
        m_ColorWell.translatesAutoresizingMaskIntoConstraints = false;
        m_ColorWell.color = m_Color;
        [self addSubview:m_ColorWell];
        
        m_Description = [[NSTextField alloc] initWithFrame:NSRect()];
        m_Description.translatesAutoresizingMaskIntoConstraints = false;
        m_Description.bordered = false;
        m_Description.editable = false;
        m_Description.drawsBackground = false;
        m_Description.font = [NSFont labelFontOfSize:11];

        
        [self addSubview:m_Description];
        
        auto views = NSDictionaryOfVariableBindings(m_ColorWell, m_Description);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[m_ColorWell(==40)]-[m_Description]-(>=0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0@250)-[m_ColorWell(==18)]-(>=0@250)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_Description]-(==0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        
    }
    return self;
}

- (void) viewDidMoveToSuperview
{
    if( self.superview )
        [m_ColorWell addObserver:self forKeyPath:@"color" options:0 context:NULL];
    else
        [m_ColorWell removeObserver:self forKeyPath:@"color"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if( [keyPath isEqualToString:@"color"] )
        if( NSColorWell *cw = objc_cast<NSColorWell>(object) ) {
            if( cw.color != m_Color &&
                !CGColorEqualToColor(cw.color.CGColor, m_Color.CGColor) ) {
                m_Color = cw.color;
                m_Description.stringValue = [m_Color toHexString];
                [self sendAction:self.action to:self.target];
            }
        }
}

- (NSColor*)color
{
    return m_Color;
}

- (void) setColor:(NSColor *)color
{
    if( m_Color != color ) {
        m_Color = color;
        m_ColorWell.color = m_Color;
        m_Description.stringValue = [m_Color toHexString];
    }
}

@end
