//
//  PreferencesWindowPanelsTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include "PreferencesWindowPanelsTab.h"
//#include "../../Files/ClassicPanelViewPresentation.h"
//#include "../../Files/ModernPanelViewPresentation.h"
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/States/FilePanels/PanelViewLayoutSupport.h>
#include "PreferencesWindowPanelsTabColoringFilterSheet.h"
#include <Utility/ByteCountFormatter.h>

#define MyPrivateTableViewDataTypeClassic @"PreferencesWindowPanelsTabPrivateTableViewDataTypeClassic"
#define MyPrivateTableViewDataTypeModern @"PreferencesWindowPanelsTabPrivateTableViewDataTypeModern"
static const auto g_LayoutColumnsDDType = @"PreferencesWindowPanelsTabPrivateTableViewDataColumns";

static const auto g_ConfigClassicColoring   = "filePanel.classic.coloringRules_v1";
static const auto g_ConfigModernColoring    = "filePanel.modern.coloringRules_v1";
static const auto g_ConfigClassicFont       = "filePanel.classic.font";

@interface PreferencesToNumberValueTransformer : NSValueTransformer
@end

@implementation PreferencesToNumberValueTransformer
+(Class)transformedValueClass {
    return [NSNumber class];
}
-(id)transformedValue:(id)value {
    if( auto n = objc_cast<NSNumber>(value) )
        return n;
    else if( auto s = objc_cast<NSString>(value) )
        return [NSNumber numberWithInt:s.intValue];
    return @0;
}
@end

@interface PreferencesHexStringToColorValueTransformer : NSValueTransformer
@end

@implementation PreferencesHexStringToColorValueTransformer

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass {
    return [NSColor class];
}

- (id)transformedValue:(id)value
{
    if( auto s = objc_cast<NSString>(value) )
        return [NSColor colorWithHexString:s.UTF8String];
    return nil;
}

- (id)reverseTransformedValue:(id)value
{
    if( auto c = objc_cast<NSColor>(value) )
        return [c toHexString];
    return nil;
}

@end

@interface PreferencesWindowPanelsTabFlippedStackView : NSStackView
@end
@implementation PreferencesWindowPanelsTabFlippedStackView
- (BOOL) isFlipped
{
    return YES;
}
@end

@interface PreferencesWindowPanelsTab()

@property (strong) IBOutlet NSTableView *classicColoringRulesTable;
@property (strong) IBOutlet NSTableView *modernColoringRulesTable;
@property (strong) IBOutlet NSPopUpButton *fileSizeFormatCombo;
@property (strong) IBOutlet NSPopUpButton *selectionSizeFormatCombo;


// layout bindings
@property (strong) IBOutlet NSTableView *layoutsTable;
@property bool anyLayoutSelected;
@property (strong) IBOutlet NSTextField *layoutTitle;
@property (strong) IBOutlet NSPopUpButton *layoutType;
@property (strong) IBOutlet NSTabView  *layoutDetailsTabView;
@property (strong) IBOutlet NSButton   *layoutsBriefFixedRadio;
@property ()                bool        layoutsBriefFixedRadioChoosen;
@property (strong) IBOutlet NSTextField*layoutsBriefFixedValueTextField;
@property (strong) IBOutlet NSButton   *layoutsBriefAmountRadio;
@property ()                bool        layoutsBriefAmountRadioChoosen;
@property (strong) IBOutlet NSTextField*layoutsBriefAmountValueTextField;
@property (strong) IBOutlet NSButton   *layoutsBriefDynamicRadio;
@property ()                bool        layoutsBriefDynamicRadioChoosen;
@property (strong) IBOutlet NSTextField*layoutsBriefDynamicMinValueTextField;
@property (strong) IBOutlet NSTextField*layoutsBriefDynamicMaxValueTextField;
@property (strong) IBOutlet NSButton   *layoutsBriefDynamicEqualCheckbox;
@property (strong) IBOutlet NSButton   *layoutsBriefIcon0x;
@property (strong) IBOutlet NSButton   *layoutsBriefIcon1x;
@property (strong) IBOutlet NSButton   *layoutsBriefIcon2x;
@property (strong) IBOutlet NSTableView *layoutsListColumnsTable;


