// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelListView.h"
#include <Base/algo.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <Utility/AdaptiveDateFormatting.h>
#include <Utility/ObjCpp.h>
#include <Panel/PanelData.h>
#include <Panel/PanelDataSortMode.h>

#include "../Helpers/IconRepositoryCleaner.h"
#include "../PanelView.h"
#include "Layout.h"
#include "PanelListViewDateTimeView.h"
#include "PanelListViewExtensionView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewNameView.h"
#include "PanelListViewRowView.h"
#include "PanelListViewSizeView.h"
#include "PanelListViewTableHeaderView.h"
#include "PanelListViewTableView.h"
#include "PanelListViewTagsView.h"
#include <algorithm>

#include <swiftToCxx/_SwiftCxxInteroperability.h>
#include <NimbleCommanderCommon-Swift.h>

using namespace nc;
using namespace nc::panel;
using nc::utility::AdaptiveDateFormatting;
using nc::vfsicon::IconRepository;

static const auto g_MaxStashedRows = 50;
static const auto g_SortAscImage = [NSImage imageNamed:@"NSAscendingSortIndicator"];
static const auto g_SortDescImage = [NSImage imageNamed:@"NSDescendingSortIndicator"];

// identifiers legend:
// A - Name
// G - Extension
// B - Size
// C - Date created
// D - Date added
// E - Date modified
// F - Date accessed
// H - Tags

static PanelListViewColumns IdentifierToKind(char _letter) noexcept;
static NSString *ToKindIdentifier(PanelListViewColumns _kind) noexcept;

@interface PanelListView ()

@property(nonatomic) AdaptiveDateFormatting::Style dateCreatedFormattingStyle;
@property(nonatomic) AdaptiveDateFormatting::Style dateAddedFormattingStyle;
@property(nonatomic) AdaptiveDateFormatting::Style dateModifiedFormattingStyle;
@property(nonatomic) AdaptiveDateFormatting::Style dateAccessedFormattingStyle;

@end

@implementation PanelListView {
    NSScrollView *m_ScrollView;
    PanelListViewTableView *m_TableView;
    data::Model *m_Data;
    __weak PanelView *m_PanelView;
    PanelListViewGeometry m_Geometry;
    IconRepository *m_IconRepository;
    NSTableColumn *m_NameColumn;
    NSTableColumn *m_ExtensionColumn;
    NSTableColumn *m_SizeColumn;
    NSTableColumn *m_DateCreatedColumn;
    NSTableColumn *m_DateAddedColumn;
    NSTableColumn *m_DateModifiedColumn;
    NSTableColumn *m_DateAccessedColumn;
    NSTableColumn *m_TagsColumn;
    AdaptiveDateFormatting::Style m_DateCreatedFormattingStyle;
    AdaptiveDateFormatting::Style m_DateAddedFormattingStyle;
    AdaptiveDateFormatting::Style m_DateModifiedFormattingStyle;
    AdaptiveDateFormatting::Style m_DateAccessedFormattingStyle;

    std::vector<PanelListViewRowView *> m_RowsStash;

    data::SortMode m_SortMode;
    std::function<void(data::SortMode)> m_SortModeChangeCallback;

    PanelListViewColumnsLayout m_AssignedLayout;
    ThemesManager::ObservationTicket m_ThemeObservation;
}

@synthesize dateCreatedFormattingStyle = m_DateCreatedFormattingStyle;
@synthesize dateAddedFormattingStyle = m_DateAddedFormattingStyle;
@synthesize dateModifiedFormattingStyle = m_DateModifiedFormattingStyle;
@synthesize dateAccessedFormattingStyle = m_DateAccessedFormattingStyle;
@synthesize sortMode = m_SortMode;
@synthesize sortModeChangeCallback = m_SortModeChangeCallback;

- (id)initWithFrame:(NSRect)_frame andIR:(nc::vfsicon::IconRepository &)_ir
{
    self = [super initWithFrame:_frame];
    if( self ) {
        m_IconRepository = &_ir;

        [self calculateItemLayout];

        m_ScrollView = [[NSScrollView alloc] initWithFrame:_frame];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_ScrollView.wantsLayer = true;
        m_ScrollView.layer.drawsAsynchronously = false;
        m_ScrollView.contentView.copiesOnScroll = true;
        m_ScrollView.hasVerticalScroller = true;
        m_ScrollView.hasHorizontalScroller = true;
        m_ScrollView.borderType = NSNoBorder;
        m_ScrollView.drawsBackground = true;
        [self addSubview:m_ScrollView];

        NSDictionary *views = NSDictionaryOfVariableBindings(m_ScrollView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_ScrollView]-(0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ScrollView]-(0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];

        m_TableView = [[PanelListViewTableView alloc] initWithFrame:_frame];
        m_TableView.dataSource = self;
        m_TableView.delegate = self;
        m_TableView.allowsMultipleSelection = false;
        m_TableView.allowsEmptySelection = false;
        m_TableView.allowsColumnSelection = false;
        m_TableView.allowsColumnReordering = true;
        m_TableView.usesAlternatingRowBackgroundColors = true;
        m_TableView.rowSizeStyle = NSTableViewRowSizeStyleCustom;
        m_TableView.rowHeight = m_Geometry.LineHeight();
        m_TableView.intercellSpacing = NSMakeSize(0, 0);
        m_TableView.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
        // we don't allow NSTableView to draw the grid since it goes haywire when custom drawing
        // is enabled, so instead the PanelListViewTableView draws it manually in
        // drawBackgroundInClipRect:
        m_TableView.gridStyleMask = NSTableViewGridNone;
        if( @available(macOS 11.0, *) )
            m_TableView.style = NSTableViewStylePlain;
        m_TableView.headerView = [[PanelListViewTableHeaderView alloc] init];
        [self setupColumns];

        m_ScrollView.documentView = m_TableView;

        __weak PanelListView *weak_self = self;
        m_IconRepository->SetUpdateCallback([=](IconRepository::SlotKey _slot, NSImage *_icon) {
            if( auto strong_self = weak_self )
                [strong_self onIconUpdated:_slot image:_icon];
        });
        m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::FilePanelsList | ThemesManager::Notifications::FilePanelsGeneral,
            [weak_self] {
                if( auto strong_self = weak_self )
                    [strong_self handleThemeChanges];
            });

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(dateDidChange:)
                                                   name:NSCalendarDayChangedNotification
                                                 object:nil];

        [self handleThemeChanges];
    }
    return self;
}

