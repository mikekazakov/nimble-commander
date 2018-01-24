// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/algo.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "../PanelData.h"
#include "../PanelDataSortMode.h"
#include "../PanelView.h"
#include "../IconsGenerator2.h"
#include "Layout.h"
#include "PanelListViewNameView.h"
#include "PanelListViewRowView.h"
#include "PanelListViewTableView.h"
#include "PanelListViewTableHeaderView.h"
#include "PanelListViewTableHeaderCell.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewSizeView.h"
#include "PanelListViewDateTimeView.h"
#include "PanelListViewDateFormatting.h"
#include "PanelListView.h"

using namespace nc::panel;

static const auto g_MaxStashedRows              = 50;
static const auto g_SortAscImage = [NSImage imageNamed:@"NSAscendingSortIndicator"];
static const auto g_SortDescImage = [NSImage imageNamed:@"NSDescendingSortIndicator"];

// identifiers legenda:
// A - Name
// B - Size
// C - Date created
// D - Date added
// E - Date modified

static PanelListViewColumns IdentifierToKind( unsigned char _letter );

void DrawTableVerticalSeparatorForView(NSView *v)
{
    if( auto t = objc_cast<NSTableView>(v.superview.superview) ) {
        if( t.gridStyleMask & NSTableViewSolidVerticalGridLineMask ) {
            if( t.gridColor && t.gridColor != NSColor.clearColor ) {
                const auto bounds = v.bounds;
                const auto rc = NSMakeRect(ceil(bounds.size.width)-1,
                                           0,
                                           1,
                                           bounds.size.height);
                
                // don't draw vertical line near table view's edge
                const auto trc = [t convertRect:rc fromView:v];
                if( trc.origin.x < t.bounds.size.width - 1 ) {
                    [t.gridColor set];
                    NSRectFill(rc); // support alpha?
                }
            }
        }
    }
}

@interface PanelListView()

@property (nonatomic) PanelListViewDateFormatting::Style dateCreatedFormattingStyle;
@property (nonatomic) PanelListViewDateFormatting::Style dateAddedFormattingStyle;
@property (nonatomic) PanelListViewDateFormatting::Style dateModifiedFormattingStyle;


@end


@implementation PanelListView
{
    NSScrollView                       *m_ScrollView;
    PanelListViewTableView             *m_TableView;
    data::Model                        *m_Data;
    __weak PanelView                   *m_PanelView;
    PanelListViewGeometry               m_Geometry;
    IconsGenerator2                    *m_IconsGenerator;
    NSTableColumn                      *m_NameColumn;
    NSTableColumn                      *m_SizeColumn;
    NSTableColumn                      *m_DateCreatedColumn;
    NSTableColumn                      *m_DateAddedColumn;
    NSTableColumn                      *m_DateModifiedColumn;
    PanelListViewDateFormatting::Style  m_DateCreatedFormattingStyle;
    PanelListViewDateFormatting::Style  m_DateAddedFormattingStyle;
    PanelListViewDateFormatting::Style  m_DateModifiedFormattingStyle;
    
    stack<PanelListViewRowView*>        m_RowsStash;
    
    data::SortMode                      m_SortMode;
    function<void(data::SortMode)>      m_SortModeChangeCallback;
    
    PanelListViewColumnsLayout          m_AssignedLayout;
    ThemesManager::ObservationTicket    m_ThemeObservation;
}

@synthesize dateCreatedFormattingStyle = m_DateCreatedFormattingStyle;
@synthesize dateAddedFormattingStyle = m_DateAddedFormattingStyle;
@synthesize dateModifiedFormattingStyle = m_DateModifiedFormattingStyle;
@synthesize sortMode = m_SortMode;
@synthesize sortModeChangeCallback = m_SortModeChangeCallback;

