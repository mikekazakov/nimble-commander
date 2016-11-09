#include "../../../Files/Config.h"
#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/PanelData.h"
#include "../../../Files/PanelView.h"
#include "List/PanelListViewNameView.h"
#include "List/PanelListViewRowView.h"
#include "List/PanelListViewTableView.h"
#include "List/PanelListViewGeometry.h"
#include "List/PanelListViewSizeView.h"
#include "List/PanelListViewDateTimeView.h"
#include "List/PanelListViewDateFormatting.h"
#include "IconsGenerator2.h"
#include "PanelListView.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";
static const auto g_MaxStashedRows              = 50;

// identifiers legenda:
// A - Name
// B - Size
// C - Date created
// D - Date added
// E - Date modified


//bool            HasATime()          const;
//time_t          ATime()             const;
//
//bool            HasMTime()          const;
//time_t          MTime()             const;
//
//bool            HasCTime()          const;
//time_t          CTime()             const;
//
//bool            HasBTime()          const;
//time_t          BTime()             const;


@interface PanelListView()

@property (nonatomic) PanelListViewDateFormatting::Style dateCreatedFormattingStyle;
@property (nonatomic) PanelListViewDateFormatting::Style dateAddedFormattingStyle;
@property (nonatomic) PanelListViewDateFormatting::Style dateModifiedFormattingStyle;


@end


@implementation PanelListView
{
    NSScrollView                       *m_ScrollView;
    PanelListViewTableView             *m_TableView;
    PanelData                          *m_Data;
    __weak PanelView                   *m_PanelView;
    PanelListViewGeometry               m_Geometry;
    IconsGenerator2                     m_IconsGenerator;
    NSTableColumn                      *m_NameColumn;
    NSTableColumn                      *m_DateCreatedColumn;
    NSTableColumn                      *m_DateAddedColumn;
    NSTableColumn                      *m_DateModifiedColumn;
    PanelListViewDateFormatting::Style  m_DateCreatedFormattingStyle;
    PanelListViewDateFormatting::Style  m_DateAddedFormattingStyle;
    PanelListViewDateFormatting::Style  m_DateModifiedFormattingStyle;
    
    dispatch_group_t                    m_BatchUpdateGroup;
    dispatch_queue_t                    m_BatchUpdateQueue;
    bool                                m_IsBatchUpdate;
    
    stack<PanelListViewRowView*>        m_RowsStash;
}