- (void)setupColumns
{
    m_NameColumn = [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::Filename)];
    m_NameColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_NameColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_NAME", "");
    m_NameColumn.width = 200;
    m_NameColumn.minWidth = 180;
    m_NameColumn.maxWidth = 2000;
    m_NameColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_NameColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    [m_NameColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];

    m_ExtensionColumn = [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::Extension)];
    m_ExtensionColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_ExtensionColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_EXTENSION", "");
    m_ExtensionColumn.width = 60;
    m_ExtensionColumn.minWidth = 50;
    m_ExtensionColumn.maxWidth = 200;
    m_ExtensionColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_ExtensionColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    [m_ExtensionColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];

    m_SizeColumn = [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::Size)];
    m_SizeColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_SizeColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_SIZE", "");
    m_SizeColumn.width = 90;
    m_SizeColumn.minWidth = 75;
    m_SizeColumn.maxWidth = 110;
    m_SizeColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_SizeColumn.resizingMask = NSTableColumnUserResizingMask;
    [m_SizeColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];

    m_DateCreatedColumn =
        [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::DateCreated)];
    m_DateCreatedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_DateCreatedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_CREATED", "");
    m_DateCreatedColumn.width = 90;
    m_DateCreatedColumn.minWidth = 75;
    m_DateCreatedColumn.maxWidth = 300;
    m_DateCreatedColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_DateCreatedColumn.resizingMask = NSTableColumnUserResizingMask;
    [m_DateCreatedColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];
    [self widthDidChangeForColumn:m_DateCreatedColumn];

    m_DateAddedColumn = [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::DateAdded)];
    m_DateAddedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_DateAddedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_ADDED", "");
    m_DateAddedColumn.width = 90;
    m_DateAddedColumn.minWidth = 75;
    m_DateAddedColumn.maxWidth = 300;
    m_DateAddedColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_DateAddedColumn.resizingMask = NSTableColumnUserResizingMask;
    [m_DateAddedColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];
    [self widthDidChangeForColumn:m_DateAddedColumn];

    m_DateModifiedColumn =
        [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::DateModified)];
    m_DateModifiedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_DateModifiedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_MODIFIED", "");
    m_DateModifiedColumn.width = 90;
    m_DateModifiedColumn.minWidth = 75;
    m_DateModifiedColumn.maxWidth = 300;
    m_DateModifiedColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_DateModifiedColumn.resizingMask = NSTableColumnUserResizingMask;
    [m_DateModifiedColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];
    [self widthDidChangeForColumn:m_DateModifiedColumn];

    m_DateAccessedColumn =
        [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::DateAccessed)];
    m_DateAccessedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_DateAccessedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_ACCESSED", "");
    m_DateAccessedColumn.width = 90;
    m_DateAccessedColumn.minWidth = 75;
    m_DateAccessedColumn.maxWidth = 300;
    m_DateAccessedColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_DateAccessedColumn.resizingMask = NSTableColumnUserResizingMask;
    [m_DateAccessedColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];
    [self widthDidChangeForColumn:m_DateAccessedColumn];

    m_TagsColumn = [[NSTableColumn alloc] initWithIdentifier:ToKindIdentifier(PanelListViewColumns::Tags)];
    m_TagsColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
    m_TagsColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_TAGS", "");
    m_TagsColumn.width = 120;
    m_TagsColumn.minWidth = 90;
    m_TagsColumn.maxWidth = 400;
    m_TagsColumn.headerCell.alignment = NSTextAlignmentLeft;
    m_TagsColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    [m_TagsColumn addObserver:self forKeyPath:@"width" options:0 context:nullptr];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [m_PanelView removeObserver:self forKeyPath:@"active"];
    [m_NameColumn removeObserver:self forKeyPath:@"width"];
    [m_ExtensionColumn removeObserver:self forKeyPath:@"width"];
    [m_SizeColumn removeObserver:self forKeyPath:@"width"];
    [m_DateCreatedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateAddedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateModifiedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateAccessedColumn removeObserver:self forKeyPath:@"width"];
    [m_TagsColumn removeObserver:self forKeyPath:@"width"];
}