- (id) initWithFrame:(NSRect)frameRect andIC:(IconsGenerator2&)_ic
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_IconsGenerator = &_ic;
        
        [self calculateItemLayout];
        
        m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_ScrollView.wantsLayer = true;
        m_ScrollView.layer.drawsAsynchronously = false;
        m_ScrollView.contentView.copiesOnScroll = true;
        m_ScrollView.hasVerticalScroller = true;
        m_ScrollView.hasHorizontalScroller = true;
        m_ScrollView.borderType = NSNoBorder;
        m_ScrollView.drawsBackground = true;
        m_ScrollView.backgroundColor = CurrentTheme().FilePanelsListRegularEvenRowBackgroundColor();
        [self addSubview:m_ScrollView];
    
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ScrollView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(-1)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];

        m_TableView = [[PanelListViewTableView alloc] initWithFrame:frameRect];
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
        m_TableView.gridStyleMask = NSTableViewSolidVerticalGridLineMask;
        m_TableView.gridColor = CurrentTheme().FilePanelsListGridColor();
        m_TableView.headerView = [[PanelListViewTableHeaderView alloc] init];
        [self setupColumns];

        
        m_ScrollView.documentView = m_TableView;
        
        __weak PanelListView* weak_self = self;
        m_IconsGenerator->SetUpdateCallback([=](uint16_t _icon_no, NSImage* _icon){
            if( auto strong_self = weak_self )
                [strong_self onIconUpdated:_icon_no image:_icon];
        });
        m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::FilePanelsList |
            ThemesManager::Notifications::FilePanelsGeneral, [weak_self]{
            if( auto strong_self = weak_self )
                [strong_self handleThemeChanges];
        });
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
    }
    return self;
}

- (void) setupColumns
{
    if( (m_NameColumn = [[NSTableColumn alloc] initWithIdentifier:@"A"]) ) {
        m_NameColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
        m_NameColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_NAME", "");
        m_NameColumn.width = 200;
        m_NameColumn.minWidth = 180;
        m_NameColumn.maxWidth = 2000;
        m_NameColumn.headerCell.alignment = NSTextAlignmentLeft;
        m_NameColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
        [m_NameColumn addObserver:self forKeyPath:@"width" options:0 context:NULL];
    }
    if( (m_SizeColumn = [[NSTableColumn alloc] initWithIdentifier:@"B"]) ) {
        m_SizeColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
        m_SizeColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_SIZE", "");
        m_SizeColumn.width = 90;
        m_SizeColumn.minWidth = 75;
        m_SizeColumn.maxWidth = 110;
        m_SizeColumn.headerCell.alignment = NSTextAlignmentRight;
        m_SizeColumn.resizingMask = NSTableColumnUserResizingMask;
        [m_SizeColumn addObserver:self forKeyPath:@"width" options:0 context:NULL];
    }
    if( (m_DateCreatedColumn = [[NSTableColumn alloc] initWithIdentifier:@"C"]) ) {
        m_DateCreatedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
        m_DateCreatedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_CREATED", "");
        m_DateCreatedColumn.width = 90;
        m_DateCreatedColumn.minWidth = 75;
        m_DateCreatedColumn.maxWidth = 300;
        m_DateCreatedColumn.headerCell.alignment = NSTextAlignmentLeft;
        m_DateCreatedColumn.resizingMask = NSTableColumnUserResizingMask;
        [m_DateCreatedColumn addObserver:self forKeyPath:@"width" options:0 context:NULL];
        [self widthDidChangeForColumn:m_DateCreatedColumn];
    }
    if( (m_DateAddedColumn = [[NSTableColumn alloc] initWithIdentifier:@"D"]) ) {
        m_DateAddedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
        m_DateAddedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_ADDED", "");
        m_DateAddedColumn.width = 90;
        m_DateAddedColumn.minWidth = 75;
        m_DateAddedColumn.maxWidth = 300;
        m_DateAddedColumn.headerCell.alignment = NSTextAlignmentLeft;
        m_DateAddedColumn.resizingMask = NSTableColumnUserResizingMask;
        [m_DateAddedColumn addObserver:self forKeyPath:@"width" options:0 context:NULL];
        [self widthDidChangeForColumn:m_DateAddedColumn];
    }
    if( (m_DateModifiedColumn = [[NSTableColumn alloc] initWithIdentifier:@"E"]) ) {
        m_DateModifiedColumn.headerCell = [[PanelListViewTableHeaderCell alloc] init];
        m_DateModifiedColumn.title = NSLocalizedString(@"__PANELVIEW_LIST_COLUMN_TITLE_DATE_MODIFIED", "");
        m_DateModifiedColumn.width = 90;
        m_DateModifiedColumn.minWidth = 75;
        m_DateModifiedColumn.maxWidth = 300;
        m_DateModifiedColumn.headerCell.alignment = NSTextAlignmentLeft;
        m_DateModifiedColumn.resizingMask = NSTableColumnUserResizingMask;
        [m_DateModifiedColumn addObserver:self forKeyPath:@"width" options:0 context:NULL];
        [self widthDidChangeForColumn:m_DateModifiedColumn];
    }
}