@synthesize dateCreatedFormattingStyle = m_DateCreatedFormattingStyle;
@synthesize dateAddedFormattingStyle = m_DateAddedFormattingStyle;
@synthesize dateModifiedFormattingStyle = m_DateModifiedFormattingStyle;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_BatchUpdateGroup = dispatch_group_create();
        m_BatchUpdateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        m_IsBatchUpdate = false;
        
        m_Geometry = PanelListViewGeometry( [NSFont systemFontOfSize:13] );
        
        m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_ScrollView.wantsLayer = true;
        m_ScrollView.layer.drawsAsynchronously = true;
        m_ScrollView.contentView.copiesOnScroll = true;
        m_ScrollView.hasVerticalScroller = true;
        m_ScrollView.borderType = NSNoBorder;
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
        m_TableView.usesAlternatingRowBackgroundColors = true;
        m_TableView.rowSizeStyle = NSTableViewRowSizeStyleCustom;
        m_TableView.rowHeight = m_Geometry.LineHeight();
        m_TableView.intercellSpacing = NSMakeSize(0, 0);
        [self setupColumns];

        
        m_ScrollView.documentView = m_TableView;
        
        __weak PanelListView* weak_self = self;
        m_IconsGenerator.SetUpdateCallback([=](uint16_t _icon_no, NSImageRep* _icon){
            if( auto strong_self = weak_self )
                [strong_self onIconUpdated:_icon_no image:_icon];
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
    if( auto col = [[NSTableColumn alloc] initWithIdentifier:@"A"] ) {
        col.title = @"Name";
        col.width = 200;
        [m_TableView addTableColumn:col];
        m_NameColumn = col;
    }
    if( auto col = [[NSTableColumn alloc] initWithIdentifier:@"B"] ) {
        col.title = @"Size";
        col.width = 90;
        col.minWidth = 75;
        col.maxWidth = 110;
        col.headerCell.alignment = NSTextAlignmentRight;
        [m_TableView addTableColumn:col];
    }
    if( auto col = [[NSTableColumn alloc] initWithIdentifier:@"C"] ) {
        col.title = @"Date Created";
        col.width = 90;
        col.minWidth = 75;
        col.maxWidth = 300;
        [m_TableView addTableColumn:col];
        m_DateCreatedColumn = col;
        [col addObserver:self forKeyPath:@"width" options:0 context:NULL];
        [self observeValueForKeyPath:@"width" ofObject:col change:nil context:nil];
//        m_DateCreatedFormattingStyle = PanelListViewDateFormatting::Style::Long;
    }
    if( auto col = [[NSTableColumn alloc] initWithIdentifier:@"D"] ) {
        col.title = @"Date Added";
        col.width = 90;
        col.minWidth = 75;
        col.maxWidth = 300;
        [m_TableView addTableColumn:col];
        m_DateAddedColumn = col;
        [col addObserver:self forKeyPath:@"width" options:0 context:NULL];
        [self observeValueForKeyPath:@"width" ofObject:col change:nil context:nil];
//        m_DateAddedFormattingStyle = PanelListViewDateFormatting::Style::Long;
    }
    if( auto col = [[NSTableColumn alloc] initWithIdentifier:@"E"] ) {
        col.title = @"Date Modified";
        col.width = 90;
        col.minWidth = 75;
        col.maxWidth = 300;
        [m_TableView addTableColumn:col];
        m_DateModifiedColumn = col;
        [col addObserver:self forKeyPath:@"width" options:0 context:NULL];
        [self observeValueForKeyPath:@"width" ofObject:col change:nil context:nil];
//        m_DateModifiedFormattingStyle = PanelListViewDateFormatting::Style::Long;
    }
}

-(void) dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
    [m_DateCreatedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateAddedColumn removeObserver:self forKeyPath:@"width"];
    [m_DateModifiedColumn removeObserver:self forKeyPath:@"width"];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidMoveToSuperview
{
    if( auto pv = objc_cast<PanelView>(self.superview) ) {
        m_PanelView = pv;
        [pv addObserver:self forKeyPath:@"active" options:0 context:NULL];
        [self observeValueForKeyPath:@"active" ofObject:pv change:nil context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( object == m_PanelView && [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
            rowView.panelActive = active;
        }];
    }
    if( [keyPath isEqualToString:@"width"] ) {
        using df = PanelListViewDateFormatting;
        if( object == m_DateCreatedColumn )
            self.dateCreatedFormattingStyle = df::SuitableStyleForWidth( m_DateCreatedColumn.width, self.font );
        if( object == m_DateAddedColumn )
            self.dateAddedFormattingStyle = df::SuitableStyleForWidth( m_DateAddedColumn.width, self.font );
        if( object == m_DateModifiedColumn )
            self.dateModifiedFormattingStyle = df::SuitableStyleForWidth( m_DateModifiedColumn.width, self.font );
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Data ? m_Data->SortedEntriesCount() : 0;
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

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if( !m_Data )
        return nil;
    
    if( auto w = objc_cast<PanelListViewRowView>([tableView rowViewAtRow:row makeIfNecessary:false]) ) {
        if( auto vfs_item = w.item ) {
            NSString *identifier = tableColumn.identifier;
            
            const auto col_id = [identifier characterAtIndex:0];
            if( col_id == 'A' ) {
                auto nv = RetrieveOrSpawnView<PanelListViewNameView>(tableView, identifier);
                auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
                [self fillDataForNameView:nv withItem:vfs_item andVD:vd];
//- (void) fillDataForNameView:(PanelListViewNameView*)_view withItem:(const VFSListingItem&)_item andVD:(PanelData::PanelVolatileData&)_vd
//                NSImageRep* icon = m_IconsGenerator.ImageFor(vfs_item, vd);
//                [nv setFilename:vfs_item.NSDisplayName()];
//                [nv setIcon:icon];
                return nv;
            }
            if( col_id == 'B' ) {
                return RetrieveOrSpawnView<PanelListViewSizeView>(tableView, identifier);
            }
            if( col_id == 'C' ) {
                auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(tableView, identifier);
                [self fillDataForDateCreatedView:dv withItem:vfs_item];
//                - (void) fillDataForDateCreatedView:(PanelListViewDateTimeView*)_view withItem:(const VFSListingItem&)_item
                
//                dv.time = vfs_item.BTime();
//                dv.style = m_DateCreatedFormattingStyle;
                return dv;
            }
            if( col_id == 'D' ) {
                auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(tableView, identifier);
                [self fillDataForDateAddedView:dv withItem:vfs_item];
//                dv.time = vfs_item.BTime();
//                dv.style = m_DateAddedFormattingStyle;
                return dv;
            }
            if( col_id == 'E' ) {
                auto dv = RetrieveOrSpawnView<PanelListViewDateTimeView>(tableView, identifier);
                [self fillDataForDateModifiedView:dv withItem:vfs_item];
//                dv.time = vfs_item.MTime();
//                dv.style = m_DateModifiedFormattingStyle;
                return dv;
            }
        }
    }
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)rowIndex
{
    const auto row = (int)rowIndex;
    if( m_Data ) {
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

- (void) fillDataForNameView:(PanelListViewNameView*)_view withItem:(const VFSListingItem&)_item andVD:(PanelData::PanelVolatileData&)_vd
{
    NSImageRep* icon = m_IconsGenerator.ImageFor(_item, _vd);
    [_view setFilename:_item.NSDisplayName()];
    [_view setIcon:icon];
}

- (void) fillDataForDateCreatedView:(PanelListViewDateTimeView*)_view withItem:(const VFSListingItem&)_item
{
    if( m_IsBatchUpdate )
        dispatch_group_async(m_BatchUpdateGroup, m_BatchUpdateQueue, [=]{
            _view.time = _item.BTime();
            _view.style = m_DateCreatedFormattingStyle;
        });
    else {
        _view.time = _item.BTime();
        _view.style = m_DateCreatedFormattingStyle;
    }
}

- (void) fillDataForDateAddedView:(PanelListViewDateTimeView*)_view  withItem:(const VFSListingItem&)_item
{
    if( m_IsBatchUpdate )
        dispatch_group_async(m_BatchUpdateGroup, m_BatchUpdateQueue, [=]{
            _view.time = _item.HasAddTime() ? _item.AddTime() : -1;
            _view.style = m_DateAddedFormattingStyle;
        });
    else {
        _view.time = _item.HasAddTime() ? _item.AddTime() : -1;
        _view.style = m_DateAddedFormattingStyle;
    }
}

- (void) fillDataForDateModifiedView:(PanelListViewDateTimeView*)_view  withItem:(const VFSListingItem&)_item
{
    if( m_IsBatchUpdate )
        dispatch_group_async(m_BatchUpdateGroup, m_BatchUpdateQueue, [=]{
            _view.time = _item.MTime();
            _view.style = m_DateModifiedFormattingStyle;
        });
    else {
        _view.time = _item.MTime();
        _view.style = m_DateModifiedFormattingStyle;
    }
}

- (void) dataChanged
{
//    MachTimeBenchmark mtb;
    const auto old_rows_count = (int)m_TableView.numberOfRows;
    const auto new_rows_count = m_Data->SortedEntriesCount();

    m_IconsGenerator.SyncDiscardedAndOutdated( *m_Data );
    
    m_IsBatchUpdate = true;
    
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
                if( col_id == 'A' )     [self fillDataForNameView:(PanelListViewNameView*)v withItem:item andVD:vd];
                if( col_id == 'C' )     [self fillDataForDateCreatedView:(PanelListViewDateTimeView*)v withItem:item];
                if( col_id == 'D' )     [self fillDataForDateAddedView:(PanelListViewDateTimeView*)v withItem:item];
                if( col_id == 'E' )     [self fillDataForDateModifiedView:(PanelListViewDateTimeView*)v withItem:item];
            }
        }
    }];

    if( old_rows_count < new_rows_count )
        [m_TableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(old_rows_count, new_rows_count - old_rows_count)]
                           withAnimation:NSTableViewAnimationEffectNone];
    else if( old_rows_count > new_rows_count )
        [m_TableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(new_rows_count, old_rows_count - new_rows_count)]
                           withAnimation:NSTableViewAnimationEffectNone];
    
    dispatch_group_wait(m_BatchUpdateGroup, DISPATCH_TIME_FOREVER);
    m_IsBatchUpdate = false;
    