@end

@implementation PreferencesWindowPanelsTab
{
    NSFont *m_ClassicFont;
    vector<PanelViewPresentationItemsColoringRule> m_ModernColoringRules;
    vector<PanelViewPresentationItemsColoringRule> m_ClassicColoringRules;
    PanelViewLayoutsStorage *m_LayoutsStorage;
    vector< pair<PanelListViewColumnsLayout::Column, bool> > m_LayoutListColumns;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    static once_flag once;
    call_once(once, []{
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:
@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"];
        if( image )
            [image setName:@"GenericApplicationIcon"];
    });

    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        m_LayoutsStorage = &AppDelegate.me.panelLayouts;
        
        auto mcr = GlobalConfig().Get(g_ConfigModernColoring);
        if( mcr.IsArray() )
            for( auto i = mcr.Begin(), e = mcr.End(); i != e; ++i )
                m_ModernColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
        
        auto ccr = GlobalConfig().Get(g_ConfigClassicColoring);
        if( ccr.IsArray() )
            for( auto i = ccr.Begin(), e = ccr.End(); i != e; ++i )
                m_ClassicColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    self.classicColoringRulesTable.dataSource = self;
    self.classicColoringRulesTable.delegate = self;
    [self.classicColoringRulesTable registerForDraggedTypes:@[MyPrivateTableViewDataTypeClassic]];
    self.modernColoringRulesTable.dataSource = self;
    self.modernColoringRulesTable.delegate = self;
    [self.modernColoringRulesTable registerForDraggedTypes:@[MyPrivateTableViewDataTypeModern]];
    
    [self.layoutsListColumnsTable registerForDraggedTypes:@[g_LayoutColumnsDDType]];
    
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    column.width = 120;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Name",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"unfocused"];
    column.width = 70;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Regular",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"focused"];
    column.width = 70;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Focused",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"filter"];
    column.width = 70;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Filter",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    column.width = 120;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Name",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"regular"];
    column.width = 70;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Regular",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"focused"];
    column.width = 70;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Focused",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"filter"];
    column.width = 70;
    ((NSTableHeaderCell*)column.headerCell).stringValue = NSLocalizedStringFromTable(@"Filter",
                                                                                     @"Preferences",
                                                                                     "Coloring rules column name");
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    
    uint64_t magic_size = 2597065;
    for(NSMenuItem *it in self.fileSizeFormatCombo.itemArray)
        it.title = ByteCountFormatter::Instance().ToNSString(magic_size, (ByteCountFormatter::Type)it.tag);
    for(NSMenuItem *it in self.selectionSizeFormatCombo.itemArray)
        it.title = ByteCountFormatter::Instance().ToNSString(magic_size, (ByteCountFormatter::Type)it.tag);
  
    [self.view layoutSubtreeIfNeeded];
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"PreferencesIcons_Panels"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"Panels",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (IBAction)OnSetClassicFont:(id)sender
{
    m_ClassicFont = [NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigClassicFont).value_or("")]];
    if(!m_ClassicFont) m_ClassicFont = [NSFont fontWithName:@"Menlo Regular" size:15];

    NSFontManager *fontManager = NSFontManager.sharedFontManager;
    fontManager.target = self;
    fontManager.action = @selector(ChangeClassicFont:);
    [fontManager setSelectedFont:m_ClassicFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)ChangeClassicFont:(id)sender
{
    m_ClassicFont = [sender convertFont:m_ClassicFont];
    GlobalConfig().Set(g_ConfigClassicFont, [m_ClassicFont toStringDescription].UTF8String);
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( tableView == self.classicColoringRulesTable )
        return m_ClassicColoringRules.size();
    if( tableView == self.modernColoringRulesTable )
        return m_ModernColoringRules.size();
    if( tableView == self.layoutsTable )
        return m_LayoutsStorage->LayoutsCount();
    if( tableView == self.layoutsListColumnsTable )
//        return 5;
        return m_LayoutListColumns.size();
    return 0;
}

