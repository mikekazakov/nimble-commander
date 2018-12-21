// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include <Utility/HexadecimalColor.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>
#include "PreferencesWindowPanelsTabColoringFilterSheet.h"
#include "PreferencesWindowThemesControls.h"
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>

@interface NCPreferencesAlphaColorWell : NSColorWell
@end

@implementation NCPreferencesAlphaColorWell

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

@implementation NCPreferencesActionTableCellView

- (BOOL)sendAction:(SEL)action to:(id)target
{
    return [NSApp sendAction:action to:target from:self];
}

@end

@implementation PreferencesWindowThemesTabColorControl
{
    NSColor         *m_Color;
    NCPreferencesAlphaColorWell  *m_ColorWell;
    NSTextField     *m_Description;
}

- (id) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {
        m_Color = NSColor.blackColor;
    
        m_ColorWell = [[NCPreferencesAlphaColorWell alloc] initWithFrame:NSRect()];
        m_ColorWell.translatesAutoresizingMaskIntoConstraints = false;
        m_ColorWell.color = m_Color;
        m_ColorWell.target = self;
        m_ColorWell.action = @selector(colorChanged:);
        [self addSubview:m_ColorWell];
        
        m_Description = [[NSTextField alloc] initWithFrame:NSRect()];
        m_Description.translatesAutoresizingMaskIntoConstraints = false;
        m_Description.bordered = false;
        m_Description.editable = false;
        m_Description.drawsBackground = false;
        m_Description.font = [NSFont labelFontOfSize:11];
        m_Description.stringValue = [m_Color toHexString];        
        [self addSubview:m_Description];
        
        auto views = NSDictionaryOfVariableBindings(m_ColorWell, m_Description);
        auto add_visfmt = [&](NSString *_layout) {
            auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_layout
                                                                       options:0
                                                                       metrics:nil
                                                                         views:views];
            [self addConstraints:constraints];
        };
        add_visfmt(@"|[m_ColorWell(==40)]-[m_Description]-(>=0)-|");
        add_visfmt(@"V:|-(>=0@250)-[m_ColorWell(==18)]-(>=0@250)-|");
        add_visfmt(@"V:|-(==0)-[m_Description]-(==0)-|");
    }
    return self;
}

- (void)colorChanged:(id)sender
{
    if( NSColorWell *cw = objc_cast<NSColorWell>(sender) ) {
            if( cw.color != m_Color ) {
                m_Color = cw.color;
                m_Description.stringValue = [m_Color toHexString];
                [self sendAction:self.action to:self.target];
            }
        }
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
    if( !color )
        return;
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
    if( !font )
        return;
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
        if( (int)std::floor(m_Font.pointSize+0.5) == s )
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

@interface PreferencesWindowThemesTabColoringRulesControl()
@property (nonatomic) IBOutlet NSView *carrier;
@property (nonatomic) IBOutlet NSTableView *table;
@property (nonatomic) IBOutlet NSSegmentedControl *plusMinus;


@end

static const auto g_PreferencesWindowThemesTabColoringRulesControlDataType =
    @"PreferencesWindowThemesTabColoringRulesControlDataType";

@implementation PreferencesWindowThemesTabColoringRulesControl
{
    vector<nc::panel::PresentationItemsColoringRule> m_Rules;

}

- (id) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {
    
        NSNib *nib = [[NSNib alloc] initWithNibNamed:
                      @"PreferencesWindowThemesTabColoringRulesControl" bundle:nil];
        [nib instantiateWithOwner:self topLevelObjects:nil];
        
        auto v = self.carrier;
        v.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:self.carrier];
        
        auto views = NSDictionaryOfVariableBindings(v);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[v]|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v]|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        
        [self.table registerForDraggedTypes:
            @[g_PreferencesWindowThemesTabColoringRulesControlDataType]];
    }
    return self;
    
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Rules.size();
}

- (void) setRules:(vector<nc::panel::PresentationItemsColoringRule>)rules
{
    if( m_Rules != rules ) {
        m_Rules = rules;
        [self.table reloadData];
    }
}

- (vector<nc::panel::PresentationItemsColoringRule>)rules
{
    return m_Rules;
}