-(void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [m_PanelView removeObserver:self forKeyPath:@"active"];
    [m_NameColumn removeObserver:self forKeyPath:@"width"];
    [m_SizeColumn removeObserver:self forKeyPath:@"width"];
    [m_DateCreatedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateAddedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateModifiedColumn removeObserver:self forKeyPath:@"width"];
}

- (void)viewDidMoveToSuperview
{
    if( auto pv = objc_cast<PanelView>(self.superview) ) {
        m_PanelView = pv;
        [pv addObserver:self forKeyPath:@"active" options:0 context:NULL];
        [self observeValueForKeyPath:@"active" ofObject:pv change:nil context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if( object == m_PanelView && [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        [m_TableView enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rv, NSInteger row) {
            if( auto v = objc_cast<PanelListViewRowView>(rv) )
                v.panelActive = active;
        }];
    }
    if( [keyPath isEqualToString:@"width"] ) {
        if( auto c = objc_cast<NSTableColumn>(object) )
            [self widthDidChangeForColumn:c];
    }
}

- (void)widthDidChangeForColumn:(NSTableColumn*)_column
{
    using df = PanelListViewDateFormatting;
    if( _column == m_DateCreatedColumn ) {
        const auto style = df::SuitableStyleForWidth( (int)m_DateCreatedColumn.width, self.font );
        self.dateCreatedFormattingStyle = style;
    }
    if( _column == m_DateAddedColumn ) {
        const auto style = df::SuitableStyleForWidth( (int)m_DateAddedColumn.width, self.font );
        self.dateAddedFormattingStyle = style;
    }
    if( _column == m_DateModifiedColumn ) {
        const auto style = df::SuitableStyleForWidth( (int)m_DateModifiedColumn.width, self.font );
        self.dateModifiedFormattingStyle = style;
    }
    [self notifyLastColumnToRedraw];
}

- (void)tableViewColumnDidResize:(NSNotification *)notification
{
    if( m_TableView.headerView.resizedColumn < 0 )
        return;

    [self.panelView notifyAboutPresentationLayoutChange];
}

- (void)tableViewColumnDidMove:(NSNotification *)notification
{
    [self.panelView notifyAboutPresentationLayoutChange];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Data ? m_Data->SortedEntriesCount() : 0;
}

- (void) calculateItemLayout
{
    m_Geometry = PanelListViewGeometry( CurrentTheme().FilePanelsListFont(),
                                        m_AssignedLayout.icon_scale );

    m_IconsGenerator->SetIconSize( m_Geometry.IconSize() );
    
    if( m_TableView )
        m_TableView.rowHeight = m_Geometry.LineHeight();
}

template <typename View>
static View *RetrieveOrSpawnView(NSTableView *_tv, NSString *_identifier)
{
    if( View *v = [_tv makeViewWithIdentifier:_identifier owner:nil] )
        return v;
    auto v = [[View alloc] initWithFrame:NSRect()];
    v.identifier = _identifier;
    return v;
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row
{
    if( !m_Data )
        return nil;
    
    const auto abstract_row_view = [m_TableView rowViewAtRow:row makeIfNecessary:false];
    if( const auto row_view = objc_cast<PanelListViewRowView>(abstract_row_view) ) {
        if( const auto vfs_item = row_view.item ) {
            const auto identifier = tableColumn.identifier;
            const auto kind = IdentifierToKind( (uint8_t)[identifier characterAtIndex:0] );
            if( kind == PanelListViewColumns::Filename ) {
                auto nv = RetrieveOrSpawnView<PanelListViewNameView>(tableView, identifier);
                if( m_Data->IsValidSortPosition((int)row) ) {
                    auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
                    [self fillDataForNameView:nv withItem:vfs_item andVD:vd];
                }
                return nv;
            }
            if( kind == PanelListViewColumns::Size ) {
                auto sv = RetrieveOrSpawnView<PanelListViewSizeView>(tableView, identifier);
                if( m_Data->IsValidSortPosition((int)row) ) {
                    auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
                    [self fillDataForSizeView:sv withItem:vfs_item andVD:vd];
                }
                return sv;
            }
            if( kind == PanelListViewColumns::DateCreated ) {
                auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(tableView, identifier);
                [self fillDataForDateCreatedView:dv withItem:vfs_item];
                return dv;
            }
            if( kind == PanelListViewColumns::DateAdded ) {
                auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(tableView, identifier);
                [self fillDataForDateAddedView:dv withItem:vfs_item];
                return dv;
            }
            if( kind == PanelListViewColumns::DateModified ) {
                auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(tableView, identifier);
                [self fillDataForDateModifiedView:dv withItem:vfs_item];
                return dv;
            }
        }
    }
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)rowIndex
{
    if( !m_Data )
        return nil;

    const auto row = (int)rowIndex;
    if( auto item = m_Data->EntryAtSortPosition(row) ) {
        auto &vd = m_Data->VolatileDataAtSortPosition(row);
        
        PanelListViewRowView *row_view;
        if( !m_RowsStash.empty() ) {
            row_view = m_RowsStash.top();
            m_RowsStash.pop();
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

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if( row < 0 && m_RowsStash.size() < g_MaxStashedRows )
        if( auto r = objc_cast<PanelListViewRowView>(rowView) ) {
            r.item = VFSListingItem();
            m_RowsStash.push( r );
        }
}

- (void) fillDataForNameView:(PanelListViewNameView*)_view
                    withItem:(const VFSListingItem&)_item
                       andVD:(data::ItemVolatileData&)_vd
{
    NSImage* icon = m_IconsGenerator->ImageFor(_item, _vd);
    [_view setFilename:_item.DisplayNameNS()];
    [_view setIcon:icon];
}

- (void) fillDataForSizeView:(PanelListViewSizeView*)_view
                    withItem:(const VFSListingItem&)_item
                       andVD:(data::ItemVolatileData&)_vd
{
    [_view setSizeWithItem:_item andVD:_vd];
}

- (void) fillDataForDateCreatedView:(PanelListViewDateTimeView*)_view
                           withItem:(const VFSListingItem&)_item
{
    _view.time = _item.BTime();
    _view.style = m_DateCreatedFormattingStyle;
}

- (void) fillDataForDateAddedView:(PanelListViewDateTimeView*)_view
                         withItem:(const VFSListingItem&)_item
{
    _view.time = _item.HasAddTime() ? _item.AddTime() : -1;
    _view.style = m_DateAddedFormattingStyle;
}

- (void) fillDataForDateModifiedView:(PanelListViewDateTimeView*)_view
                            withItem:(const VFSListingItem&)_item
{
    _view.time = _item.MTime();
    _view.style = m_DateModifiedFormattingStyle;
}

- (void) dataChanged
{
//    MachTimeBenchmark mtb;
    const auto old_rows_count = (int)m_TableView.numberOfRows;
    const auto new_rows_count = m_Data->SortedEntriesCount();

    m_IconsGenerator->SyncDiscardedAndOutdated( *m_Data );
    
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *row_view, NSInteger row) {
        if( row >= new_rows_count )
            return;

        if( auto item = m_Data->EntryAtSortPosition((int)row) ) {
            auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
            row_view.item = item;
            row_view.vd = vd;
            for( NSView *v in row_view.subviews ) {
                NSString *identifier = v.identifier;
                if( identifier.length == 0 )
                    continue;
                const auto col_id = [v.identifier characterAtIndex:0];
                if( col_id == 'A' ) [self fillDataForNameView:(PanelListViewNameView*)v
                                                     withItem:item
                                                        andVD:vd];
                if( col_id == 'B' ) [self fillDataForSizeView:(PanelListViewSizeView*)v
                                                     withItem:item
                                                        andVD:vd];
                if( col_id == 'C' ) [self fillDataForDateCreatedView:(PanelListViewDateTimeView*)v
                                                            withItem:item];
                if( col_id == 'D' ) [self fillDataForDateAddedView:(PanelListViewDateTimeView*)v
                                                          withItem:item];
                if( col_id == 'E' ) [self fillDataForDateModifiedView:(PanelListViewDateTimeView*)v
                                                             withItem:item];
            }
        }
    }];

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

- (void) syncVolatileData
{
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
        if( m_Data->IsValidSortPosition((int)row) )
            rowView.vd = m_Data->VolatileDataAtSortPosition((int)row);
    }];
}

- (void) setData:(data::Model*)_data
{
    m_Data = _data;
    [self dataChanged];    
}

- (int)itemsInColumn
{
    return int(m_ScrollView.contentView.bounds.size.height / m_Geometry.LineHeight());
}

- (int) maxNumberOfVisibleItems
{
    return [self itemsInColumn];
}

- (int) cursorPosition
{
    return (int)m_TableView.selectedRow;
}

- (void)setCursorPosition:(int)cursorPosition
{
    if( cursorPosition >= 0 ) {
        [m_TableView selectRowIndexes:[NSIndexSet indexSetWithIndex:cursorPosition]
                 byExtendingSelection:false];
        dispatch_to_main_queue([=]{
            [m_TableView scrollRowToVisible:cursorPosition];
        });
    }
    else {
        [m_TableView selectRowIndexes:[NSIndexSet indexSet]
                 byExtendingSelection:false];
    }
}

- (const PanelListViewGeometry&) geometry
{
    return m_Geometry;
}

- (NSFont*) font
{
//    return [NSFont systemFontOfSize:13];
    return CurrentTheme().FilePanelsListFont();
}

- (void) onIconUpdated:(uint16_t)_icon_no image:(NSImage*)_image
{
    dispatch_assert_main_queue();
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
        const auto index = (int)row;
        if( m_Data->IsValidSortPosition(index) ) {
            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            if( vd.icon == _icon_no )
                rowView.nameView.icon = _image;
        }
    }];
}