//enum class PanelListViewColumns : signed char
//{
//    Empty           = 0,
//    Filename        = 1,
//    Size            = 2,
//    DateCreated     = 3,
//    DateAdded       = 4,
//    DateModified    = 5
//};

static NSString* PanelListColumnTypeToString( PanelListViewColumns _c )
{
    switch( _c ) {
        case PanelListViewColumns::Filename:    return @"Name";
        case PanelListViewColumns::Size:        return @"Size";
        case PanelListViewColumns::DateCreated: return @"Date Created";
        case PanelListViewColumns::DateAdded:   return @"Date Added";
        case PanelListViewColumns::DateModified:return @"Date Modified";
        default:                                return @"";
    }
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if(tableView == self.classicColoringRulesTable) {
        auto &r = m_ClassicColoringRules.at(row);
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
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"focused"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = r.focused;
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"filter"]) {
            NSButton *bt = [[NSButton alloc] initWithFrame:NSRect()];
            bt.title = NSLocalizedStringFromTable(@"edit",
                                                  @"Preferences",
                                                  "Coloring rules edit button title");
            bt.buttonType = NSMomentaryPushInButton;
            bt.bezelStyle = NSRoundedBezelStyle;
            ((NSButtonCell*)bt.cell).controlSize = NSMiniControlSize;
            bt.target = self;
            bt.action = @selector(classicColoringFilterClicked:);
            return bt;
        }
    }
    if( tableView == self.modernColoringRulesTable ) {
        assert(row < m_ModernColoringRules.size());
        auto &r = m_ModernColoringRules[row];
        if([tableColumn.identifier isEqualToString:@"name"]) {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
            tf.stringValue = [NSString stringWithUTF8StdString:r.name];
            tf.bordered = false;
            tf.editable = true;
            tf.drawsBackground = false;
            tf.delegate = self;
            return tf;
        }
        if([tableColumn.identifier isEqualToString:@"regular"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = r.regular;
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"focused"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = r.focused;
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"filter"]) {
            NSButton *bt = [[NSButton alloc] initWithFrame:NSRect()];
            bt.title = NSLocalizedStringFromTable(@"edit",
                                                  @"Preferences",
                                                  "Coloring rules edit button title");
            bt.buttonType = NSMomentaryPushInButton;
            bt.bezelStyle = NSRoundedBezelStyle;
            ((NSButtonCell*)bt.cell).controlSize = NSMiniControlSize;
            bt.target = self;
            bt.action = @selector(modernColoringFilterClicked:);
            return bt;
        }
    }
    if( tableView == self.layoutsTable ) {
        if( [tableColumn.identifier isEqualToString:@"name"] ) {
            if( auto l = m_LayoutsStorage->GetLayout((int)row) ) {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
                tf.stringValue = l->name.empty() ?
                [NSString stringWithFormat:@"Layout #%ld", row] :
                [NSString stringWithUTF8StdString:l->name];
                tf.bordered = false;
                tf.editable = false;
                tf.drawsBackground = false;
                return tf;
            }
        }
    }
    if( tableView == self.layoutsListColumnsTable ) {
        if( auto layout = self.selectedLayout ) {
            if( auto list = layout->list() ) {
                if( row < m_LayoutListColumns.size() ) {
                    auto &col = m_LayoutListColumns[row];
                    
                    if( [tableColumn.identifier isEqualToString:@"enabled"]  ) {
                        NSButton *cb = [[NSButton alloc] initWithFrame:NSRect()];
                        cb.enabled = row != 0;
                        cb.buttonType = NSButtonTypeSwitch;
                        cb.state = col.second;
                        cb.target = self;
                        cb.action = @selector(onLayoutListColumnEnabledClicked:);
                        return cb;
                    }
                    if( [tableColumn.identifier isEqualToString:@"title"]  ) {
                        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                        tf.stringValue = PanelListColumnTypeToString(col.first.kind);
                        tf.bordered = false;
                        tf.editable = false;
                        tf.drawsBackground = false;
                        return tf;
                    }
                }
            }
        }
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView
    didAddRowView:(NSTableRowView *)rowView
           forRow:(NSInteger)row
{
    if(tableView == self.classicColoringRulesTable ||
       tableView == self.modernColoringRulesTable )
        for(int i = 1; i <= 2; ++i) {
            NSView *v = [rowView viewAtColumn:i];
            NSRect rc = v.frame;
            rc.size.width = 36;
            rc.origin.x += (v.frame.size.width - rc.size.width) / 2.;
            v.frame = rc;
        }
}

- (void)tableView:(NSTableView *)tableView
 didRemoveRowView:(NSTableRowView *)rowView
           forRow:(NSInteger)row
{
    if(tableView == self.classicColoringRulesTable ||
       tableView == self.modernColoringRulesTable ) {
        [[rowView viewAtColumn:1] removeObserver:self forKeyPath:@"color"];
        [[rowView viewAtColumn:2] removeObserver:self forKeyPath:@"color"];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;
    if( auto rv = objc_cast<NSTableRowView>(tf.superview) ) {
        if( rv.superview == self.classicColoringRulesTable ) {
            long row_no = [self.classicColoringRulesTable rowForView:rv];
            if( row_no >= 0 ) {
                m_ClassicColoringRules[row_no].name = tf.stringValue ? tf.stringValue.UTF8String : "";
                [self writeClassicFiltering];                
            }
        }
        else if( rv.superview == self.modernColoringRulesTable ) {
            long row_no = [self.modernColoringRulesTable rowForView:rv];
            if( row_no >= 0 ) {
                m_ModernColoringRules[row_no].name = tf.stringValue ? tf.stringValue.UTF8String : "";
                [self writeModernFiltering];
            }
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( [keyPath isEqualToString:@"color"] )
        if( NSColorWell *cw = objc_cast<NSColorWell>(object) ) {
            if( auto rv = objc_cast<NSTableRowView>(cw.superview) ) {
                if( rv.superview == self.classicColoringRulesTable ) {
                    long row_no = [self.classicColoringRulesTable rowForView:rv];
                    if( row_no >= 0 ) {
                        if( cw == [rv viewAtColumn:1] )
                            m_ClassicColoringRules.at(row_no).regular = cw.color;
                        if( cw == [rv viewAtColumn:2] )
                            m_ClassicColoringRules.at(row_no).focused = cw.color;
                        [self writeClassicFiltering];
                    }
                }
                else if( rv.superview == self.modernColoringRulesTable ) {
                    long row_no = [self.modernColoringRulesTable rowForView:rv];
                    if( row_no >= 0 ) {
                        if( cw == [rv viewAtColumn:1] )
                            m_ModernColoringRules.at(row_no).regular = cw.color;
                        if( cw == [rv viewAtColumn:2] )
                            m_ModernColoringRules.at(row_no).focused = cw.color;
                        [self writeModernFiltering];
                    }
                }
            }
        }
}

- (void) writeModernFiltering
{
    GenericConfig::ConfigValue cr(rapidjson::kArrayType);
    cr.Reserve((unsigned)m_ModernColoringRules.size(), GenericConfig::g_CrtAllocator);
    for(const auto &r: m_ModernColoringRules)
        cr.PushBack( r.ToJSON(), GenericConfig::g_CrtAllocator );
    GlobalConfig().Set(g_ConfigModernColoring, cr);
}

- (void) writeClassicFiltering
{
    GenericConfig::ConfigValue cr(rapidjson::kArrayType);
    cr.Reserve((unsigned)m_ClassicColoringRules.size(), GenericConfig::g_CrtAllocator);
    for(const auto &r: m_ClassicColoringRules)
        cr.PushBack( r.ToJSON(), GenericConfig::g_CrtAllocator );
    GlobalConfig().Set(g_ConfigClassicColoring, cr);
}

- (void) classicColoringFilterClicked:(id)sender
{
    if( auto button = objc_cast<NSButton>(sender) )
        if( auto rv = objc_cast<NSTableRowView>(button.superview) ) {
            long row_no = [((NSTableView*)rv.superview) rowForView:rv];
            auto sheet = [[PreferencesWindowPanelsTabColoringFilterSheet alloc] initWithFilter:m_ClassicColoringRules.at(row_no).filter];
            [sheet beginSheetForWindow:self.view.window
                     completionHandler:^(NSModalResponse returnCode) {
                         if( returnCode != NSModalResponseOK )
                             return;
                         m_ClassicColoringRules.at(row_no).filter = sheet.filter;
                         [self writeClassicFiltering];
                     }];
        }
}

- (void) modernColoringFilterClicked:(id)sender
{
    if( auto button = objc_cast<NSButton>(sender) )
        if( auto rv = objc_cast<NSTableRowView>(button.superview) ) {
            long row_no = [((NSTableView*)rv.superview) rowForView:rv];
            auto sheet = [[PreferencesWindowPanelsTabColoringFilterSheet alloc] initWithFilter:m_ModernColoringRules.at(row_no).filter];
            [sheet beginSheetForWindow:self.view.window
                     completionHandler:^(NSModalResponse returnCode) {
                         if( returnCode != NSModalResponseOK )
                             return;
                         m_ModernColoringRules.at(row_no).filter = sheet.filter;
                         [self writeModernFiltering];
                     }];
        }
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if(aTableView == self.classicColoringRulesTable ||
       aTableView == self.modernColoringRulesTable ||
       aTableView == self.layoutsListColumnsTable )
        return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    if(aTableView == self.classicColoringRulesTable) {
        [pboard declareTypes:@[MyPrivateTableViewDataTypeClassic] owner:self];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:MyPrivateTableViewDataTypeClassic];
        return true;
    }
    if(aTableView == self.modernColoringRulesTable) {
        [pboard declareTypes:@[MyPrivateTableViewDataTypeModern] owner:self];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:MyPrivateTableViewDataTypeModern];
        return true;
    }
    if( aTableView == self.layoutsListColumnsTable ) {
        if( rowIndexes.firstIndex == 0 )
            return false;
        [pboard declareTypes:@[g_LayoutColumnsDDType] owner:self];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:g_LayoutColumnsDDType];
        return true;
    }
    return false;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)operation
{
    if(aTableView == self.classicColoringRulesTable) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:MyPrivateTableViewDataTypeClassic]];
        NSInteger drag_from = inds.firstIndex;
    
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1) // same index, below
            return false;
        
        assert(drag_from < m_ClassicColoringRules.size());
        
        auto i = begin(m_ClassicColoringRules);
        if( drag_from < drag_to )
            rotate( i + drag_from, i + drag_from + 1, i + drag_to );
        else
            rotate( i + drag_to, i + drag_from, i + drag_from + 1 );
        [self.classicColoringRulesTable reloadData];
        [self writeClassicFiltering];
        return true;
    }
    else if(aTableView == self.modernColoringRulesTable) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:MyPrivateTableViewDataTypeModern]];
        NSInteger drag_from = inds.firstIndex;
        
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1) // same index, below
            return false;
        
        assert(drag_from < m_ModernColoringRules.size());

        auto i = begin(m_ModernColoringRules);
        if( drag_from < drag_to )
            rotate( i + drag_from, i + drag_from + 1, i + drag_to );
        else
            rotate( i + drag_to, i + drag_from, i + drag_from + 1 );
        [self.modernColoringRulesTable reloadData];
        [self writeModernFiltering];
        return true;
    }
    else if( aTableView == self.layoutsListColumnsTable ) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:g_LayoutColumnsDDType]];
        NSInteger drag_from = inds.firstIndex;
        
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1 || // same index, below
           drag_to == 0 ) // first item should be filename
            return false;
        
        assert( drag_from < m_LayoutListColumns.size() );
        auto i = begin(m_LayoutListColumns);
        if( drag_from < drag_to )
            rotate( i + drag_from, i + drag_from + 1, i + drag_to );
        else
            rotate( i + drag_to, i + drag_from, i + drag_from + 1 );
        [self.layoutsListColumnsTable reloadData];
        [self commitLayoutChanges];
        return true;
    }
    return false;
}