- (void)viewDidMoveToSuperview
{
    if( auto pv = nc::objc_cast<PanelView>(self.superview) ) {
        m_PanelView = pv;
        [pv addObserver:self forKeyPath:@"active" options:0 context:nullptr];
        [self observeValueForKeyPath:@"active" ofObject:pv change:nil context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)_key_path
                      ofObject:(id)_object
                        change:(NSDictionary *) [[maybe_unused]] _change
                       context:(void *) [[maybe_unused]] _context
{
    if( _object == m_PanelView && [_key_path isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        [m_TableView enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rv, [[maybe_unused]] NSInteger row) {
          if( auto v = nc::objc_cast<PanelListViewRowView>(rv) )
              v.panelActive = active;
        }];
    }
    if( [_key_path isEqualToString:@"width"] ) {
        if( auto c = nc::objc_cast<NSTableColumn>(_object) )
            [self widthDidChangeForColumn:c];
    }
}

- (void)widthDidChangeForColumn:(NSTableColumn *)_column
{
    if( _column == m_DateCreatedColumn ) {
        const auto style = nc::utility::AdaptiveDateFormatting::SuitableStyleForWidth(
            static_cast<int>(m_DateCreatedColumn.width), self.font);
        self.dateCreatedFormattingStyle = style;
    }
    if( _column == m_DateAddedColumn ) {
        const auto style = nc::utility::AdaptiveDateFormatting::SuitableStyleForWidth(
            static_cast<int>(m_DateAddedColumn.width), self.font);
        self.dateAddedFormattingStyle = style;
    }
    if( _column == m_DateModifiedColumn ) {
        const auto style = nc::utility::AdaptiveDateFormatting::SuitableStyleForWidth(
            static_cast<int>(m_DateModifiedColumn.width), self.font);
        self.dateModifiedFormattingStyle = style;
    }
    if( _column == m_DateAccessedColumn ) {
        const auto style = nc::utility::AdaptiveDateFormatting::SuitableStyleForWidth(
            static_cast<int>(m_DateAccessedColumn.width), self.font);
        self.dateAccessedFormattingStyle = style;
    }
    [self notifyLastColumnToRedraw];
    [m_TableView setNeedsDisplay:true];
}

- (void)tableViewColumnDidResize:(NSNotification *) [[maybe_unused]] _notification
{
    if( m_TableView.headerView.resizedColumn < 0 )
        return;

    [self.panelView notifyAboutPresentationLayoutChange];
    [m_TableView setNeedsDisplay:true];
}

- (void)tableViewColumnDidMove:(NSNotification *) [[maybe_unused]] _notification
{
    [self.panelView notifyAboutPresentationLayoutChange];
    [m_TableView setNeedsDisplay:true];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *) [[maybe_unused]] _table_view
{
    return m_Data ? m_Data->SortedEntriesCount() : 0;
}

- (void)calculateItemLayout
{
    m_Geometry = PanelListViewGeometry(CurrentTheme().FilePanelsListFont(), m_AssignedLayout.icon_scale);

    [self setupIconsPxSize];

    if( m_TableView )
        m_TableView.rowHeight = m_Geometry.LineHeight();

    // By default the offset of the title in the header cell is the same as the default offset in the geometry
    for( auto column : {m_ExtensionColumn,
                        m_SizeColumn,
                        m_DateCreatedColumn,
                        m_DateAddedColumn,
                        m_DateModifiedColumn,
                        m_DateAccessedColumn,
                        m_TagsColumn} ) {
        if( auto cell = objc_cast<PanelListViewTableHeaderCell>(column.headerCell) ) {
            cell.leftOffset = static_cast<double>(m_Geometry.LeftInset());
        }
    }
    // But for the filename column the offset is special
    if( auto cell = objc_cast<PanelListViewTableHeaderCell>(m_NameColumn.headerCell) ) {
        cell.leftOffset = static_cast<double>(m_Geometry.FilenameOffsetInColumn());
    }
}

- (void)setupIconsPxSize
{
    if( self.window ) {
        const auto px_size = int(m_Geometry.IconSize() * self.window.backingScaleFactor);
        m_IconRepository->SetPxSize(px_size);
    }
    else {
        m_IconRepository->SetPxSize(m_Geometry.IconSize());
    }
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self setupIconsPxSize]; // we call this here due to a possible DPI change
}

template <typename View>
static View *RetrieveOrSpawnView(NSTableView *_tv, NSString *_identifier)
{
    if( View *const v = [_tv makeViewWithIdentifier:_identifier owner:nil] )
        return v;
    auto v = [[View alloc] initWithFrame:NSRect()];
    v.identifier = _identifier;
    return v;
}

- (nullable NSView *)tableView:(NSTableView *)_table_view
            viewForTableColumn:(nullable NSTableColumn *)_table_column
                           row:(NSInteger)_row_index
{
    if( !m_Data )
        return nil;

    const int row = static_cast<int>(_row_index);

    const auto abstract_row_view = [m_TableView rowViewAtRow:row makeIfNecessary:false];
    const auto row_view = nc::objc_cast<PanelListViewRowView>(abstract_row_view);
    if( row_view == nil )
        return nil;

    if( const auto vfs_item = row_view.item ) {
        const auto identifier = _table_column.identifier;
        const auto kind = IdentifierToKind(static_cast<char>([identifier characterAtIndex:0]));
        if( kind == PanelListViewColumns::Filename ) {
            auto nv = RetrieveOrSpawnView<PanelListViewNameView>(_table_view, identifier);
            if( m_Data->IsValidSortPosition(row) ) {
                auto &vd = m_Data->VolatileDataAtSortPosition(row);
                [self fillDataForNameView:nv withItem:vfs_item andVD:vd];
            }
            return nv;
        }
        if( kind == PanelListViewColumns::Extension ) {
            auto ev = RetrieveOrSpawnView<NCPanelListViewExtensionView>(_table_view, identifier);
            [self fillDataForExensionView:ev withItem:vfs_item];
            return ev;
        }
        if( kind == PanelListViewColumns::Size ) {
            auto sv = RetrieveOrSpawnView<PanelListViewSizeView>(_table_view, identifier);
            if( m_Data->IsValidSortPosition(row) ) {
                auto &vd = m_Data->VolatileDataAtSortPosition(row);
                [self fillDataForSizeView:sv withItem:vfs_item andVD:vd];
            }
            return sv;
        }
        if( kind == PanelListViewColumns::DateCreated ) {
            auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(_table_view, identifier);
            [self fillDataForDateCreatedView:dv withItem:vfs_item];
            return dv;
        }
        if( kind == PanelListViewColumns::DateAdded ) {
            auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(_table_view, identifier);
            [self fillDataForDateAddedView:dv withItem:vfs_item];
            return dv;
        }
        if( kind == PanelListViewColumns::DateModified ) {
            auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(_table_view, identifier);
            [self fillDataForDateModifiedView:dv withItem:vfs_item];
            return dv;
        }
        if( kind == PanelListViewColumns::DateAccessed ) {
            auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(_table_view, identifier);
            [self fillDataForDateAccessedView:dv withItem:vfs_item];
            return dv;
        }
        if( kind == PanelListViewColumns::Tags ) {
            auto tv = RetrieveOrSpawnView<NCPanelListViewTagsView>(_table_view, identifier);
            [self fillDataForTagsView:tv withItem:vfs_item];
            return tv;
        }
    }
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *) [[maybe_unused]] _table_view rowViewForRow:(NSInteger)_row_index
{
    if( !m_Data )
        return nil;

    const auto row = static_cast<int>(_row_index);
    if( auto item = m_Data->EntryAtSortPosition(row) ) {
        auto &vd = m_Data->VolatileDataAtSortPosition(row);

        PanelListViewRowView *row_view;
        if( !m_RowsStash.empty() ) {
            row_view = m_RowsStash.back();
            m_RowsStash.pop_back();
            row_view.item = item;
        }
        else {
            row_view = [[PanelListViewRowView alloc] initWithItem:item];
            row_view.listView = self;
        }
        row_view.itemIndex = row;
        row_view.vd = vd;
        row_view.panelActive = m_PanelView.active;

        return row_view;
    }
    return nil;
}

- (void)tableView:(NSTableView *) [[maybe_unused]] tableView
    didRemoveRowView:(NSTableRowView *) [[maybe_unused]] rowView
              forRow:(NSInteger)row
{
    if( row < 0 && m_RowsStash.size() < g_MaxStashedRows )
        if( auto r = nc::objc_cast<PanelListViewRowView>(rowView) ) {
            r.item = VFSListingItem();
            m_RowsStash.push_back(r);
        }
}

- (void)fillDataForNameView:(PanelListViewNameView *)_view
                   withItem:(const VFSListingItem &)_item
                      andVD:(data::ItemVolatileData &)_vd
{
    [_view setFilename:_item.DisplayNameNS() andTags:_item.Tags()];

    if( m_IconRepository->IsValidSlot(_vd.icon) ) {
        [_view setIcon:m_IconRepository->AvailableIconForSlot(_vd.icon)];
        m_IconRepository->ScheduleIconProduction(_vd.icon, _item);
    }
    else {
        _vd.icon = m_IconRepository->Register(_item);
        if( m_IconRepository->IsValidSlot(_vd.icon) ) {
            [_view setIcon:m_IconRepository->AvailableIconForSlot(_vd.icon)];
            m_IconRepository->ScheduleIconProduction(_vd.icon, _item);
        }
        else {
            [_view setIcon:m_IconRepository->AvailableIconForListingItem(_item)];
        }
    }
}

- (void)fillDataForExensionView:(NCPanelListViewExtensionView *)_view withItem:(const VFSListingItem &)_item
{
    if( _item.HasExtension() )
        [_view setExtension:[NSString stringWithUTF8String:_item.Extension()]];
    else
        [_view setExtension:nil];
}

- (void)fillDataForTagsView:(NCPanelListViewTagsView *)_view withItem:(const VFSListingItem &)_item
{
    [_view setTags:_item.Tags()];
}

- (void)fillDataForSizeView:(PanelListViewSizeView *)_view
                   withItem:(const VFSListingItem &)_item
                      andVD:(const data::ItemVolatileData &)_vd
{
    [_view setSizeWithItem:_item andVD:_vd];
}

- (void)fillDataForDateCreatedView:(PanelListViewDateTimeView *)_view withItem:(const VFSListingItem &)_item
{
    _view.time = _item.BTime();
    _view.style = m_DateCreatedFormattingStyle;
}

- (void)fillDataForDateAddedView:(PanelListViewDateTimeView *)_view withItem:(const VFSListingItem &)_item
{
    _view.time = _item.HasAddTime() ? _item.AddTime() : -1;
    _view.style = m_DateAddedFormattingStyle;
}

- (void)fillDataForDateModifiedView:(PanelListViewDateTimeView *)_view withItem:(const VFSListingItem &)_item
{
    _view.time = _item.MTime();
    _view.style = m_DateModifiedFormattingStyle;
}

- (void)fillDataForDateAccessedView:(PanelListViewDateTimeView *)_view withItem:(const VFSListingItem &)_item
{
    _view.time = _item.ATime();
    _view.style = m_DateAccessedFormattingStyle;
}

- (void)dataChanged
{
    data::Model *const data = m_Data;
    const auto old_rows_count = static_cast<int>(m_TableView.numberOfRows);
    const auto new_rows_count = data->SortedEntriesCount();

    IconRepositoryCleaner{*m_IconRepository, *m_Data}.SweepUnusedSlots();

    auto block = ^(PanelListViewRowView *row_view, NSInteger rowIndex) {
      const int row = static_cast<int>(rowIndex);
      if( row >= new_rows_count )
          return;

      if( auto item = data->EntryAtSortPosition(row) ) {
          auto &vd = data->VolatileDataAtSortPosition(row);
          row_view.item = item;
          row_view.vd = vd;
          for( NSView *v in row_view.subviews ) {
              NSString *identifier = v.identifier;
              if( identifier.length == 0 )
                  continue;
              const auto col_id = [v.identifier characterAtIndex:0];
              const auto col_type = IdentifierToKind(static_cast<char>(col_id));
              if( col_type == PanelListViewColumns::Filename )
                  [self fillDataForNameView:static_cast<PanelListViewNameView *>(v) withItem:item andVD:vd];
              if( col_type == PanelListViewColumns::Extension )
                  [self fillDataForExensionView:static_cast<NCPanelListViewExtensionView *>(v) withItem:item];
              if( col_type == PanelListViewColumns::Size )
                  [self fillDataForSizeView:static_cast<PanelListViewSizeView *>(v) withItem:item andVD:vd];
              if( col_type == PanelListViewColumns::DateCreated )
                  [self fillDataForDateCreatedView:static_cast<PanelListViewDateTimeView *>(v) withItem:item];
              if( col_type == PanelListViewColumns::DateAdded )
                  [self fillDataForDateAddedView:static_cast<PanelListViewDateTimeView *>(v) withItem:item];
              if( col_type == PanelListViewColumns::DateModified )
                  [self fillDataForDateModifiedView:static_cast<PanelListViewDateTimeView *>(v) withItem:item];
              if( col_type == PanelListViewColumns::DateAccessed )
                  [self fillDataForDateAccessedView:static_cast<PanelListViewDateTimeView *>(v) withItem:item];
              if( col_type == PanelListViewColumns::Tags )
                  [self fillDataForTagsView:static_cast<NCPanelListViewTagsView *>(v) withItem:item];
          }
      }
    };
    [m_TableView enumerateAvailableRowViewsUsingBlock:block];

    if( old_rows_count < new_rows_count ) {
        const auto to_add = NSMakeRange(old_rows_count, new_rows_count - old_rows_count);
        [m_TableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:to_add]
                           withAnimation:NSTableViewAnimationEffectNone];
    }
    else if( old_rows_count > new_rows_count ) {
        const auto to_remove = NSMakeRange(new_rows_count, old_rows_count - new_rows_count);
        [m_TableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:to_remove]
                           withAnimation:NSTableViewAnimationEffectNone];
    }
}
- (void)syncVolatileData
{
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
      if( m_Data->IsValidSortPosition(static_cast<int>(row)) )
          rowView.vd = m_Data->VolatileDataAtSortPosition(static_cast<int>(row));
    }];
}

