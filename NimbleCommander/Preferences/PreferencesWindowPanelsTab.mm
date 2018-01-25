// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include "PreferencesWindowPanelsTab.h"
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/States/FilePanels/PanelViewLayoutSupport.h>
#include "PreferencesWindowPanelsTabColoringFilterSheet.h"
#include <Utility/ByteCountFormatter.h>

using namespace nc::panel;

static const auto g_LayoutColumnsDDType = @"PreferencesWindowPanelsTabPrivateTableViewDataColumns";

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

@property (nonatomic) IBOutlet NSTabView *tabParts;
@property (nonatomic) IBOutlet NSPopUpButton *fileSizeFormatCombo;
@property (nonatomic) IBOutlet NSPopUpButton *selectionSizeFormatCombo;

// layout bindings
@property (nonatomic) IBOutlet NSTableView *layoutsTable;
@property (nonatomic)          bool         anyLayoutSelected;
@property (nonatomic) IBOutlet NSTextField *layoutTitle;
@property (nonatomic) IBOutlet NSPopUpButton*layoutType;
@property (nonatomic) IBOutlet NSTabView  *layoutDetailsTabView;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefFixedRadio;
@property (nonatomic)          bool        layoutsBriefFixedRadioChoosen;
@property (nonatomic) IBOutlet NSTextField*layoutsBriefFixedValueTextField;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefAmountRadio;
@property (nonatomic)          bool        layoutsBriefAmountRadioChoosen;
@property (nonatomic) IBOutlet NSTextField*layoutsBriefAmountValueTextField;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefDynamicRadio;
@property (nonatomic)          bool        layoutsBriefDynamicRadioChoosen;
@property (nonatomic) IBOutlet NSTextField*layoutsBriefDynamicMinValueTextField;
@property (nonatomic) IBOutlet NSTextField*layoutsBriefDynamicMaxValueTextField;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefDynamicEqualCheckbox;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefIcon0x;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefIcon1x;
@property (nonatomic) IBOutlet NSButton   *layoutsBriefIcon2x;
@property (nonatomic) IBOutlet NSTableView*layoutsListColumnsTable;
@property (nonatomic) IBOutlet NSButton   *layoutsListIcon0x;
@property (nonatomic) IBOutlet NSButton   *layoutsListIcon1x;
@property (nonatomic) IBOutlet NSButton   *layoutsListIcon2x;


@end

@implementation PreferencesWindowPanelsTab
{
    shared_ptr<PanelViewLayoutsStorage> m_LayoutsStorage;
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
        m_LayoutsStorage = NCAppDelegate.me.panelLayouts;
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    [self.layoutsListColumnsTable registerForDraggedTypes:@[g_LayoutColumnsDDType]];
    
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

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( tableView == self.layoutsTable )
        return m_LayoutsStorage->LayoutsCount();
    if( tableView == self.layoutsListColumnsTable )
        return m_LayoutListColumns.size();
    return 0;
}

static NSString* PanelListColumnTypeToString( PanelListViewColumns _c )
{
    switch( _c ) {
        case PanelListViewColumns::Filename:    return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_NAME", "");
        case PanelListViewColumns::Size:        return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_SIZE", "");
        case PanelListViewColumns::DateCreated: return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_CREATED", "");
        case PanelListViewColumns::DateAdded:   return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_ADDED", "");
        case PanelListViewColumns::DateModified:return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_MODIFIED", "");
        default:                                return @"";
    }
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
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
                if( row < (int)m_LayoutListColumns.size() ) {
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

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if( aTableView == self.layoutsListColumnsTable )
        return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
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
    if( aTableView == self.layoutsListColumnsTable ) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:g_LayoutColumnsDDType]];
        NSInteger drag_from = inds.firstIndex;
        
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1 || // same index, below
           drag_to == 0 ) // first item should be filename
            return false;
        
        assert( drag_from < (int)m_LayoutListColumns.size() );
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

- (shared_ptr<const PanelViewLayout>) selectedLayout
{
    const auto row = self.layoutsTable.selectedRow;
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
            m_LayoutsStorage->ReplaceLayoutWithMandatoryNotification( move(new_layout), row );
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
        self.layoutsListIcon0x.state = list->icon_scale == 0;
        self.layoutsListIcon1x.state = list->icon_scale == 1;
        self.layoutsListIcon2x.state = list->icon_scale == 2;
        
    }
}

- (void) clearLayoutFields
{
    self.layoutTitle.stringValue = @"";
    [self.layoutType selectItemWithTag:(int)PanelViewLayout::Type::Disabled];
    [self.layoutDetailsTabView selectTabViewItemWithIdentifier:
     LayoutTypeToTabIdentifier(PanelViewLayout::Type::Disabled)];
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
    if( row >= 0 && row < (int)m_LayoutListColumns.size() ) {
        m_LayoutListColumns[row].second = ((NSButton*)sender).state == NSOnState;
        [self commitLayoutChanges];
    }
}

- (IBAction)onLayoutListIconScaleClicked:(id)sender
{
    self.layoutsListIcon0x.state = sender == self.layoutsListIcon0x;
    self.layoutsListIcon1x.state = sender == self.layoutsListIcon1x;
    self.layoutsListIcon2x.state = sender == self.layoutsListIcon2x;
    [self commitLayoutChanges];
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
            m_LayoutsStorage->ReplaceLayoutWithMandatoryNotification( move(new_layout), row );
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
    l.icon_scale = [&]() -> uint8_t {
        if( self.layoutsListIcon2x.state ) return 2;
        if( self.layoutsListIcon1x.state ) return 1;
        return 0;
    }();
    
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

    l.fixed_mode_width =  (short)self.layoutsBriefFixedValueTextField.intValue;
    if( l.fixed_mode_width < 40 )
        l.fixed_mode_width = 40;
    l.fixed_amount_value = (short)self.layoutsBriefAmountValueTextField.intValue;
    if( l.fixed_amount_value < 1 )
        l.fixed_amount_value = 1;
    l.dynamic_width_min = (short)self.layoutsBriefDynamicMinValueTextField.intValue;
    if( l.dynamic_width_min < 40 )
        l.dynamic_width_min = 40;
    l.dynamic_width_max = (short)self.layoutsBriefDynamicMaxValueTextField.intValue;
    if( l.dynamic_width_max < 40 )
        l.dynamic_width_max = 40;
    if( l.dynamic_width_max < l.dynamic_width_min )
        l.dynamic_width_max = l.dynamic_width_min;
    l.dynamic_width_equal = self.layoutsBriefDynamicEqualCheckbox.state;
    l.icon_scale = [&]() -> uint8_t {
        if( self.layoutsBriefIcon2x.state ) return 2;
        if( self.layoutsBriefIcon1x.state ) return 1;
        return 0;
    }();

    return l;
}

- (IBAction)onHeaderClicked:(id)sender
{
    NSInteger index = [sender selectedSegment];
    [self.tabParts selectTabViewItemAtIndex:index];
}

@end