- (IBAction)OnAddNewClassicColoringRule:(id)sender
{
    m_ClassicColoringRules.emplace_back();
    [self.classicColoringRulesTable reloadData];
    [self writeClassicFiltering];
}

- (IBAction)OnRemoveClassicColoringRule:(id)sender
{
    NSIndexSet *indeces = self.classicColoringRulesTable.selectedRowIndexes;
    if(indeces.count == 1) {
        m_ClassicColoringRules.erase( begin(m_ClassicColoringRules) + indeces.firstIndex );
        [self.classicColoringRulesTable reloadData];
        [self writeClassicFiltering];
    }
}

- (IBAction)OnAddNewModernColoringRule:(id)sender
{
    m_ModernColoringRules.emplace_back();
    [self.modernColoringRulesTable reloadData];
    [self writeModernFiltering];
}

- (IBAction)OnRemoveModernColoringRule:(id)sender
{
    NSIndexSet *indeces = self.modernColoringRulesTable.selectedRowIndexes;
    if( indeces.count == 1 ) {
        m_ModernColoringRules.erase( begin(m_ModernColoringRules) + indeces.firstIndex );
        [self.modernColoringRulesTable reloadData];
        [self writeModernFiltering];
    }
}


- (shared_ptr<const PanelViewLayout>) selectedLayout
{
    NSInteger row = self.layoutsTable.selectedRow;
//    return row < m_Tools.size() ? m_Tools[row] : nullptr;
    return m_LayoutsStorage->GetLayout((int)row);
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if( notification.object == self.layoutsTable  ) {
        const auto row = (int)self.layoutsTable.selectedRow;
        self.anyLayoutSelected = row >= 0;
        if( row >= 0 )
            [self fillLayoutFields];
        else
            [self clearLayoutFields];
    }
    
//    NSInteger row = self.toolsTable.selectedRow;
}