- (void)setData:(data::Model *)_data
{
    m_Data = _data;
    [self dataChanged];
}

- (int)itemsInColumn
{
    return int(m_ScrollView.contentView.bounds.size.height / m_Geometry.LineHeight());
}

- (int)maxNumberOfVisibleItems
{
    return [self itemsInColumn];
}

- (int)cursorPosition
{
    return static_cast<int>(m_TableView.selectedRow);
}

- (void)setCursorPosition:(int)_cursor_position
{
    if( _cursor_position >= 0 ) {
        [m_TableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_cursor_position] byExtendingSelection:false];
        [self ensureItemIsVisible:_cursor_position];
    }
    else {
        [m_TableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:false];
    }
}

- (void)ensureItemIsVisible:(int)_item_index
{
    if( _item_index < 0 )
        return;

    const auto item_rect = [m_TableView rectOfRow:_item_index];
    if( NSEqualRects(item_rect, NSZeroRect) )
        return; // failsafe if the invariant is broken

    const auto visible_rect = m_ScrollView.documentVisibleRect;
    const auto header_height = m_TableView.headerView.bounds.size.height;
    const auto visible_rect_without_headers = NSMakeRect(visible_rect.origin.x,
                                                         visible_rect.origin.y + header_height,
                                                         visible_rect.size.width,
                                                         visible_rect.size.height - header_height);

    // check the item is visible now
    if( NSContainsRect(visible_rect_without_headers, item_rect) )
        return; // already visible, nothing to do

    // decide which direction to scroll and how to place the item
    if( item_rect.origin.y < visible_rect_without_headers.origin.y ) {
        // scroll up
        const auto rc = NSMakeRect(
            item_rect.origin.x, item_rect.origin.y - header_height, item_rect.size.width, item_rect.size.height);
        [self doScrollRectToVisible:rc];
    }
    else if( NSMaxY(item_rect) > NSMaxY(visible_rect_without_headers) ) {
        // scroll down
        const auto rc = NSMakeRect(item_rect.origin.x,
                                   item_rect.origin.y - visible_rect.size.height + item_rect.size.height,
                                   item_rect.size.width,
                                   item_rect.size.height);
        [self doScrollRectToVisible:rc];
    }
}