//     mtb.ResetMicro();
}

- (void) syncVolatileData
{
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
        rowView.vd = m_Data->VolatileDataAtSortPosition((int)row);
    }];
}

- (void) setData:(PanelData*)_data
{
    m_Data = _data;
    [self dataChanged];    
}

- (int)itemsInColumn
{
    return m_ScrollView.contentView.bounds.size.height / m_Geometry.LineHeight();
//    return 0;
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

- (void)frameDidChange
{
//    MachTimeBenchmark mtb;
    [m_ScrollView layoutSubtreeIfNeeded];
//    mtb.ResetMicro();
    
}


//
//@property (nonatomic, readonly) int itemsInColumn;
//@property (nonatomic) int cursorPosition;

- (const vector<PanelViewPresentationItemsColoringRule>&) coloringRules
{
//    return g_ColoringRules;
    static vector<PanelViewPresentationItemsColoringRule> rules;
    static once_flag once;
    call_once(once,[]{
        auto cr = GlobalConfig().Get(g_ConfigColoring);
        if( cr.IsArray() )
            for( auto i = cr.Begin(), e = cr.End(); i != e; ++i )
                rules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
        rules.emplace_back(); // always have a default ("others") non-filtering filter at the back
    });
    return rules;
}

- (const PanelListViewGeometry&) geometry
{
    return m_Geometry;
}

- (NSFont*) font
{
    return [NSFont systemFontOfSize:13];
}

- (void) onIconUpdated:(uint16_t)_icon_no image:(NSImageRep*)_image
{
    dispatch_assert_main_queue();
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
//        rowView.vd = m_Data->VolatileDataAtSortPosition((int)row);
        const auto index = (int)row;
        auto &vd = m_Data->VolatileDataAtSortPosition(index);
        if( vd.icon == _icon_no ) {
//                        [i setIcon:_image];
            rowView.nameView.icon = _image;
//            break;
        }
        
    }];
    
    
//    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
//        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
//            const auto index = (int)index_path.item;
//            auto &vd = m_Data->VolatileDataAtSortPosition(index);
//            if( vd.icon == _icon_no ) {
//                [i setIcon:_image];
//                break;
//            }
//        }
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

@end