- (IBAction)onLayoutTypeChanged:(id)sender
{
    if( auto l = self.selectedLayout ) {
        auto new_layout = *l;
        new_layout.name = self.layoutTitle.stringValue.UTF8String;
        
        if( self.layoutType.selectedTag == (int)PanelViewLayout::Type::Brief ) {
            PanelBriefViewColumnsLayout l1;
            l1.mode = PanelBriefViewColumnsLayout::Mode::DynamicWidth;
            l1.dynamic_width_min = 140;
            l1.dynamic_width_max = 250;
            l1.dynamic_width_equal = false;
            new_layout.layout = l1;
        }
        if( self.layoutType.selectedTag == (int)PanelViewLayout::Type::List ) {
            PanelListViewColumnsLayout l1;
            PanelListViewColumnsLayout::Column col;
            col.kind = PanelListViewColumns::Filename;
            l1.columns.emplace_back(col);
            new_layout.layout = l1;
        }
        if( self.layoutType.selectedTag == (int)PanelViewLayout::Type::Disabled )
            new_layout.layout = PanelViewDisabledLayout{};

        if( new_layout != *l ) {
            const auto row = (int)self.layoutsTable.selectedRow;
            m_LayoutsStorage->ReplaceLayout( move(new_layout), row );
            [self fillLayoutFields];
        }
    }
}