- (const PanelListViewGeometry &)geometry
{
    return m_Geometry;
}

- (NSFont *)font
{
    return CurrentTheme().FilePanelsListFont();
}

- (void)onIconUpdated:(IconRepository::SlotKey)_icon_no image:(NSImage *)_image
{
    dispatch_assert_main_queue();
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
      const auto index = static_cast<int>(row);
      if( m_Data->IsValidSortPosition(index) ) {
          auto &vd = m_Data->VolatileDataAtSortPosition(index);
          if( vd.icon == _icon_no )
              rowView.nameView.icon = _image;
      }
    }];
}

- (void)updateDateTimeViewAtColumn:(NSTableColumn *)_column withStyle:(AdaptiveDateFormatting::Style)_style
{
    // use this!!!!
    // m_TableView viewAtColumn:<#(NSInteger)#> row:<#(NSInteger)#> makeIfNecessary:<#(BOOL)#>

    const auto col_index = [m_TableView.tableColumns indexOfObject:_column];
    if( col_index != NSNotFound )
        [m_TableView
            enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, [[maybe_unused]] NSInteger row) {
              if( auto v = nc::objc_cast<PanelListViewDateTimeView>([rowView viewAtColumn:col_index]) )
                  v.style = _style;
            }];
}

- (void)setDateCreatedFormattingStyle:(AdaptiveDateFormatting::Style)_style
{
    if( m_DateCreatedFormattingStyle != _style ) {
        m_DateCreatedFormattingStyle = _style;
        [self updateDateTimeViewAtColumn:m_DateCreatedColumn withStyle:_style];
    }
}