//- (PanelListViewDateFormatting::Style) dateCreatedFormattingStyle
//{
//    return m_DateCreatedFormattingStyle;
//}

- (void) updateDateTimeViewAtColumn:(NSTableColumn*)_column withStyle:(PanelListViewDateFormatting::Style)_style
{
// use this!!!!
//m_TableView viewAtColumn:<#(NSInteger)#> row:<#(NSInteger)#> makeIfNecessary:<#(BOOL)#>
    
    const auto col_index = [m_TableView.tableColumns indexOfObject:_column];
    if( col_index != NSNotFound )
        [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
            if( auto v = objc_cast<PanelListViewDateTimeView>([rowView viewAtColumn:col_index]) )
                v.style = _style;
        }];
}

- (void) setDateCreatedFormattingStyle:(PanelListViewDateFormatting::Style)dateCreatedFormattingStyle
{
    if( m_DateCreatedFormattingStyle != dateCreatedFormattingStyle ) {
        m_DateCreatedFormattingStyle = dateCreatedFormattingStyle;
        [self updateDateTimeViewAtColumn:m_DateCreatedColumn withStyle:dateCreatedFormattingStyle];
    }
}

- (void) setDateAddedFormattingStyle:(PanelListViewDateFormatting::Style)dateAddedFormattingStyle
{
    if( m_DateAddedFormattingStyle != dateAddedFormattingStyle ) {
        m_DateAddedFormattingStyle = dateAddedFormattingStyle;
        [self updateDateTimeViewAtColumn:m_DateAddedColumn withStyle:dateAddedFormattingStyle];
    }
}