static NSString *LayoutTypeToTabIdentifier( PanelViewLayout::Type _t )
{
    switch( _t ) {
        case PanelViewLayout::Type::Brief:  return @"Brief";
        case PanelViewLayout::Type::List:   return @"List";
        default: return @"Disabled";
    }
}


- (void) fillLayoutFields
{
    const auto l = self.selectedLayout;
    assert(l);
    self.layoutTitle.stringValue = [NSString stringWithUTF8StdString:l->name];
    const auto t = l->type();
    [self.layoutType selectItemWithTag:(int)t];
    [self.layoutDetailsTabView selectTabViewItemWithIdentifier:
     LayoutTypeToTabIdentifier(t)];

    if( auto brief = l->brief() ) {
        self.layoutsBriefFixedRadioChoosen =
            brief->mode == PanelBriefViewColumnsLayout::Mode::FixedWidth;
        self.layoutsBriefAmountRadioChoosen =
            brief->mode == PanelBriefViewColumnsLayout::Mode::FixedAmount;
        self.layoutsBriefDynamicRadioChoosen =
            brief->mode == PanelBriefViewColumnsLayout::Mode::DynamicWidth;
        self.layoutsBriefFixedValueTextField.intValue = brief->fixed_mode_width;
        self.layoutsBriefAmountValueTextField.intValue = brief->fixed_amount_value;
        self.layoutsBriefDynamicMinValueTextField.intValue = brief->dynamic_width_min;
        self.layoutsBriefDynamicMaxValueTextField.intValue = brief->dynamic_width_max;
        self.layoutsBriefDynamicEqualCheckbox.state = brief->dynamic_width_equal;
        self.layoutsBriefIcon0x.state = brief->icon_scale == 0;
        self.layoutsBriefIcon1x.state = brief->icon_scale == 1;
        self.layoutsBriefIcon2x.state = brief->icon_scale == 2;
    }
    
    if( auto list = l->list() ) {
        static const auto columns_order = {
            PanelListViewColumns::Filename,
            PanelListViewColumns::Size,
            PanelListViewColumns::DateCreated,
            PanelListViewColumns::DateModified,
            PanelListViewColumns::DateAdded
        };
        m_LayoutListColumns.clear();
        for( auto c: list->columns )
            m_LayoutListColumns.emplace_back(c, true);
        for( auto c: columns_order )
            if( !any_of(begin(m_LayoutListColumns),
                        end(m_LayoutListColumns),
                        [=](auto v){ return v.first.kind == c; }) ) {
                PanelListViewColumnsLayout::Column dummy;
                dummy.kind = c;
                
                m_LayoutListColumns.emplace_back(dummy, false);
            }

        [self.layoutsListColumnsTable reloadData];
    }
    
//
    
//    self.toolPath.stringValue = [NSString stringWithUTF8StdString:t->m_ExecutablePath];
//    self.toolParameters.stringValue = [NSString stringWithUTF8StdString:t->m_Parameters];
//    [self.toolStartupMode selectItemWithTag:(int)t->m_StartupMode];
}