- (void)setDateAddedFormattingStyle:(AdaptiveDateFormatting::Style)_style
{
    if( m_DateAddedFormattingStyle != _style ) {
        m_DateAddedFormattingStyle = _style;
        [self updateDateTimeViewAtColumn:m_DateAddedColumn withStyle:_style];
    }
}

- (void)setDateModifiedFormattingStyle:(AdaptiveDateFormatting::Style)_style
{
    if( m_DateModifiedFormattingStyle != _style ) {
        m_DateModifiedFormattingStyle = _style;
        [self updateDateTimeViewAtColumn:m_DateModifiedColumn withStyle:_style];
    }
}

- (void)setDateAccessedFormattingStyle:(AdaptiveDateFormatting::Style)_style
{
    if( m_DateAccessedFormattingStyle != _style ) {
        m_DateAccessedFormattingStyle = _style;
        [self updateDateTimeViewAtColumn:m_DateAccessedColumn withStyle:_style];
    }
}

- (NSTableColumn *)columnByType:(PanelListViewColumns)_type
{
    switch( _type ) {
        case PanelListViewColumns::Filename:
            return m_NameColumn;
        case PanelListViewColumns::Extension:
            return m_ExtensionColumn;
        case PanelListViewColumns::Size:
            return m_SizeColumn;
        case PanelListViewColumns::DateCreated:
            return m_DateCreatedColumn;
        case PanelListViewColumns::DateAdded:
            return m_DateAddedColumn;
        case PanelListViewColumns::DateModified:
            return m_DateModifiedColumn;
        case PanelListViewColumns::DateAccessed:
            return m_DateAccessedColumn;
        case PanelListViewColumns::Tags:
            return m_TagsColumn;
        default:
            return nil;
    }
}

- (PanelListViewColumns)typeByColumn:(NSTableColumn *)_col
{
    if( _col == m_NameColumn )
        return PanelListViewColumns::Filename;
    if( _col == m_ExtensionColumn )
        return PanelListViewColumns::Extension;
    if( _col == m_SizeColumn )
        return PanelListViewColumns::Size;
    if( _col == m_DateCreatedColumn )
        return PanelListViewColumns::DateCreated;
    if( _col == m_DateAddedColumn )
        return PanelListViewColumns::DateAdded;
    if( _col == m_DateModifiedColumn )
        return PanelListViewColumns::DateModified;
    if( _col == m_DateAccessedColumn )
        return PanelListViewColumns::DateAccessed;
    if( _col == m_TagsColumn )
        return PanelListViewColumns::Tags;
    return PanelListViewColumns::Empty;
}

- (PanelListViewColumnsLayout)columnsLayout
{
    PanelListViewColumnsLayout l;
    l.icon_scale = m_AssignedLayout.icon_scale;
    for( NSTableColumn *tc in m_TableView.tableColumns ) {
        PanelListViewColumnsLayout::Column c;
        c.kind = [self typeByColumn:tc];
        c.width = short(tc.width);
        l.columns.emplace_back(c);
    }
    return l;
}

- (void)setColumnsLayout:(PanelListViewColumnsLayout)_layout
{
    if( _layout == m_AssignedLayout )
        return;

    for( NSTableColumn *c in [m_TableView.tableColumns copy] )
        [m_TableView removeTableColumn:c];

    for( auto &c : _layout.columns ) {
        if( NSTableColumn *tc = [self columnByType:c.kind] ) {
            if( c.min_width >= 0 )
                tc.minWidth = c.min_width;
            if( c.max_width >= 0 )
                tc.maxWidth = c.max_width;
            if( c.width >= 0 )
                tc.width = c.width;

            [m_TableView addTableColumn:tc];
        }
    }

    m_AssignedLayout = _layout;
    [m_TableView sizeToFit];
    [self calculateItemLayout];
    [self placeSortIndicator];
}

- (void)setSortMode:(data::SortMode)_mode
{
    if( m_SortMode == _mode )
        return;
    m_SortMode = _mode;

    [self placeSortIndicator];
}