- (void) setDateModifiedFormattingStyle:(PanelListViewDateFormatting::Style)dateModifiedFormattingStyle
{
    if( m_DateModifiedFormattingStyle != dateModifiedFormattingStyle ) {
        m_DateModifiedFormattingStyle = dateModifiedFormattingStyle;
        [self updateDateTimeViewAtColumn:m_DateModifiedColumn withStyle:dateModifiedFormattingStyle];
    }
}

- (NSTableColumn*)columnByType:(PanelListViewColumns)_type
{
    switch( _type ) {
        case PanelListViewColumns::Filename:        return m_NameColumn;
        case PanelListViewColumns::Size:            return m_SizeColumn;
        case PanelListViewColumns::DateCreated:     return m_DateCreatedColumn;
        case PanelListViewColumns::DateAdded:       return m_DateAddedColumn;
        case PanelListViewColumns::DateModified:    return m_DateModifiedColumn;
        default: return nil;
    }
}

- (PanelListViewColumns)typeByColumn:(NSTableColumn*)_col
{
    if( _col == m_NameColumn )          return PanelListViewColumns::Filename;
    if( _col == m_SizeColumn )          return PanelListViewColumns::Size;
    if( _col == m_DateCreatedColumn )   return PanelListViewColumns::DateCreated;
    if( _col == m_DateAddedColumn )     return PanelListViewColumns::DateAdded;
    if( _col == m_DateModifiedColumn )  return PanelListViewColumns::DateModified;
    return PanelListViewColumns::Empty;
}

