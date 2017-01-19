#include <Utility/FontExtras.h>
#include <Utility/HexadecimalColor.h>
#include "PreferencesWindowThemesControls.h"

@interface AlphaColorWell : NSColorWell
@end

@implementation AlphaColorWell

- (void)activate:(BOOL)exclusive
{
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
    [super activate:exclusive];
}

- (void)deactivate
{
    [super deactivate];
    [[NSColorPanel sharedColorPanel] setShowsAlpha:NO];
}

@end



@implementation PreferencesWindowThemesTabColorControl
{
    NSColor         *m_Color;
    AlphaColorWell  *m_ColorWell;
    NSTextField     *m_Description;
}

- (id) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {
        m_Color = NSColor.blackColor;
    
        m_ColorWell = [[AlphaColorWell alloc] initWithFrame:NSRect()];
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
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[m_ColorWell(==40)]-[m_Description]-(>=0)-|"
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
            if( cw.color != m_Color ) {
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

@implementation PreferencesWindowThemesTabFontControl
{
    NSFont      *m_Font;
    NSButton    *m_Custom;
    NSButton    *m_System;
    NSTextField *m_Description;
}

- (id) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {
        m_Font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        
        m_Custom = [[NSButton alloc] initWithFrame:NSRect()];
        m_Custom.translatesAutoresizingMaskIntoConstraints = false;
        m_Custom.title = @"Custom";
        m_Custom.buttonType = NSButtonTypeMomentaryLight;
        m_Custom.bezelStyle = NSBezelStyleRecessed;
        ((NSButtonCell*)m_Custom.cell).controlSize = NSMiniControlSize;
        m_Custom.target = self;
        m_Custom.action = @selector(onSetCustomFont:);
        [self addSubview:m_Custom];

        m_System = [[NSButton alloc] initWithFrame:NSRect()];
        m_System.translatesAutoresizingMaskIntoConstraints = false;
        m_System.title = @"Standard";
        m_System.buttonType = NSButtonTypeMomentaryLight;
        m_System.bezelStyle = NSBezelStyleRecessed;
        ((NSButtonCell*)m_System.cell).controlSize = NSMiniControlSize;
        m_System.target = self;
        m_System.action = @selector(onSetStandardFont:);
        [self addSubview:m_System];
        
        m_Description = [[NSTextField alloc] initWithFrame:NSRect()];
        m_Description.translatesAutoresizingMaskIntoConstraints = false;
        m_Description.bordered = false;
        m_Description.editable = false;
        m_Description.drawsBackground = false;
        m_Description.font = [NSFont labelFontOfSize:11];
        m_Description.usesSingleLineMode = true;
        m_Description.stringValue = [m_Font toStringDescription];
        [self addSubview:m_Description];
        
        auto views = NSDictionaryOfVariableBindings(m_Custom, m_System, m_Description);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[m_Custom]-(==1)-[m_System]-[m_Description]-(>=0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        //NSLayoutAnchor

        [self addConstraint:[NSLayoutConstraint constraintWithItem:m_Custom
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:m_System
                                                         attribute:NSLayoutAttributeBaseline
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:m_Custom
                                                         attribute:NSLayoutAttributeBaseline
                                                        multiplier:1 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:m_Description
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1 constant:0]];
        
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_Custom(==18)]"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_System(==18)]"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
    }
    return self;
}

- (NSFont*)font
{
    return m_Font;
}

- (void) setFont:(NSFont *)font
{
    if( m_Font != font ) {
        m_Font = font;
        m_Description.stringValue = [m_Font toStringDescription];
    }
}

- (void) onSetCustomFont:(id)sender
{
    NSFontManager *fontManager = NSFontManager.sharedFontManager;
    fontManager.target = self;
    fontManager.action = @selector(fontManagerChanged:);
    [fontManager setSelectedFont:m_Font isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void) fontManagerChanged:(id)sender
{
    const auto new_font = [sender convertFont:m_Font];
    if( new_font != m_Font ) {
        m_Font = new_font;
        m_Description.stringValue = [m_Font toStringDescription];
        [self sendAction:self.action to:self.target];
    }
}

- (void) onSetStandardFont:(id)sender
{
    auto menu = [[NSMenu alloc] init];
    const auto sizes = {10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36};
    for( auto s: sizes ) {
        auto item = [[NSMenuItem alloc] init];
        item.title = [NSString stringWithFormat:@"%d", s];
        item.tag = s;
        item.target = self;
        item.action = @selector(standardFontClicked:);
        if( (int)floor(m_Font.pointSize+0.5) == s )
            item.state = NSOnState;
        [menu addItem:item];
    }
    
    [menu popUpMenuPositioningItem:nil
                        atLocation:NSMakePoint(0, [sender bounds].size.height)
                            inView:sender];
}

- (void) standardFontClicked:(id)sender
{
    if( auto i = objc_cast<NSMenuItem>(sender) ) {
        const auto new_font = [NSFont systemFontOfSize:i.tag];
        if( new_font != m_Font ) {
            m_Font = new_font;
            m_Description.stringValue = [m_Font toStringDescription];
            [self sendAction:self.action to:self.target];
        }
    }
}

@end