- (void)placeSortIndicator
{
    for( NSTableColumn *c in m_TableView.tableColumns )
        [m_TableView setIndicatorImage:nil inTableColumn:c];

    auto set = [&]() -> std::pair<NSImage *, NSTableColumn *> {
        using _ = data::SortMode;
        switch( m_SortMode.sort ) {
            case _::SortByName:
                return {g_SortAscImage, m_NameColumn};
            case _::SortByNameRev:
                return {g_SortDescImage, m_NameColumn};
            case _::SortByExt:
                return {g_SortAscImage, m_ExtensionColumn};
            case _::SortByExtRev:
                return {g_SortDescImage, m_ExtensionColumn};
            case _::SortBySize:
                return {g_SortDescImage, m_SizeColumn};
            case _::SortBySizeRev:
                return {g_SortAscImage, m_SizeColumn};
            case _::SortByBirthTime:
                return {g_SortDescImage, m_DateCreatedColumn};
            case _::SortByBirthTimeRev:
                return {g_SortAscImage, m_DateCreatedColumn};
            case _::SortByModTime:
                return {g_SortDescImage, m_DateModifiedColumn};
            case _::SortByModTimeRev:
                return {g_SortAscImage, m_DateModifiedColumn};
            case _::SortByAddTime:
                return {g_SortDescImage, m_DateAddedColumn};
            case _::SortByAddTimeRev:
                return {g_SortAscImage, m_DateAddedColumn};
            case _::SortByAccessTime:
                return {g_SortDescImage, m_DateAccessedColumn};
            case _::SortByAccessTimeRev:
                return {g_SortAscImage, m_DateAccessedColumn};
            default:
                return std::make_pair(nil, nil);
        }
    }();

    if( set.first && set.second )
        [m_TableView setIndicatorImage:set.first inTableColumn:set.second];
}

- (void)tableView:(NSTableView *) [[maybe_unused]] _table_view didClickTableColumn:(NSTableColumn *)_table_column
{
    auto proposed = m_SortMode;
    auto swp = [&](data::SortMode::Mode _1st, data::SortMode::Mode _2nd) {
        proposed.sort = (proposed.sort == _1st ? _2nd : _1st);
    };

    if( _table_column == m_NameColumn )
        swp(data::SortMode::SortByName, data::SortMode::SortByNameRev);
    else if( _table_column == m_ExtensionColumn )
        swp(data::SortMode::SortByExt, data::SortMode::SortByExtRev);
    else if( _table_column == m_SizeColumn )
        swp(data::SortMode::SortBySize, data::SortMode::SortBySizeRev);
    else if( _table_column == m_DateCreatedColumn )
        swp(data::SortMode::SortByBirthTime, data::SortMode::SortByBirthTimeRev);
    else if( _table_column == m_DateModifiedColumn )
        swp(data::SortMode::SortByModTime, data::SortMode::SortByModTimeRev);
    else if( _table_column == m_DateAddedColumn )
        swp(data::SortMode::SortByAddTime, data::SortMode::SortByAddTimeRev);
    else if( _table_column == m_DateAccessedColumn )
        swp(data::SortMode::SortByAccessTime, data::SortMode::SortByAccessTimeRev);

    if( proposed != m_SortMode && m_SortModeChangeCallback )
        m_SortModeChangeCallback(proposed);
}

- (void)notifyLastColumnToRedraw
{
    auto cn = m_TableView.numberOfColumns;
    if( !cn )
        return;

    for( int i = 0, e = static_cast<int>(m_TableView.numberOfRows); i != e; ++i )
        [m_TableView viewAtColumn:cn - 1 row:i makeIfNecessary:false].needsDisplay = true;
}

- (bool)isItemVisible:(int)_sorted_item_index
{
    CGRect visibleRect = m_ScrollView.contentView.visibleRect;
    NSRange range = [m_TableView rowsInRect:visibleRect];
    return NSLocationInRange(_sorted_item_index, range);
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor forItemAtIndex:(int)_sorted_item_index
{
    if( PanelListViewRowView *rv = [m_TableView rowViewAtRow:_sorted_item_index makeIfNecessary:false] )
        [rv.nameView setupFieldEditor:_editor];
}

- (PanelView *)panelView
{
    return m_PanelView;
}

- (void)onPageUp:(NSEvent *) [[maybe_unused]] _event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y -= rect.size.height - m_TableView.headerView.bounds.size.height;
    [self doScrollRectToVisible:rect];
}

- (void)onPageDown:(NSEvent *) [[maybe_unused]] _event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y += rect.size.height;
    [self doScrollRectToVisible:rect];
}

- (void)onScrollToBeginning:(NSEvent *) [[maybe_unused]] _event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y = -m_TableView.headerView.bounds.size.height;
    [self doScrollRectToVisible:rect];
}

- (void)onScrollToEnd:(NSEvent *) [[maybe_unused]] _event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y = m_TableView.bounds.size.height - m_TableView.visibleRect.size.height +
                    m_TableView.headerView.bounds.size.height;
    [self doScrollRectToVisible:rect];
}

- (void)doScrollRectToVisible:(NSRect)_rc
{
    // NB! not updated automatically, initialized only once per run
    static const bool smooth_scroll = GlobalConfig().GetBool("filePanel.presentation.smoothScrolling");
    if( smooth_scroll )
        [m_ScrollView.contentView scrollPoint:_rc.origin];
    else
        [m_ScrollView.contentView setBoundsOrigin:_rc.origin];
}

- (int)sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options) [[maybe_unused]] _options
{
    const auto local_point = [m_TableView convertPoint:_window_point fromView:nil];
    const auto visible_rect = m_ScrollView.documentVisibleRect;
    if( !NSPointInRect(local_point, visible_rect) )
        return -1;

    const auto row_index = [m_TableView rowAtPoint:local_point];
    if( row_index < 0 )
        return -1;

    if( PanelListViewRowView *rv = [m_TableView rowViewAtRow:row_index makeIfNecessary:false] )
        return rv.itemIndex;

    return -1;
}

- (void)frameDidChange
{
    [self notifyLastColumnToRedraw];
}