- (PanelListViewColumnsLayout)columnsLayout
{
    PanelListViewColumnsLayout l;
    l.icon_scale = m_AssignedLayout.icon_scale;
    for( NSTableColumn *tc in m_TableView.tableColumns) {
        PanelListViewColumnsLayout::Column c;
        c.kind = [self typeByColumn:tc];
        c.width = short(tc.width);
        l.columns.emplace_back( c );
    }
    return l;
}

- (void) setColumnsLayout:(PanelListViewColumnsLayout)columnsLayout
{
    if( columnsLayout == m_AssignedLayout )
        return;
    
    for( NSTableColumn *c in [m_TableView.tableColumns copy] )
        [m_TableView removeTableColumn:c];

    for( auto &c: columnsLayout.columns ) {
        if( NSTableColumn *tc = [self columnByType:c.kind] ) {
            if( c.min_width >= 0 )  tc.minWidth = c.min_width;
            if( c.max_width >= 0 )  tc.maxWidth = c.max_width;
            if( c.width >= 0 )      tc.width = c.width;

            [m_TableView addTableColumn:tc];
        }
    }
    
    m_AssignedLayout = columnsLayout;
    [m_TableView sizeToFit];
    [self calculateItemLayout];
    [self placeSortIndicator];
}

- (void) setSortMode:(data::SortMode)_mode
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
    
    auto set = [&]()->pair<NSImage*,NSTableColumn*>{
        using _ = data::SortMode;
        switch( m_SortMode.sort ) {
            case _::SortByName:         return {g_SortAscImage,     m_NameColumn};
            case _::SortByNameRev:      return {g_SortDescImage,    m_NameColumn};
            case _::SortBySize:         return {g_SortDescImage,    m_SizeColumn};
            case _::SortBySizeRev:      return {g_SortAscImage,     m_SizeColumn};
            case _::SortByBirthTime:    return {g_SortDescImage,    m_DateCreatedColumn};
            case _::SortByBirthTimeRev: return {g_SortAscImage,     m_DateCreatedColumn};
            case _::SortByModTime:      return {g_SortDescImage,    m_DateModifiedColumn};
            case _::SortByModTimeRev:   return {g_SortAscImage,     m_DateModifiedColumn};
            case _::SortByAddTime:      return {g_SortDescImage,    m_DateAddedColumn};
            case _::SortByAddTimeRev:   return {g_SortAscImage,     m_DateAddedColumn};
            default: return make_pair(nil, nil);
        }
    }();
    
    if( set.first && set.second )
        [m_TableView setIndicatorImage:set.first inTableColumn:set.second];
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
    auto proposed = m_SortMode;
    auto swp = [&]( data::SortMode::Mode _1st, data::SortMode::Mode _2nd ){
        proposed.sort = (proposed.sort == _1st ? _2nd : _1st );
    };

    if( tableColumn == m_NameColumn )
        swp(data::SortMode::SortByName, data::SortMode::SortByNameRev);
    if( tableColumn == m_SizeColumn )
        swp(data::SortMode::SortBySize, data::SortMode::SortBySizeRev);
    if( tableColumn == m_DateCreatedColumn )
        swp(data::SortMode::SortByBirthTime, data::SortMode::SortByBirthTimeRev);
    if( tableColumn == m_DateModifiedColumn )
        swp(data::SortMode::SortByModTime, data::SortMode::SortByModTimeRev);
    if( tableColumn == m_DateAddedColumn )
        swp(data::SortMode::SortByAddTime, data::SortMode::SortByAddTimeRev);
    
    if( proposed != m_SortMode && m_SortModeChangeCallback )
        m_SortModeChangeCallback(proposed);
}