- (void) clearLayoutFields
{
    self.layoutTitle.stringValue = @"";
    [self.layoutType selectItemWithTag:(int)PanelViewLayout::Type::Disabled];
    [self.layoutDetailsTabView selectTabViewItemWithIdentifier:
     LayoutTypeToTabIdentifier(PanelViewLayout::Type::Disabled)];
//    self.toolPath.stringValue = @"";
//    self.toolParameters.stringValue = @"";
//    [self.toolStartupMode selectItemWithTag:(int)ExternalTool::StartupMode::Automatic];
}

- (IBAction)onLayoutBriefModeClicked:(id)sender
{
    self.layoutsBriefFixedRadioChoosen = sender == self.layoutsBriefFixedRadio;
    self.layoutsBriefAmountRadioChoosen = sender == self.layoutsBriefAmountRadio;
    self.layoutsBriefDynamicRadioChoosen = sender == self.layoutsBriefDynamicRadio;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutListColumnEnabledClicked:(id)sender
{
    int row = (int)[self.layoutsListColumnsTable rowForView:(NSView*)sender];
    if( row >= 0 && row < m_LayoutListColumns.size() ) {
        m_LayoutListColumns[row].second = ((NSButton*)sender).state == NSOnState;
        [self commitLayoutChanges];
    }
}

- (IBAction)onLayoutTitleChanged:(id)sender
{
    [self commitLayoutChanges];
    [self.layoutsTable reloadDataForRowIndexes:
     [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, m_LayoutsStorage->LayoutsCount())]
                                 columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (IBAction)onLayoutBriefIcon0xClicked:(id)sender
{
    self.layoutsBriefIcon0x.state = true;
    self.layoutsBriefIcon1x.state = false;
    self.layoutsBriefIcon2x.state = false;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutBriefIcon1xClicked:(id)sender
{
    self.layoutsBriefIcon0x.state = false;
    self.layoutsBriefIcon1x.state = true;
    self.layoutsBriefIcon2x.state = false;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutBriefIcon2xClicked:(id)sender
{
    self.layoutsBriefIcon0x.state = false;
    self.layoutsBriefIcon1x.state = false;
    self.layoutsBriefIcon2x.state = true;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutBriefParamChanged:(id)sender
{
    [self commitLayoutChanges];
}

- (void) commitLayoutChanges
{
    if( auto l = self.selectedLayout ) {
        auto new_layout = *l;
        new_layout.name = self.layoutTitle.stringValue.UTF8String;
        
        if( self.layoutType.selectedTag == (int)PanelViewLayout::Type::Brief )
            new_layout.layout = [self gatherBriefLayoutInfo];
        if( self.layoutType.selectedTag == (int)PanelViewLayout::Type::List )
            new_layout.layout = [self gatherListLayoutInfo];
        if( self.layoutType.selectedTag == (int)PanelViewLayout::Type::Disabled )
            new_layout.layout = PanelViewDisabledLayout{};
        
        if( new_layout != *l ) {
            const auto row = (int)self.layoutsTable.selectedRow;
            m_LayoutsStorage->ReplaceLayout( move(new_layout), row );
        }
    }
}

- (PanelListViewColumnsLayout) gatherListLayoutInfo
{
    PanelListViewColumnsLayout l;
    
    for( auto &c: m_LayoutListColumns )
        if( c.second ) {
            l.columns.emplace_back( c.first );
        }
    
    return l;
}

- (PanelBriefViewColumnsLayout) gatherBriefLayoutInfo
{
    PanelBriefViewColumnsLayout l;
    
    if( self.layoutsBriefFixedRadioChoosen )
        l.mode = PanelBriefViewColumnsLayout::Mode::FixedWidth;
    if( self.layoutsBriefAmountRadioChoosen )
        l.mode = PanelBriefViewColumnsLayout::Mode::FixedAmount;
    if( self.layoutsBriefDynamicRadioChoosen )
        l.mode = PanelBriefViewColumnsLayout::Mode::DynamicWidth;

    l.fixed_mode_width =  self.layoutsBriefFixedValueTextField.intValue;
    if( l.fixed_mode_width < 40 )
        l.fixed_mode_width = 40;
    l.fixed_amount_value = self.layoutsBriefAmountValueTextField.intValue;
    if( l.fixed_amount_value < 1 )
        l.fixed_amount_value = 1;
    l.dynamic_width_min = self.layoutsBriefDynamicMinValueTextField.intValue;
    if( l.dynamic_width_min < 40 )
        l.dynamic_width_min = 40;
    l.dynamic_width_max = self.layoutsBriefDynamicMaxValueTextField.intValue;
    if( l.dynamic_width_max < 40 )
        l.dynamic_width_max = 40;
    if( l.dynamic_width_max < l.dynamic_width_min )
        l.dynamic_width_max = l.dynamic_width_min;
    l.dynamic_width_equal = self.layoutsBriefDynamicEqualCheckbox.state;
    l.icon_scale = [&]{
        if( self.layoutsBriefIcon2x.state ) return 2;
        if( self.layoutsBriefIcon1x.state ) return 1;
        return 0;
    }();

    return l;
}

@end