- (BOOL)tableView:(NSTableView *) [[maybe_unused]] tableView
    shouldReorderColumn:(NSInteger)columnIndex
               toColumn:(NSInteger)newColumnIndex
{
    return columnIndex != 0 && newColumnIndex != 0;
}

- (NSMenu *)columnsSelectionMenu
{
    if( auto nib = [[NSNib alloc] initWithNibNamed:@"PanelListViewColumnsMenu" bundle:nil] ) {
        NSArray *objects;
        if( [nib instantiateWithOwner:nil topLevelObjects:&objects] )
            for( id i in objects )
                if( auto menu = nc::objc_cast<NSMenu>(i) )
                    return menu;
    }
    return nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)_menu_item
{
    if( _menu_item.action == @selector(onToggleColumnVisibilty:) ) {
        const auto kind = IdentifierToKind(static_cast<char>([_menu_item.identifier characterAtIndex:0]));
        const auto column = [self columnByType:kind];
        _menu_item.state = column && [m_TableView.tableColumns containsObject:column];
    }
    return true;
}

- (IBAction)onToggleColumnVisibilty:(id)_sender
{
    if( auto menu_item = nc::objc_cast<NSMenuItem>(_sender) ) {
        const auto kind = IdentifierToKind(static_cast<char>([menu_item.identifier characterAtIndex:0]));

        if( kind == PanelListViewColumns::Empty )
            return;

        auto layout = self.columnsLayout;

        const auto t = std::ranges::find_if(layout.columns, [&](const auto &_i) { return _i.kind == kind; });

        if( t != std::end(layout.columns) ) {
            layout.columns.erase(t);
        }
        else {
            PanelListViewColumnsLayout::Column c;
            c.kind = kind;
            layout.columns.emplace_back(c);
        }

        self.columnsLayout = layout;
        [self.panelView notifyAboutPresentationLayoutChange];
    }
}

- (void)handleThemeChanges
{
    auto cp = self.cursorPosition;
    [self calculateItemLayout];
    [m_TableView reloadData];
    self.cursorPosition = cp;
    m_TableView.gridColor = CurrentTheme().FilePanelsListGridColor();
    m_ScrollView.backgroundColor = CurrentTheme().FilePanelsListRegularEvenRowBackgroundColor();

    for( NSTableColumn *col : {m_NameColumn,
                               m_ExtensionColumn,
                               m_SizeColumn,
                               m_DateCreatedColumn,
                               m_DateAddedColumn,
                               m_DateModifiedColumn,
                               m_DateAccessedColumn,
                               m_TagsColumn} ) {
        if( PanelListViewTableHeaderCell *cell = objc_cast<PanelListViewTableHeaderCell>(col.headerCell) ) {
            [cell updateThemeWithTextFont:CurrentTheme().FilePanelsListHeaderFont()
                                textColor:CurrentTheme().FilePanelsListHeaderTextColor()
                           separatorColor:CurrentTheme().FilePanelsListHeaderSeparatorColor()
                          backgroundColor:CurrentTheme().FilePanelsListHeaderBackgroundColor()];
        }
    }
}

- (void)dateDidChange:(NSNotification *) [[maybe_unused]] _notification
{
    // may be triggered from a background notification thread, so kick the handling to the main
    // thread
    __weak PanelListView *weak_self = self;
    dispatch_to_main_queue([weak_self] {
        if( PanelListView *const strong_self = weak_self )
            [strong_self dateDidChangeImpl];
    });
}

- (void)dateDidChangeImpl
{
    dispatch_assert_main_queue();
    auto block = ^(PanelListViewRowView *row_view, NSInteger) {
      for( NSView *v in row_view.subviews ) {
          NSString *identifier = v.identifier;
          if( identifier.length == 0 )
              continue;
          const auto col_id = [v.identifier characterAtIndex:0];
          if( col_id == 'C' || col_id == 'D' || col_id == 'E' ) {
              auto date_view = nc::objc_cast<PanelListViewDateTimeView>(v);
              [date_view dateChanged];
          }
      }
    };
    [m_TableView enumerateAvailableRowViewsUsingBlock:block];
}

- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index
{
    const NSRect rc = [m_TableView rectOfRow:_sorted_item_index];
    if( rc.size.height == 0. )
        return {};
    return [self convertRect:rc fromView:m_TableView];
}

@end

static PanelListViewColumns IdentifierToKind(char _letter) noexcept
{
    switch( _letter ) {
        case 'A':
            return PanelListViewColumns::Filename;
        case 'B':
            return PanelListViewColumns::Size;
        case 'C':
            return PanelListViewColumns::DateCreated;
        case 'D':
            return PanelListViewColumns::DateAdded;
        case 'E':
            return PanelListViewColumns::DateModified;
        case 'F':
            return PanelListViewColumns::DateAccessed;
        case 'G':
            return PanelListViewColumns::Extension;
        case 'H':
            return PanelListViewColumns::Tags;
        default:
            return PanelListViewColumns::Empty;
    }
}

static NSString *ToKindIdentifier(PanelListViewColumns _kind) noexcept
{
    switch( _kind ) {
        case PanelListViewColumns::Empty:
            return @" ";
        case PanelListViewColumns::Filename:
            return @"A";
        case PanelListViewColumns::Extension:
            return @"G";
        case PanelListViewColumns::Size:
            return @"B";
        case PanelListViewColumns::DateCreated:
            return @"C";
        case PanelListViewColumns::DateAdded:
            return @"D";
        case PanelListViewColumns::DateModified:
            return @"E";
        case PanelListViewColumns::DateAccessed:
            return @"F";
        case PanelListViewColumns::Tags:
            return @"H";
    }
    return @" "; // shouldn't reach here
}