- (void)onColorChanged:(id)sender
{
    if( NSColorWell *cw = objc_cast<NSColorWell>(sender) )
        if( auto rv = objc_cast<NSTableRowView>(cw.superview) )
            if( rv.superview == self.table ) {
                long row_no = [self.table rowForView:rv];
                if( row_no >= 0 ) {
                    auto new_color = cw.color;
                    if( cw == [rv viewAtColumn:1] && m_Rules.at(row_no).regular != new_color ) {
                        m_Rules.at(row_no).regular = new_color;
                        [self commit];
                    }
                    if( cw == [rv viewAtColumn:2] && m_Rules.at(row_no).focused != new_color ) {
                        m_Rules.at(row_no).focused = new_color;
                        [self commit];
                    }
                }
            }
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if( row >= (int)m_Rules.size() )
        return nil;
    auto &r = m_Rules[row];
    if([tableColumn.identifier isEqualToString:@"name"]) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
        tf.stringValue = [NSString stringWithUTF8StdString:r.name];
        tf.bordered = false;
        tf.editable = true;
        tf.drawsBackground = false;
        tf.delegate = self;
        return tf;
    }
    if([tableColumn.identifier isEqualToString:@"unfocused"]) {
        NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
        cw.color = r.regular;
        cw.target = self;
        cw.action = @selector(onColorChanged:);
        return cw;
    }
    if([tableColumn.identifier isEqualToString:@"focused"]) {
        NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
        cw.color = r.focused;
        cw.target = self;
        cw.action = @selector(onColorChanged:);
        return cw;
    }
    if([tableColumn.identifier isEqualToString:@"filter"]) {
        NSButton *bt = [[NSButton alloc] initWithFrame:NSRect()];
        bt.title = NSLocalizedStringFromTable(@"edit",
                                              @"Preferences",
                                              "Coloring rules edit button title");
        bt.buttonType = NSButtonTypeMomentaryLight;
        bt.bezelStyle = NSBezelStyleRecessed;
        ((NSButtonCell*)bt.cell).controlSize = NSMiniControlSize;
        bt.target = self;
        bt.action = @selector(onColoringFilterClicked:);
        return bt;
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView
    didAddRowView:(NSTableRowView *)rowView
           forRow:(NSInteger)row
{
    for( int i = 1; i <= 2; ++i ) {
        NSView *v = [rowView viewAtColumn:i];
        NSRect rc = v.frame;
        rc.size.width = 40;
        rc.origin.x += (v.frame.size.width - rc.size.width) / 2.;
        v.frame = rc;
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;
    if( auto rv = objc_cast<NSTableRowView>(tf.superview) ) {
        if( rv.superview == self.table ) {
            long row_no = [self.table rowForView:rv];
            if( row_no >= 0 ) {
                auto new_value = tf.stringValue ? tf.stringValue.UTF8String : "";
                if( m_Rules[row_no].name != new_value ) {
                    m_Rules[row_no].name = new_value;
                    [self commit];
                }
            }
        }
    }
}

- (void) onColoringFilterClicked:(id)sender
{
    if( auto button = objc_cast<NSButton>(sender) )
        if( auto rv = objc_cast<NSTableRowView>(button.superview) ) {
            long row_no = [((NSTableView*)rv.superview) rowForView:rv];
            auto sheet = [[PreferencesWindowPanelsTabColoringFilterSheet alloc]
                initWithFilter:m_Rules.at(row_no).filter];
            [sheet beginSheetForWindow:self.window
                     completionHandler:^(NSModalResponse returnCode) {
                         if( returnCode != NSModalResponseOK )
                             return;
                         if( sheet.filter != m_Rules.at(row_no).filter ) {
                            m_Rules.at(row_no).filter = sheet.filter;
                            [self commit];
                         }
                     }];
        }
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
                validateDrop:(id < NSDraggingInfo >)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:@[g_PreferencesWindowThemesTabColoringRulesControlDataType]
                   owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes]
            forType:g_PreferencesWindowThemesTabColoringRulesControlDataType];
    return true;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)operation
{
    NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard
        dataForType:g_PreferencesWindowThemesTabColoringRulesControlDataType]];
    NSInteger drag_from = inds.firstIndex;
    
    if(drag_to == drag_from || // same index, above
       drag_to == drag_from + 1) // same index, below
    return false;
    
    assert(drag_from < (int)m_Rules.size());
    
    auto i = begin(m_Rules);
    if( drag_from < drag_to )
        rotate( i + drag_from, i + drag_from + 1, i + drag_to );
    else
        rotate( i + drag_to, i + drag_from, i + drag_from + 1 );
    [self.table reloadData];
    [self commit];
    return true;
}

- (IBAction)onPlusMinusButton:(id)sender
{
    const auto segment = self.plusMinus.selectedSegment;
    if( segment == 0 ) {
        m_Rules.emplace_back();
        [self.table reloadData];
        [self commit];
    }
    else if( segment == 1 ) {
        const auto row = self.table.selectedRow;
        if( row < 0 )
            return;
        m_Rules.erase( begin(m_Rules) + row );
        [self.table reloadData];
        [self commit];
    }
}

- (void) commit
{
    [self sendAction:self.action to:self.target];
}

@end

@implementation PreferencesWindowThemesAppearanceControl
{
    NSPopUpButton *m_Button;
    ThemeAppearance m_ThemeAppearance;
}

- (id) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {
        m_ThemeAppearance = ThemeAppearance::Light;
        m_Button = [[NSPopUpButton alloc] initWithFrame:NSRect()];
        m_Button.translatesAutoresizingMaskIntoConstraints = false;
        ((NSPopUpButtonCell*)m_Button.cell).controlSize = NSControlSizeSmall;
        [m_Button addItemWithTitle:@"Aqua"];
        m_Button.lastItem.tag = (int)ThemeAppearance::Light;
        [m_Button addItemWithTitle:@"Dark"];
        m_Button.lastItem.tag = (int)ThemeAppearance::Dark;
        [m_Button selectItemWithTag:(int)m_ThemeAppearance];
        m_Button.target = self;
        m_Button.action = @selector(onSelectionChanged:);
        [self addSubview:m_Button];
        
        auto views = NSDictionaryOfVariableBindings(m_Button);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[m_Button(>=80)]"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:m_Button
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1 constant:0]];
    }
    return self;
}

- (void)onSelectionChanged:(id)sender
{
    auto new_value = (ThemeAppearance)m_Button.selectedTag;
    if( new_value != m_ThemeAppearance ) {
        m_ThemeAppearance = new_value;
        [self sendAction:self.action to:self.target];
    }
}

- (void)setThemeAppearance:(ThemeAppearance)themeAppearance
{
    if( m_ThemeAppearance != themeAppearance ) {
        m_ThemeAppearance = themeAppearance;
        [m_Button selectItemWithTag:(int)m_ThemeAppearance];
    }
}

- (ThemeAppearance)themeAppearance
{
    return m_ThemeAppearance;
}

- (void)setEnabled:(bool)enabled
{
    m_Button.enabled = enabled;
}

- (bool)enabled
{
    return m_Button.enabled;
}

@end

