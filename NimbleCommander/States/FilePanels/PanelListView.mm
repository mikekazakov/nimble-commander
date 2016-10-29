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


// identifiers legenda:
// A - Name
// B - Size
// C - Date created


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
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
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
//        @property NSSize intercellSpacing;
        
        
//        @property NSTableViewRowSizeStyle rowSizeStyle NS_AVAILABLE_MAC(10_7);
//        
//        /* Returns the effective row size style for the table. If the rowSizeStyle is NSTableViewRowSizeStyleDefault, then this method returns the default size for this particular table.
//         */
//        @property (readonly) NSTableViewRowSizeStyle effectiveRowSizeStyle NS_AVAILABLE_MAC(10_7);
//        
//        
//        /* Get and set the rowHeight. The value must be greater than 0. Calling -setRowHeight: with a non-pixel aligning (fractional) value will be forced to a pixel aligning (integral) value. For variable row height tableViews (ones that have the delegate implement -tableView:heightOfRow:), -rowHeight will be used to draw alternating rows past the last row in the tableView. The actual -rectOfRow: is equal to the -rowHeight plus the intercellSpacing.height. The default value is 17.0 for applications linked on 10.5 and higher (the height acceptable for [NSFont systemFontSize]). The default value is 16.0 for 10.4 and lower.
//         */
//        @property CGFloat rowHeight;

        
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
            col.headerCell.alignment = NSTextAlignmentRight;
            [m_TableView addTableColumn:col];
            m_DateCreatedColumn = col;
            [col addObserver:self forKeyPath:@"width" options:0 context:NULL];
        }
        
        
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
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(tableColumnsResized:)
//                                                     name:NSTableViewColumnDidResizeNotification
//                                                   object:m_TableView];
        
    }
    return self;
}

-(void) dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
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
//        for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
//            [i setPanelActive:active];
        [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
            rowView.panelActive = active;
        }];
    }
    if( object == m_DateCreatedColumn && [keyPath isEqualToString:@"width"] ) {
//        cout << "!!!" << endl;
        auto new_width = m_DateCreatedColumn.width;
        auto style = PanelListViewDateFormatting::SuitableStyleForWidth( new_width, self.font );
        
//        - (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
//            NSUInteger index = [[aTableView tableColumns] indexOf:aTableColumn];
//            ...
//        }
        auto col_index = [m_TableView.tableColumns indexOfObject:m_DateCreatedColumn];
        if( col_index != NSNotFound ) {
            [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
//                rowView.vd = m_Data->VolatileDataAtSortPosition((int)row);
//- (nullable id)viewAtColumn:(NSInteger)column;
                if( auto v = objc_cast<PanelListViewDateTimeView>([rowView viewAtColumn:col_index]) ) {
                    v.style = style;
                }
            }];
            
            
        }
        
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Data ? m_Data->SortedDirectoryEntries().size() : 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if( !m_Data )
        return nil;
    
    if( PanelListViewRowView *w = objc_cast<PanelListViewRowView>([tableView rowViewAtRow:row makeIfNecessary:false]) ) {
        
        if( auto vfs_item = w.item ) {
            NSString *identifier = tableColumn.identifier;
            
            unichar col_id = [identifier characterAtIndex:0];
            if( col_id == 'A' ) {
                PanelListViewNameView *nv = [tableView makeViewWithIdentifier:identifier owner:self];
                if( !nv ) {
                    nv = [[PanelListViewNameView alloc] initWithFrame:NSRect()];
                    nv.identifier = identifier;
                }
                
//                if( auto vfs_item = m_Data->EntryAtSortPosition(index) ) {
//                    [item setItem:vfs_item];
//                    
                auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
                NSImageRep* icon = m_IconsGenerator.ImageFor(vfs_item, vd);
                
                [nv setFilename:vfs_item.NSDisplayName()];
                [nv setIcon:icon];
                
                return nv;
            }
            if( col_id == 'B' ) {
                PanelListViewSizeView *sv = [tableView makeViewWithIdentifier:identifier owner:self];
                if( !sv ) {
                    sv = [[PanelListViewSizeView alloc] initWithFrame:NSRect()];
                    sv.identifier = identifier;
                }
                
                return sv;
            }
            if( col_id == 'C' ) {
                PanelListViewDateTimeView *dv = [tableView makeViewWithIdentifier:identifier owner:self];
                if( !dv ) {
                    dv = [[PanelListViewDateTimeView alloc] initWithFrame:NSRect()];
                    dv.identifier = identifier;
                }
                dv.time = vfs_item.MTime();

                return dv;
            }
           
            
//            if( col_id == 'B' ) {
//                return [[NSView alloc] initWithFrame:NSRect()];
//            }
        }
        
        
    }
    
    
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    if( m_Data ) {
        if( auto item = m_Data->EntryAtSortPosition((int)row) ) {
            auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
            
            PanelListViewRowView *row_view = [[PanelListViewRowView alloc] initWithItem:item atIndex:(int)row];
            row_view.listView = self;
            row_view.vd = vd;
            row_view.panelActive = m_PanelView.active;
            return row_view;
        }
    }
    return nil;
}

//- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
//{
//    rowView.backgroundColor = [NSColor clearColor];
//    
//}

- (void) dataChanged
{
    [m_TableView reloadData];
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

//- (void)tableViewColumnDidResize:(NSNotification *)notification
//{
////@property (readonly) NSInteger resizedColumn;
//    auto col_index = m_TableView.headerView.resizedColumn;
//    if( col_index >= 0 ) {
//        cout << col_index << endl;
//        
//        
//        
//    }
//}
//
//- (void)tableColumnsResized:(NSNotification *)notification
//{
//    cout << "!!" << endl;
//    
//}

//tableColumnsResized


@end
