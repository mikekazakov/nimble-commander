// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowPanelsTab.h"
#include "ConfigBinder.h"
#include "PreferencesWindowPanelsTabOperationsConcurrencySheet.h"
#include <Base/dispatch_cpp.h>
#include <Config/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/States/FilePanels/PanelViewLayoutSupport.h>
#include <Panel/TagsStorage.h>
#include <Panel/UI/TagsPresentation.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/FontExtras.h>
#include <Utility/HexadecimalColor.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <algorithm>
#include <fmt/format.h>
#include <fmt/ranges.h>
#include <ranges>

using namespace nc::panel;

static const auto g_LayoutColumnsDDType =
    @"com.magnumbytes.nc.pref.PreferencesWindowPanelsTabPrivateTableViewDataColumns";
static const auto g_TagsDDType = @"com.magnumbytes.nc.pref.PreferencesWindowPanelsTabPrivateTableViewTagRows";

@interface PreferencesToNumberValueTransformer : NSValueTransformer
@end

@implementation PreferencesToNumberValueTransformer
+ (Class)transformedValueClass
{
    return [NSNumber class];
}
- (id)transformedValue:(id)value
{
    if( auto n = nc::objc_cast<NSNumber>(value) )
        return n;
    else if( auto s = nc::objc_cast<NSString>(value) )
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

+ (Class)transformedValueClass
{
    return [NSColor class];
}

- (id)transformedValue:(id)value
{
    if( auto s = nc::objc_cast<NSString>(value) )
        return [NSColor colorWithHexString:s.UTF8String];
    return nil;
}

- (id)reverseTransformedValue:(id)value
{
    if( auto c = nc::objc_cast<NSColor>(value) )
        return [c toHexString];
    return nil;
}

@end

@interface NCPreferencesToNonNilStringValueTransformer : NSValueTransformer
@end
@implementation NCPreferencesToNonNilStringValueTransformer
+ (Class)transformedValueClass
{
    return [NSString class];
}
- (id)transformedValue:(id)value
{
    if( auto s = nc::objc_cast<NSString>(value) )
        return s;
    return @"";
}
@end

@interface PreferencesWindowPanelsTabFlippedStackView : NSStackView
@end
@implementation PreferencesWindowPanelsTabFlippedStackView
- (BOOL)isFlipped
{
    return YES;
}
@end

@interface PreferencesWindowPanelsTab ()

@property(nonatomic) IBOutlet NSTabView *tabParts;
@property(nonatomic) IBOutlet NSPopUpButton *fileSizeFormatCombo;
@property(nonatomic) IBOutlet NSPopUpButton *selectionSizeFormatCombo;

// layout bindings
@property(nonatomic) IBOutlet NSTableView *layoutsTable;
@property(nonatomic) bool anyLayoutSelected;
@property(nonatomic) IBOutlet NSTextField *layoutTitle;
@property(nonatomic) IBOutlet NSPopUpButton *layoutType;
@property(nonatomic) IBOutlet NSTabView *layoutDetailsTabView;
@property(nonatomic) IBOutlet NSButton *layoutsBriefFixedRadio;
@property(nonatomic) bool layoutsBriefFixedRadioChoosen;
@property(nonatomic) IBOutlet NSTextField *layoutsBriefFixedValueTextField;
@property(nonatomic) IBOutlet NSButton *layoutsBriefAmountRadio;
@property(nonatomic) bool layoutsBriefAmountRadioChoosen;
@property(nonatomic) IBOutlet NSTextField *layoutsBriefAmountValueTextField;
@property(nonatomic) IBOutlet NSButton *layoutsBriefDynamicRadio;
@property(nonatomic) bool layoutsBriefDynamicRadioChoosen;
@property(nonatomic) IBOutlet NSTextField *layoutsBriefDynamicMinValueTextField;
@property(nonatomic) IBOutlet NSTextField *layoutsBriefDynamicMaxValueTextField;
@property(nonatomic) IBOutlet NSButton *layoutsBriefDynamicEqualCheckbox;
@property(nonatomic) IBOutlet NSButton *layoutsBriefIcon0x;
@property(nonatomic) IBOutlet NSButton *layoutsBriefIcon1x;
@property(nonatomic) IBOutlet NSButton *layoutsBriefIcon2x;
@property(nonatomic) IBOutlet NSTableView *layoutsListColumnsTable;
@property(nonatomic) IBOutlet NSButton *layoutsListIcon0x;
@property(nonatomic) IBOutlet NSButton *layoutsListIcon1x;
@property(nonatomic) IBOutlet NSButton *layoutsListIcon2x;

// tags bindings
@property(nonatomic) IBOutlet NSTableView *tagsTable;
@property(nonatomic) IBOutlet NSSegmentedControl *tagsPlusMinus;
@property(nonatomic) IBOutlet NSMenu *tagsAdditionalMenu;
@property(nonatomic) bool tagsAreEnabled; // mirrors "filePanel.FinderTags.enable" from config

@end

@implementation PreferencesWindowPanelsTab {
    std::shared_ptr<PanelViewLayoutsStorage> m_LayoutsStorage;
    std::vector<std::pair<PanelListViewColumnsLayout::Column, bool>> m_LayoutListColumns;
    TagsStorage *m_TagsStorage;
    std::vector<nc::utility::Tags::Tag> m_Tags;
    dispatch_queue m_TagOperationsQue;
    std::unique_ptr<nc::ConfigBinder> m_BinderTagsAreEnabled;
}
@synthesize tabParts;
@synthesize fileSizeFormatCombo;
@synthesize selectionSizeFormatCombo;
@synthesize layoutsTable;
@synthesize anyLayoutSelected;
@synthesize layoutTitle;
@synthesize layoutType;
@synthesize layoutDetailsTabView;
@synthesize layoutsBriefFixedRadio;
@synthesize layoutsBriefFixedRadioChoosen;
@synthesize layoutsBriefFixedValueTextField;
@synthesize layoutsBriefAmountRadio;
@synthesize layoutsBriefAmountRadioChoosen;
@synthesize layoutsBriefAmountValueTextField;
@synthesize layoutsBriefDynamicRadio;
@synthesize layoutsBriefDynamicRadioChoosen;
@synthesize layoutsBriefDynamicMinValueTextField;
@synthesize layoutsBriefDynamicMaxValueTextField;
@synthesize layoutsBriefDynamicEqualCheckbox;
@synthesize layoutsBriefIcon0x;
@synthesize layoutsBriefIcon1x;
@synthesize layoutsBriefIcon2x;
@synthesize layoutsListColumnsTable;
@synthesize layoutsListIcon0x;
@synthesize layoutsListIcon1x;
@synthesize layoutsListIcon2x;
@synthesize tagsTable;
@synthesize tagsPlusMinus;
@synthesize tagsAdditionalMenu;
@synthesize tagsAreEnabled;

- (id)initWithNibName:(NSString *) [[maybe_unused]] nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    static std::once_flag once;
    std::call_once(once, [] {
        NSImage *const image =
            [[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/"
                                                    @"Resources/GenericApplicationIcon.icns"];
        if( image )
            [image setName:@"GenericApplicationIcon"];
    });

    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if( self ) {
        m_LayoutsStorage = NCAppDelegate.me.panelLayouts; // TODO: DI instead
        m_TagsStorage = &NCAppDelegate.me.tagsStorage;    // TODO: DI instead
        m_Tags = m_TagsStorage->Get();
        m_BinderTagsAreEnabled = std::make_unique<nc::ConfigBinder>(
            NCAppDelegate.me.globalConfig, "filePanel.FinderTags.enable", self, @"tagsAreEnabled");
    }

    return self;
}

- (void)loadView
{
    [super loadView];
    [self.layoutsListColumnsTable registerForDraggedTypes:@[g_LayoutColumnsDDType]];
    [self.tagsTable registerForDraggedTypes:@[g_TagsDDType]];

    uint64_t magic_size = 2597065;
    for( NSMenuItem *it in self.fileSizeFormatCombo.itemArray )
        it.title = ByteCountFormatter::Instance().ToNSString(magic_size, static_cast<ByteCountFormatter::Type>(it.tag));
    for( NSMenuItem *it in self.selectionSizeFormatCombo.itemArray )
        it.title = ByteCountFormatter::Instance().ToNSString(magic_size, static_cast<ByteCountFormatter::Type>(it.tag));

    [self.view layoutSubtreeIfNeeded];
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"preferences.toolbar.panels"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Panels", @"Preferences", "General preferences tab title");
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)_table
{
    if( _table == self.layoutsTable )
        return m_LayoutsStorage->LayoutsCount();
    if( _table == self.layoutsListColumnsTable )
        return m_LayoutListColumns.size();
    if( _table == self.tagsTable )
        return m_Tags.size();
    return 0;
}

static NSString *PanelListColumnTypeToString(PanelListViewColumns _c)
{
    switch( _c ) {
        case PanelListViewColumns::Filename:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_NAME", "");
        case PanelListViewColumns::Extension:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_EXTENSION", "");
        case PanelListViewColumns::Size:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_SIZE", "");
        case PanelListViewColumns::DateCreated:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_CREATED", "");
        case PanelListViewColumns::DateAdded:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_ADDED", "");
        case PanelListViewColumns::DateModified:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_MODIFIED", "");
        case PanelListViewColumns::DateAccessed:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_ACCESSED", "");
        case PanelListViewColumns::Tags:
            return NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_TAGS", "");
        default:
            return @"";
    }
}

static NSMenu *BuildTagColorMenu()
{
    using Color = nc::utility::Tags::Color;
    [[clang::no_destroy]] static const std::pair<Color, NSString *> items[] = {
        {Color::None, NSLocalizedString(@"No Colour", "")},
        {Color::Red, NSLocalizedString(@"Red", "")},
        {Color::Orange, NSLocalizedString(@"Orange", "")},
        {Color::Yellow, NSLocalizedString(@"Yellow", "")},
        {Color::Green, NSLocalizedString(@"Green", "")},
        {Color::Blue, NSLocalizedString(@"Blue", "")},
        {Color::Purple, NSLocalizedString(@"Purple", "")},
        {Color::Gray, NSLocalizedString(@"Gray", "")}};
    NSMenu *const menu = [[NSMenu alloc] init];
    for( auto &item : items ) {
        NSMenuItem *const it = [[NSMenuItem alloc] initWithTitle:item.second action:nil keyEquivalent:@""];
        it.image = TagsMenuDisplay::Images().at(std::to_underlying(item.first));
        it.tag = std::to_underlying(item.first);
        [menu addItem:it];
    }
    assert(menu.numberOfItems == 8);
    return menu;
}

- (NSView *)tableView:(NSTableView *)_table viewForTableColumn:(NSTableColumn *)_column row:(NSInteger)_row
{
    if( _table == self.layoutsTable ) {
        if( [_column.identifier isEqualToString:@"name"] ) {
            if( auto l = m_LayoutsStorage->GetLayout(static_cast<int>(_row)) ) {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
                tf.stringValue = l->name.empty() ? [NSString stringWithFormat:@"Layout #%ld", _row]
                                                 : [NSString stringWithUTF8StdString:l->name];
                tf.bordered = false;
                tf.editable = false;
                tf.drawsBackground = false;
                return tf;
            }
        }
    }
    if( _table == self.layoutsListColumnsTable ) {
        if( auto layout = self.selectedLayout ) {
            if( layout->list() ) {
                if( _row < static_cast<int>(m_LayoutListColumns.size()) ) {
                    auto &col = m_LayoutListColumns[_row];
                    if( [_column.identifier isEqualToString:@"enabled"] ) {
                        NSButton *cb = [[NSButton alloc] initWithFrame:NSRect()];
                        cb.enabled = _row != 0;
                        cb.buttonType = NSButtonTypeSwitch;
                        cb.state = col.second;
                        cb.target = self;
                        cb.action = @selector(onLayoutListColumnEnabledClicked:);
                        return cb;
                    }
                    if( [_column.identifier isEqualToString:@"title"] ) {
                        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                        tf.stringValue = PanelListColumnTypeToString(col.first.kind);
                        tf.bordered = false;
                        tf.editable = false;
                        tf.drawsBackground = false;
                        tf.translatesAutoresizingMaskIntoConstraints = false;
                        NSTableCellView *cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
                        [cv addSubview:tf];
                        [cv addConstraints:[NSLayoutConstraint
                                               constraintsWithVisualFormat:@"H:|-(4)-[tf]-(4)-|"
                                                                   options:0
                                                                   metrics:nil
                                                                     views:NSDictionaryOfVariableBindings(tf)]];
                        [cv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                                       attribute:NSLayoutAttributeCenterY
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:cv
                                                                       attribute:NSLayoutAttributeCenterY
                                                                      multiplier:1.
                                                                        constant:0.]];
                        return cv;
                    }
                }
            }
        }
    }
    if( _table == self.tagsTable && _row < static_cast<long>(m_Tags.size()) ) {
        auto tag = m_Tags[_row];
        if( [_column.identifier isEqualToString:@"color"] ) {
            NSPopUpButton *but = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 15) pullsDown:false];
            but.imagePosition = NSImageOnly;
            but.bordered = false;
            but.menu = BuildTagColorMenu();
            [but selectItemWithTag:std::to_underlying(tag.Color())];
            but.target = self;
            but.action = @selector(onTagsTableColorChanged:);
            [but bind:@"enabled" toObject:self withKeyPath:@"tagsAreEnabled" options:nil];
            return but;
        }
        if( [_column.identifier isEqualToString:@"label"] ) {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
            tf.stringValue = [NSString stringWithUTF8StdString:tag.Label()];
            tf.bordered = false;
            tf.editable = true;
            tf.drawsBackground = false;
            tf.usesSingleLineMode = true;
            tf.translatesAutoresizingMaskIntoConstraints = false;
            tf.delegate = self;
            [tf bind:@"enabled" toObject:self withKeyPath:@"tagsAreEnabled" options:nil];
            NSTableCellView *cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
            [cv addSubview:tf];
            cv.textField = tf;
            [cv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(4)-[tf(>=40)]-(4)-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(tf)]];
            [cv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                           attribute:NSLayoutAttributeCenterY
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:cv
                                                           attribute:NSLayoutAttributeCenterY
                                                          multiplier:1.
                                                            constant:0.]];
            return cv;
        }
    }
    return nil;
}