- (void) notifyLastColumnToRedraw
{
    auto cn = m_TableView.numberOfColumns;
    if( !cn )
        return;
    
    for( int i = 0, e = (int)m_TableView.numberOfRows; i != e; ++i )
        [m_TableView viewAtColumn:cn-1 row:i makeIfNecessary:false].needsDisplay = true;
}

- (bool) isItemVisible:(int)_sorted_item_index
{
    CGRect visibleRect = m_ScrollView.contentView.visibleRect;
    NSRange range = [m_TableView rowsInRect:visibleRect];
    return NSLocationInRange(_sorted_item_index, range);
}

- (void) setupFieldEditor:(NSScrollView*)_editor forItemAtIndex:(int)_sorted_item_index
{
    if( PanelListViewRowView *rv = [m_TableView rowViewAtRow:_sorted_item_index makeIfNecessary:false] )
        [rv.nameView setupFieldEditor:_editor];
}

- (PanelView*)panelView
{
    return m_PanelView;
}

- (void) onPageUp:(NSEvent*)_event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y -= rect.size.height - m_TableView.headerView.bounds.size.height;
    [m_TableView scrollRectToVisible:rect];
}

- (void) onPageDown:(NSEvent*)_event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y += rect.size.height;
    [m_TableView scrollRectToVisible:rect];
}

- (void) onScrollToBeginning:(NSEvent*)_event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y = -m_TableView.headerView.bounds.size.height;
    [m_TableView scrollRectToVisible:rect];
}

- (void) onScrollToEnd:(NSEvent*)_event
{
    NSRect rect;
    rect = m_TableView.visibleRect;
    rect.origin.y = m_TableView.bounds.size.height -
                    m_TableView.visibleRect.size.height +
                    m_TableView.headerView.bounds.size.height;
    [m_TableView scrollRectToVisible:rect];
}

- (int) sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options
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

- (void) frameDidChange
{
    [self notifyLastColumnToRedraw];
}

- (BOOL)tableView:(NSTableView *)tableView
shouldReorderColumn:(NSInteger)columnIndex
         toColumn:(NSInteger)newColumnIndex
{
    return !(columnIndex == 0 || newColumnIndex == 0);
}

- (NSMenu*) columnsSelectionMenu
{
    if( auto nib = [[NSNib alloc] initWithNibNamed:@"PanelListViewColumnsMenu" bundle:nil] ) {
        NSArray *objects;
        if( [nib instantiateWithOwner:nil topLevelObjects:&objects] )
            for( id i in objects )
                if( auto menu = objc_cast<NSMenu>(i) )
                    return menu;
    }
    return nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if( menuItem.action == @selector(onToggleColumnVisibilty:) ) {
        const auto kind = IdentifierToKind( (uint8_t)[menuItem.identifier characterAtIndex:0] );
        const auto column = [self columnByType:kind];
        menuItem.state = column && [m_TableView.tableColumns containsObject:column];
    }
    return true;
}

- (IBAction)onToggleColumnVisibilty:(id)sender
{
    if( auto menu_item = objc_cast<NSMenuItem>(sender) ) {
        const auto kind = IdentifierToKind( (uint8_t)[menu_item.identifier characterAtIndex:0] );
        
        if( kind == PanelListViewColumns::Empty )
            return;
        
        auto layout = self.columnsLayout;
        
        const auto t = find_if(begin(layout.columns),
                               end(layout.columns),
                               [&](const auto &_i){ return _i.kind == kind;});

        if( t != end(layout.columns) ) {
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

static PanelListViewColumns IdentifierToKind( unsigned char _letter )
{
    switch (_letter) {
        case 'A':   return PanelListViewColumns::Filename;
        case 'B':   return PanelListViewColumns::Size;
        case 'C':   return PanelListViewColumns::DateCreated;
        case 'D':   return PanelListViewColumns::DateAdded;
        case 'E':   return PanelListViewColumns::DateModified;
        default:    return PanelListViewColumns::Empty;
    }
}

- (void) handleThemeChanges
{
    auto cp = self.cursorPosition;
    [self calculateItemLayout];
    [m_TableView reloadData];
    self.cursorPosition = cp;
    m_TableView.gridColor = CurrentTheme().FilePanelsListGridColor();
    m_ScrollView.backgroundColor = CurrentTheme().FilePanelsListRegularEvenRowBackgroundColor();
}

@end