- (NSDragOperation)tableView:(NSTableView *)_table_view
                validateDrop:(id<NSDraggingInfo>)_info
                 proposedRow:(NSInteger) [[maybe_unused]] _row
       proposedDropOperation:(NSTableViewDropOperation)_operation
{
    if( _table_view == self.layoutsListColumnsTable ) {
        return _operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
    }
    if( _table_view == self.tagsTable ) {
        return _operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (nullable id<NSPasteboardWriting>)tableView:(NSTableView *)_table_view pasteboardWriterForRow:(NSInteger)_row
{
    auto pb_item_with_type = [&](NSString *_type) -> NSPasteboardItem * {
        auto data = [NSKeyedArchiver archivedDataWithRootObject:[NSNumber numberWithInteger:_row]
                                          requiringSecureCoding:false
                                                          error:nil];
        NSPasteboardItem *const pbitem = [[NSPasteboardItem alloc] init];
        [pbitem setData:data forType:_type];
        return pbitem;
    };

    if( _table_view == self.layoutsListColumnsTable ) {
        if( _row == 0 )
            return nil;
        return pb_item_with_type(g_LayoutColumnsDDType);
    }
    if( _table_view == self.tagsTable ) {
        return pb_item_with_type(g_TagsDDType);
    }
    return nil;
}

- (BOOL)tableView:(NSTableView *)_table_view
       acceptDrop:(id<NSDraggingInfo>)_info
              row:(NSInteger)_drag_to
    dropOperation:(NSTableViewDropOperation) [[maybe_unused]] operation
{
    if( _table_view == self.layoutsListColumnsTable ) {
        auto data = [_info.draggingPasteboard dataForType:g_LayoutColumnsDDType];
        NSNumber *ind = [NSKeyedUnarchiver unarchivedObjectOfClass:NSNumber.class fromData:data error:nil];
        const NSInteger drag_from = ind.integerValue;

        if( _drag_to == drag_from ||     // same index, above
            _drag_to == drag_from + 1 || // same index, below
            _drag_to == 0 )              // first item should be filename
            return false;

        assert(drag_from < static_cast<int>(m_LayoutListColumns.size()));
        auto i = m_LayoutListColumns.begin();
        if( drag_from < _drag_to )
            std::rotate(i + drag_from, i + drag_from + 1, i + _drag_to);
        else
            std::rotate(i + _drag_to, i + drag_from, i + drag_from + 1);
        [self.layoutsListColumnsTable reloadData];
        [self commitLayoutChanges];
        return true;
    }
    if( _table_view == self.tagsTable ) {
        auto data = [_info.draggingPasteboard dataForType:g_TagsDDType];
        NSNumber *ind = [NSKeyedUnarchiver unarchivedObjectOfClass:NSNumber.class fromData:data error:nil];
        const NSInteger drag_from = ind.integerValue;
        if( _drag_to == drag_from || _drag_to == drag_from + 1 )
            return false; // same index, above or below

        assert(drag_from < static_cast<int>(m_Tags.size()));
        auto i = m_Tags.begin();
        if( drag_from < _drag_to )
            std::rotate(i + drag_from, i + drag_from + 1, i + _drag_to);
        else
            std::rotate(i + _drag_to, i + drag_from, i + drag_from + 1);
        [self.tagsTable reloadData];
        m_TagsStorage->Set(m_Tags);
        return true;
    }
    return false;
}

- (std::shared_ptr<const PanelViewLayout>)selectedLayout
{
    const auto row = self.layoutsTable.selectedRow;
    return m_LayoutsStorage->GetLayout(static_cast<int>(row));
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if( notification.object == self.layoutsTable ) {
        const auto row = static_cast<int>(self.layoutsTable.selectedRow);
        self.anyLayoutSelected = row >= 0;
        if( row >= 0 )
            [self fillLayoutFields];
        else
            [self clearLayoutFields];
    }
}

- (IBAction)onLayoutTypeChanged:(id) [[maybe_unused]] sender
{
    if( auto l = self.selectedLayout ) {
        auto new_layout = *l;
        new_layout.name = self.layoutTitle.stringValue.UTF8String;

        if( self.layoutType.selectedTag == static_cast<int>(PanelViewLayout::Type::Brief) ) {
            PanelBriefViewColumnsLayout l1;
            l1.mode = PanelBriefViewColumnsLayout::Mode::DynamicWidth;
            l1.dynamic_width_min = 140;
            l1.dynamic_width_max = 250;
            l1.dynamic_width_equal = false;
            new_layout.layout = l1;
        }
        if( self.layoutType.selectedTag == static_cast<int>(PanelViewLayout::Type::List) ) {
            PanelListViewColumnsLayout l1;
            PanelListViewColumnsLayout::Column col;
            col.kind = PanelListViewColumns::Filename;
            l1.columns.emplace_back(col);
            new_layout.layout = l1;
        }
        if( self.layoutType.selectedTag == static_cast<int>(PanelViewLayout::Type::Disabled) )
            new_layout.layout = PanelViewDisabledLayout{};

        if( new_layout != *l ) {
            const auto row = static_cast<int>(self.layoutsTable.selectedRow);
            m_LayoutsStorage->ReplaceLayoutWithMandatoryNotification(std::move(new_layout), row);
            [self fillLayoutFields];
        }
    }
}

static NSString *LayoutTypeToTabIdentifier(PanelViewLayout::Type _t)
{
    switch( _t ) {
        case PanelViewLayout::Type::Brief:
            return @"Brief";
        case PanelViewLayout::Type::List:
            return @"List";
        default:
            return @"Disabled";
    }
}

- (void)fillLayoutFields
{
    const auto l = self.selectedLayout;
    assert(l);
    self.layoutTitle.stringValue = [NSString stringWithUTF8StdString:l->name];
    const auto t = l->type();
    [self.layoutType selectItemWithTag:static_cast<int>(t)];
    [self.layoutDetailsTabView selectTabViewItemWithIdentifier:LayoutTypeToTabIdentifier(t)];

    if( auto brief = l->brief() ) {
        self.layoutsBriefFixedRadioChoosen = brief->mode == PanelBriefViewColumnsLayout::Mode::FixedWidth;
        self.layoutsBriefAmountRadioChoosen = brief->mode == PanelBriefViewColumnsLayout::Mode::FixedAmount;
        self.layoutsBriefDynamicRadioChoosen = brief->mode == PanelBriefViewColumnsLayout::Mode::DynamicWidth;
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
        constexpr PanelListViewColumns columns_order[] = {PanelListViewColumns::Filename,
                                                          PanelListViewColumns::Extension,
                                                          PanelListViewColumns::Size,
                                                          PanelListViewColumns::DateCreated,
                                                          PanelListViewColumns::DateModified,
                                                          PanelListViewColumns::DateAdded,
                                                          PanelListViewColumns::DateAccessed,
                                                          PanelListViewColumns::Tags};
        m_LayoutListColumns.clear();
        for( auto c : list->columns )
            m_LayoutListColumns.emplace_back(c, true);
        for( auto c : columns_order )
            if( std::ranges::none_of(m_LayoutListColumns, [=](auto v) { return v.first.kind == c; }) ) {
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

- (void)clearLayoutFields
{
    self.layoutTitle.stringValue = @"";
    [self.layoutType selectItemWithTag:static_cast<int>(PanelViewLayout::Type::Disabled)];
    [self.layoutDetailsTabView
        selectTabViewItemWithIdentifier:LayoutTypeToTabIdentifier(PanelViewLayout::Type::Disabled)];
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
    int row = static_cast<int>([self.layoutsListColumnsTable rowForView:static_cast<NSView *>(sender)]);
    if( row >= 0 && row < static_cast<int>(m_LayoutListColumns.size()) ) {
        m_LayoutListColumns[row].second = static_cast<NSButton *>(sender).state == NSControlStateValueOn;
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

- (IBAction)onLayoutTitleChanged:(id) [[maybe_unused]] sender
{
    [self commitLayoutChanges];
    [self.layoutsTable
        reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, m_LayoutsStorage->LayoutsCount())]
                  columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (IBAction)onLayoutBriefIcon0xClicked:(id) [[maybe_unused]] sender
{
    self.layoutsBriefIcon0x.state = true;
    self.layoutsBriefIcon1x.state = false;
    self.layoutsBriefIcon2x.state = false;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutBriefIcon1xClicked:(id) [[maybe_unused]] sender
{
    self.layoutsBriefIcon0x.state = false;
    self.layoutsBriefIcon1x.state = true;
    self.layoutsBriefIcon2x.state = false;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutBriefIcon2xClicked:(id) [[maybe_unused]] sender
{
    self.layoutsBriefIcon0x.state = false;
    self.layoutsBriefIcon1x.state = false;
    self.layoutsBriefIcon2x.state = true;
    [self commitLayoutChanges];
}

- (IBAction)onLayoutBriefParamChanged:(id) [[maybe_unused]] sender
{
    [self commitLayoutChanges];
}

- (void)commitLayoutChanges
{
    if( auto l = self.selectedLayout ) {
        auto new_layout = *l;
        new_layout.name = self.layoutTitle.stringValue.UTF8String;

        if( self.layoutType.selectedTag == static_cast<int>(PanelViewLayout::Type::Brief) )
            new_layout.layout = [self gatherBriefLayoutInfo];
        if( self.layoutType.selectedTag == static_cast<int>(PanelViewLayout::Type::List) )
            new_layout.layout = [self gatherListLayoutInfo];
        if( self.layoutType.selectedTag == static_cast<int>(PanelViewLayout::Type::Disabled) )
            new_layout.layout = PanelViewDisabledLayout{};

        if( new_layout != *l ) {
            const auto row = static_cast<int>(self.layoutsTable.selectedRow);
            m_LayoutsStorage->ReplaceLayoutWithMandatoryNotification(std::move(new_layout), row);
        }
    }
}

- (PanelListViewColumnsLayout)gatherListLayoutInfo
{
    PanelListViewColumnsLayout l;

    for( auto &c : m_LayoutListColumns )
        if( c.second ) {
            l.columns.emplace_back(c.first);
        }
    l.icon_scale = [&]() -> uint8_t {
        if( self.layoutsListIcon2x.state )
            return 2;
        if( self.layoutsListIcon1x.state )
            return 1;
        return 0;
    }();

    return l;
}

- (PanelBriefViewColumnsLayout)gatherBriefLayoutInfo
{
    PanelBriefViewColumnsLayout l;

    if( self.layoutsBriefFixedRadioChoosen )
        l.mode = PanelBriefViewColumnsLayout::Mode::FixedWidth;
    if( self.layoutsBriefAmountRadioChoosen )
        l.mode = PanelBriefViewColumnsLayout::Mode::FixedAmount;
    if( self.layoutsBriefDynamicRadioChoosen )
        l.mode = PanelBriefViewColumnsLayout::Mode::DynamicWidth;

    l.fixed_mode_width = static_cast<short>(std::max(self.layoutsBriefFixedValueTextField.intValue, 40));
    l.fixed_amount_value = static_cast<short>(std::max(self.layoutsBriefAmountValueTextField.intValue, 1));
    l.dynamic_width_min = static_cast<short>(std::max(self.layoutsBriefDynamicMinValueTextField.intValue, 40));
    l.dynamic_width_max =
        std::max(static_cast<short>(self.layoutsBriefDynamicMaxValueTextField.intValue), l.dynamic_width_min);
    l.dynamic_width_equal = self.layoutsBriefDynamicEqualCheckbox.state;
    l.icon_scale = [&]() -> uint8_t {
        if( self.layoutsBriefIcon2x.state )
            return 2;
        if( self.layoutsBriefIcon1x.state )
            return 1;
        return 0;
    }();

    return l;
}

- (IBAction)onHeaderClicked:(id)sender
{
    NSInteger index = [sender selectedSegment];
    [self.tabParts selectTabViewItemAtIndex:index];
}

- (IBAction)onChooseOperationsConcurrency:(id)sender
{
    constexpr auto path = "filePanel.operations.concurrencyPerWindowDoesntApplyTo";
    const auto orig_list = NCAppDelegate.me.globalConfig.GetString(path);
    auto sheet =
        [[PreferencesWindowPanelsTabOperationsConcurrencySheet alloc] initWithConcurrencyExclusionList:orig_list];
    __weak PreferencesWindowPanelsTabOperationsConcurrencySheet *weak_sheet = sheet;
    [sheet beginSheetForWindow:self.view.window
             completionHandler:^([[maybe_unused]] NSModalResponse rc) {
               NCAppDelegate.me.globalConfig.Set(path, weak_sheet.exclusionList);
             }];
}

- (IBAction)onTagsTableColorChanged:(id)_sender
{
    NSPopUpButton *but = nc::objc_cast<NSPopUpButton>(_sender);
    if( !but )
        return;
    const long row = [self.tagsTable rowForView:but];
    if( row < 0 || static_cast<size_t>(row) >= m_Tags.size() )
        return;

    const long selected_color = std::clamp(but.selectedTag, 0l, 7l);
    const nc::utility::Tags::Tag old_tag = m_Tags[row];
    const nc::utility::Tags::Tag new_tag{&old_tag.Label(), static_cast<nc::utility::Tags::Color>(selected_color)};
    if( old_tag == new_tag )
        return;

    m_Tags[row] = new_tag;
    m_TagsStorage->Set(m_Tags);
    m_TagOperationsQue.async(
        [new_tag] { nc::utility::Tags::ChangeColorOfAllItemsWithTag(new_tag.Label(), new_tag.Color()); });
}

- (void)controlTextDidEndEditing:(NSNotification *)_notification
{
    NSTextField *tf = nc::objc_cast<NSTextField>(_notification.object);
    if( !tf || !tf.stringValue )
        return;

    if( const long row = [self.tagsTable rowForView:tf]; row >= 0 && static_cast<size_t>(row) < m_Tags.size() ) {
        const nc::utility::Tags::Tag old_tag = m_Tags[row];

        const NSString *value = tf.stringValue;
        if( value.length == 0 || value.length > 255 ) {
            tf.stringValue = [NSString stringWithUTF8StdString:old_tag.Label()];
            return; // silently ignore
        }

        const std::string new_label = value.UTF8String;
        if( old_tag.Label() == new_label )
            return; // nothing to do

        if( std::ranges::find_if(m_Tags, [&](auto &_tag) { return _tag.Label() == new_label; }) != m_Tags.end() ) {
            auto fmt = NSLocalizedString(@"The name “%@” is already taken.\nPlease choose a different name.",
                                         "Alert shown when a user tries to enter a tag label that is already in use");
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = [NSString localizedStringWithFormat:fmt, value];
            alert.alertStyle = NSAlertStyleCritical;
            [alert beginSheetModalForWindow:self.tagsTable.window
                          completionHandler:^(NSModalResponse){
                          }];
            tf.stringValue = [NSString stringWithUTF8StdString:old_tag.Label()];
            return;
        }

        const nc::utility::Tags::Tag new_tag{nc::utility::Tags::Tag::Internalize(new_label), old_tag.Color()};
        m_Tags[row] = new_tag;
        m_TagsStorage->Set(m_Tags);
        m_TagOperationsQue.async(
            [old_tag, new_tag] { nc::utility::Tags::ChangeLabelOfAllItemsWithTag(old_tag.Label(), new_tag.Label()); });
    }
}

- (std::string)findNextTagLabel
{
    const std::string base = NSLocalizedString(@"Untitled", "Name of a newly created tag").UTF8String;
    for( int i = 1;; ++i ) {
        const std::string label = i == 1 ? base : fmt::format("{} {}", base, i);
        if( std::ranges::none_of(m_Tags, [&](auto &_tag) { return _tag.Label() == label; }) )
            return label;
    }
}

- (IBAction)onTagPlusMinusClicked:(id)_sender
{
    using nc::utility::Tags;
    if( _sender == self.tagsPlusMinus ) {
        const auto segment = self.tagsPlusMinus.selectedSegment;
        if( segment == 0 ) {
            const std::string new_label = [self findNextTagLabel];
            const Tags::Tag new_tag{Tags::Tag::Internalize(new_label), Tags::Color::None};
            m_Tags.insert(m_Tags.begin(), new_tag);
            m_TagsStorage->Set(m_Tags);
            [self.tagsTable reloadData];
            [self.tagsTable scrollRowToVisible:0];
            if( NSTableRowView *row = [self.tagsTable rowViewAtRow:0 makeIfNecessary:true] ) {
                if( NSTableCellView *cell = nc::objc_cast<NSTableCellView>([row viewAtColumn:1]) ) {
                    if( NSTextField *tf = cell.textField ) {
                        [self.tagsTable.window makeFirstResponder:tf];
                        [tf selectText:nil];
                    }
                }
            }
        }
        if( segment == 1 ) {
            const long row = self.tagsTable.selectedRow;
            if( row < 0 || static_cast<size_t>(row) >= m_Tags.size() )
                return;

            const nc::utility::Tags::Tag tag = m_Tags[row];
            NSAlert *alert = [[NSAlert alloc] init];
            auto fmt = NSLocalizedString(@"Do you want to delete tag “%@”?", "Alert shown when a user removes a tag");
            alert.messageText =
                [NSString localizedStringWithFormat:fmt, [NSString stringWithUTF8StdString:tag.Label()]];
            alert.informativeText =
                NSLocalizedString(@"You can’t undo this action.", "Alert shown when a user removes a tag - message");
            [alert addButtonWithTitle:NSLocalizedString(@"Delete Tag", "")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
            [alert.buttons objectAtIndex:0].keyEquivalent = @"";
            alert.alertStyle = NSAlertStyleCritical;
            auto handler = [self, row, tag](NSModalResponse _resp) {
                if( _resp != NSAlertFirstButtonReturn )
                    return;
                m_Tags.erase(std::next(m_Tags.begin(), row));
                m_TagsStorage->Set(m_Tags);
                [self.tagsTable reloadData];
                m_TagOperationsQue.async([tag] { nc::utility::Tags::RemoveTagFromAllItems(tag.Label()); });
            };
            [alert beginSheetModalForWindow:self.tagsTable.window completionHandler:handler];
        }
        if( segment == 2 ) {
            const auto b = self.tagsPlusMinus.bounds;
            const auto origin =
                NSMakePoint(b.size.width - [self.tagsPlusMinus widthForSegment:2] - 3, b.size.height + 3);
            [self.tagsAdditionalMenu popUpMenuPositioningItem:nil atLocation:origin inView:self.tagsPlusMinus];
        }
    }
}

- (IBAction)onSearchForNewTags:(id)sender
{
    __weak PreferencesWindowPanelsTab *weak_self = self;
    m_TagOperationsQue.async([weak_self] {
        if( weak_self ) {
            auto all_tags = nc::utility::Tags::GatherAllItemsTags();
            dispatch_to_main_queue([all_tags = std::move(all_tags), weak_self] {
                if( PreferencesWindowPanelsTab *const me = weak_self )
                    [me acceptFSTags:all_tags];
            });
        }
    });
}

- (void)acceptFSTags:(const std::vector<nc::utility::Tags::Tag> &)_tags
{
    using nc::utility::Tags;
    std::vector<Tags::Tag> added;
    for( auto &fs_tag : _tags ) {
        if( std::ranges::none_of(m_Tags, [&](auto &_tag) { return _tag.Label() == fs_tag.Label(); }) ) {
            m_Tags.push_back(fs_tag);
            added.push_back(fs_tag);
        }
    }

    if( added.empty() ) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"No new tags were found.",
                                              "Information shown when no new tags were found after searching the fs");
        alert.alertStyle = NSAlertStyleInformational;
        [alert beginSheetModalForWindow:self.tagsTable.window
                      completionHandler:^(NSModalResponse){
                      }];
    }
    else {
        m_TagsStorage->Set(m_Tags);
        [self.tagsTable reloadData];
        std::vector<std::string> labels;
        labels.reserve(added.size());
        for( auto &tag : added )
            labels.push_back(fmt::format("“{}”", tag.Label()));

        NSAlert *alert = [[NSAlert alloc] init];
        auto msg = NSLocalizedString(@"The following tags were added: %@.",
                                     "Information shown when new tags were found after searching the fs");
        alert.messageText = [NSString
            localizedStringWithFormat:msg,
                                      [NSString stringWithUTF8StdString:fmt::format("{}", fmt::join(labels, ", "))]];
        alert.alertStyle = NSAlertStyleInformational;
        [alert beginSheetModalForWindow:self.tagsTable.window
                      completionHandler:^(NSModalResponse){
                      }];
    }
}

@end
