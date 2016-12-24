#include <VFS/VFS.h>
#include <Habanero/CFStackAllocator.h>
#include <Habanero/algo.h>
#include <Utility/FontExtras.h>
#include "../PanelData.h"
#include "../PanelView.h"
#include "../PanelViewPresentationItemsColoringFilter.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include "../IconsGenerator2.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionView.h"
#include "PanelBriefViewCollectionViewLayout.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewCollectionViewBackground.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";
vector<PanelViewPresentationItemsColoringRule> g_ColoringRules;

static auto g_ItemsCount = 0;

static PanelBriefViewItemLayoutConstants BuildItemsLayout( NSFont *_font /* double icon size*/ )
{
    assert( _font );
    static const int insets[4] = {7, 1, 5, 1};

    // TODO: generic case for custom font (not SF)
    
    // hardcoded stuff to mimic Finder's layout
    int icon_size = 16;
    int line_height = 20;
    int text_baseline = 4;
    switch ( (int)floor(_font.pointSize+0.5) ) {
        case 10:
        case 11:
            line_height = 17;
            text_baseline = 5;
            break;
        case 12:
            line_height = 19;
            text_baseline = 5;
            break;
        case 13:
        case 14:
            line_height = 19;
            text_baseline = 4;
            break;
        case 15:
            line_height = 21;
            text_baseline = 6;
            break;
        case 16:
            line_height = 22;
            text_baseline = 6;
            break;
        default: {
            auto font_info = FontGeometryInfo( (__bridge CTFontRef)_font );
            line_height = font_info.LineHeight() + insets[1] + insets[3];
            text_baseline = insets[1] + font_info.Ascent();
            icon_size = font_info.LineHeight();
        }
    }

    PanelBriefViewItemLayoutConstants lc;
    lc.inset_left = insets[0]/*7*/;
    lc.inset_top = insets[1]/*1*/;
    lc.inset_right = insets[2]/*5*/;
    lc.inset_bottom = insets[3]/*1*/;
    lc.icon_size = icon_size/*16*/;
    lc.font_baseline = text_baseline /*4*/;
    lc.item_height = line_height /*20*/;
    
    return lc;
}

@implementation PanelBriefView
{
    NSScrollView                       *m_ScrollView;
    PanelBriefViewCollectionView       *m_CollectionView;
    PanelBriefViewCollectionViewLayout *m_Layout;
    PanelBriefViewCollectionViewBackground *m_Background;
    PanelData                          *m_Data;
    vector<short>                       m_FilenamesPxWidths;
    short                               m_MaxFilenamePxWidth;
    IconsGenerator2                    *m_IconsGenerator;
    NSFont                             *m_Font;
    PanelBriefViewItemLayoutConstants   m_ItemLayout;
    PanelBriefViewColumnsLayout         m_ColumnsLayout;
    __weak PanelView                   *m_PanelView;
    PanelDataSortMode                   m_SortMode;
}

@synthesize font = m_Font;
@synthesize regularBackgroundColor;
@synthesize alternateBackgroundColor;
@synthesize columnsLayout = m_ColumnsLayout;
@synthesize sortMode = m_SortMode;

- (void) setData:(PanelData*)_data
{
    m_Data = _data;
    [self dataChanged];
}

- (id)initWithFrame:(NSRect)frameRect andIC:(IconsGenerator2&)_ic
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        static once_flag once;
        call_once(once,[]{
            g_ColoringRules.clear();
            auto cr = GlobalConfig().Get(g_ConfigColoring);
            if( cr.IsArray() )
                for( auto i = cr.Begin(), e = cr.End(); i != e; ++i )
                    g_ColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
            g_ColoringRules.emplace_back(); // always have a default ("others") non-filtering filter at the back
        });
        
        self.regularBackgroundColor = NSColor.controlAlternatingRowBackgroundColors[0];
        self.alternateBackgroundColor = NSColor.controlAlternatingRowBackgroundColors[1];
        
        //m_Font = [NSFont labelFontOfSize:13];
        m_Font = [NSFont systemFontOfSize:13];
        [self calculateItemLayout];
        
        m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_ScrollView.wantsLayer = true;
        m_ScrollView.contentView.copiesOnScroll = true;
        [self addSubview:m_ScrollView];
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ScrollView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
        
        m_CollectionView = [[PanelBriefViewCollectionView alloc] initWithFrame:frameRect];
        m_CollectionView.dataSource = self;
        m_CollectionView.delegate = self;

        m_Background = [[PanelBriefViewCollectionViewBackground alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_Background.rowHeight = m_ItemLayout.item_height;
        m_CollectionView.backgroundView = m_Background;
        m_CollectionView.backgroundColors = @[NSColor.clearColor];
        
        m_Layout = [[PanelBriefViewCollectionViewLayout alloc] init];
        m_Layout.itemSize = NSMakeSize(100, m_ItemLayout.item_height);
        m_CollectionView.collectionViewLayout = m_Layout;
        [m_CollectionView registerClass:PanelBriefViewItem.class forItemWithIdentifier:@"A"];
        
        m_ScrollView.documentView = m_CollectionView;
        
        __weak PanelBriefView* weak_self = self;
        m_IconsGenerator = &_ic;
        m_IconsGenerator->SetUpdateCallback([=](uint16_t _icon_no, NSImageRep* _icon){
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
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
            [i setPanelActive:active];
    }    
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return m_Data ? m_Data->SortedDirectoryEntries().size() : 0;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    MachTimeBenchmark mtb1;
    PanelBriefViewItem *item = [collectionView makeItemWithIdentifier:@"A" forIndexPath:indexPath];
//    mtb1.ResetMicro("PanelBriefViewItem ");
    assert(item);
//    AAPLImageFile *imageFile = [self imageFileAtIndexPath:indexPath];
//    item.representedObject = imageFile;
    
    MachTimeBenchmark mtb;
    if( m_Data ) {
        const auto index = (int)indexPath.item;
        if( auto vfs_item = m_Data->EntryAtSortPosition(index) ) {
            [item setItem:vfs_item];
            
            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            
            NSImageRep*icon = m_IconsGenerator->ImageFor(vfs_item, vd);
            
            [item setVD:vd];
            [item setIcon:icon];
        }
        [item setPanelActive:m_PanelView.active];
    }
    
//    - (NSImageRep*) itemRequestsIcon:(PanelBriefViewItem*)_item;
    

//    mtb.ResetMicro("setting up PanelBriefViewItem ");
    
    return item;
    
    return nil;
}

- (CGFloat)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

- (CGFloat)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

- (void) calculateFilenamesWidths
{
    const auto count = m_Data ? (int)m_Data->SortedDirectoryEntries().size() : 0;
    vector<CFStringRef> strings(count);
    for( auto i = 0; i < count; ++i )
        strings[i] = m_Data->EntryAtSortPosition(i).CFDisplayName();
    m_FilenamesPxWidths = FontGeometryInfo::CalculateStringsWidths(strings, m_Font);
    auto max_it = max_element( begin(m_FilenamesPxWidths), end(m_FilenamesPxWidths) );
    m_MaxFilenamePxWidth = max_it != end(m_FilenamesPxWidths) ? *max_it : 50;
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    const auto layout = m_ItemLayout;
    const auto index = (int)indexPath.item;
    
    switch( m_ColumnsLayout.mode ) {
        case PanelBriefViewColumnsLayout::Mode::DynamicWidth: {
            assert( index < m_FilenamesPxWidths.size() );
            short width = m_ColumnsLayout.dynamic_width_equal ?
                m_MaxFilenamePxWidth :
                m_FilenamesPxWidths[index];
            width += 2*layout.inset_left + layout.icon_size + layout.inset_right;
            width = clamp( width, m_ColumnsLayout.dynamic_width_min, m_ColumnsLayout.dynamic_width_max );
            return NSMakeSize( width, layout.item_height );
        }
        case PanelBriefViewColumnsLayout::Mode::FixedWidth: {
            return NSMakeSize( m_ColumnsLayout.fixed_mode_width, layout.item_height );
        }
        case PanelBriefViewColumnsLayout::Mode::FixedAmount: {
            assert( m_ColumnsLayout.fixed_amount_value != 0);
            return NSMakeSize( self.bounds.size.width / m_ColumnsLayout.fixed_amount_value, layout.item_height );
        }
        default:
            break;
    }
    
    return {50, 20};
}

- (void) calculateItemLayout
{
    m_ItemLayout = BuildItemsLayout(m_Font);
}

- (void) dataChanged
{
    dispatch_assert_main_queue();
    assert( m_Data );
    [self calculateFilenamesWidths];
    m_IconsGenerator->SyncDiscardedAndOutdated( *m_Data );
    [m_CollectionView reloadData];
    [self syncVolatileData];
}

- (int) cursorPosition
{
    if( NSIndexPath *ip = m_CollectionView.selectionIndexPaths.anyObject )
        return (int)ip.item;
     else
         return -1;
}

- (void) setCursorPosition:(int)cursorPosition
{
    if( self.cursorPosition == cursorPosition )
        return;
    
    const auto entries_count = [m_CollectionView numberOfItemsInSection:0];
    
//    if( cursorPosition >= 0 && cursorPosition >= m_Data->SortedDirectoryEntries().size() ) {
    if( cursorPosition >= 0 && cursorPosition >= entries_count ) {
        // temporary solution
        // currently data<->cursor invariant is broken
        return;
    }
    
    if( cursorPosition < 0 )
        m_CollectionView.selectionIndexPaths = [NSSet set];
    else {
        NSSet *ind = [NSSet setWithObject:[NSIndexPath indexPathForItem:cursorPosition inSection:0]];
        m_CollectionView.selectionIndexPaths = ind;
        
        const auto vis_rect = m_ScrollView.documentVisibleRect;
        const auto item_rect = [m_CollectionView frameForItemAtIndex:cursorPosition];
        if( !NSContainsRect(vis_rect, item_rect) ) {
            auto scroll_mode = NSCollectionViewScrollPositionCenteredHorizontally;
            if( item_rect.origin.x < vis_rect.origin.x )
                scroll_mode = NSCollectionViewScrollPositionLeft;
            if( item_rect.origin.x + item_rect.size.width > vis_rect.origin.x + vis_rect.size.width )
                scroll_mode = NSCollectionViewScrollPositionRight;
            dispatch_to_main_queue([=]{
                [m_CollectionView scrollToItemsAtIndexPaths:ind scrollPosition:scroll_mode];
            });
        }
    }
}

- (bool) isItemVisible:(int)_sorted_item_index
{
    const auto entries_count = [m_CollectionView numberOfItemsInSection:0];
    if( _sorted_item_index < 0 || _sorted_item_index >= entries_count )
        return false;
    
    const auto vis_rect = m_ScrollView.documentVisibleRect;
    const auto item_rect = [m_CollectionView frameForItemAtIndex:_sorted_item_index];
    return NSContainsRect(vis_rect, item_rect) || NSIntersectsRect(vis_rect, item_rect);
}

- (void) setupFieldEditor:(NSScrollView*)_editor forItemAtIndex:(int)_sorted_item_index
{
    
    if( auto i = objc_cast<PanelBriefViewItem>([m_CollectionView itemAtIndexPath:[NSIndexPath indexPathForItem:_sorted_item_index
                                                                                                     inSection:0]]) ) {
        [i setupFieldEditor:_editor];
    }
        
}

//@property (nonatomic, readonly) itemsInColumn
- (int) itemsInColumn
{
    return m_Layout.rowsCount;
}

- (void) syncVolatileData
{
    dispatch_assert_main_queue();
    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
            const auto index = (int)index_path.item;
            [i setVD:m_Data->VolatileDataAtSortPosition(index)];
        }
}

- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules
{
    return g_ColoringRules;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
    int a = 10;
    
}

- (PanelBriefViewItemLayoutConstants) layoutConstants
{
    return m_ItemLayout;
}

- (void) onIconUpdated:(uint16_t)_icon_no image:(NSImageRep*)_image
{
    dispatch_assert_main_queue();
    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
            const auto index = (int)index_path.item;
            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            if( vd.icon == _icon_no ) {
                [i setIcon:_image];
                break;
            }
        }
}

- (void)frameDidChange
{
    // special treating for FixedAmount layout mode
    if( m_ColumnsLayout.mode == PanelBriefViewColumnsLayout::Mode::FixedAmount ) {
        
        // find a column to stick with
        const auto &column_positions = m_Layout.columnPositions;
        optional<int> column_stick;
        if( !column_positions.empty() ) {
            const auto visible_rect = m_ScrollView.documentVisibleRect;
            const auto it = find_if( begin(column_positions), end(column_positions), [=](auto v) {
                return v != numeric_limits<int>::max() && v >= visible_rect.origin.x;
            });
            if( it != end(column_positions) )
                column_stick = (int)distance( begin(column_positions), it );
        }
        
        // find delta between that column origin and visible rect
        const auto  previous_scroll_position = m_ScrollView.contentView.bounds.origin;
        int previous_delta = column_stick ? column_positions[*column_stick] - previous_scroll_position.x : 0;
        
        // rearrange stuff now
        [m_CollectionView.collectionViewLayout invalidateLayout];
        [self layoutSubtreeIfNeeded];

        // find a new delta between sticked column and visible rect
        NSPoint new_scroll_position = m_ScrollView.contentView.bounds.origin;
        int new_delta = 0;
        if(column_stick &&
           *column_stick < column_positions.size() &&
           column_positions[*column_stick] != numeric_limits<int>::max() )
            new_delta = column_positions[*column_stick] - new_scroll_position.x;
        
        // if there is the difference - adjust scroll position 
        if( previous_delta != new_delta )
            [m_ScrollView.documentView scrollPoint:NSMakePoint(new_scroll_position.x + new_delta - previous_delta,
                                                                 new_scroll_position.y)];
    }
}

- (void) setColumnsLayout:(PanelBriefViewColumnsLayout)columnsLayout
{
    if( columnsLayout != m_ColumnsLayout ) {
        m_ColumnsLayout = columnsLayout;
        
        [m_CollectionView.collectionViewLayout invalidateLayout];
    }
}

- (PanelView*) panelView
{
    return objc_cast<PanelView>(self.superview);
}

- (void) onPageUp:(NSEvent*)_event
{
    NSRect rect;
    rect =  m_CollectionView.visibleRect;
    rect.origin.x -= rect.size.width;
    [m_CollectionView scrollRectToVisible:rect];
}

- (void) onPageDown:(NSEvent*)_event
{
    auto a = m_ScrollView.horizontalPageScroll;
    NSRect rect;
    rect = m_CollectionView.visibleRect;
    rect.origin.x += rect.size.width;
    [m_CollectionView scrollRectToVisible:rect];
}

- (int) sortedItemPosAtPoint:(NSPoint)_window_point
               hitTestOption:(PanelViewHitTest::Options)_options
{
    // TODO:
    return -1;
}

- (int) maxNumberOfVisibleItems
{
    const auto cur_pos = self.cursorPosition;
    if( cur_pos < 0 ) {
        return m_Layout.rowsCount;
    }
    else {
        const auto items_per_column = m_Layout.rowsCount;
        const auto prob_vis_items = ( NSArray<PanelBriefViewItem*> *) m_CollectionView.visibleItems;
        const auto vis_rect = m_ScrollView.documentVisibleRect;
        vector<int> visible_item_columns;
        
        for( PanelBriefViewItem* i in prob_vis_items ) {
            const auto item_rect = i.view.frame;
            if( NSContainsRect(vis_rect, item_rect) ) {
                visible_item_columns.emplace_back( i.itemIndex / items_per_column);
            }
        }

        if( visible_item_columns.empty() )
            return items_per_column;
        
        const auto mm = minmax_element( begin(visible_item_columns), end(visible_item_columns) );
        const auto delta = *mm.second - *mm.first;
        return (delta + 1) * items_per_column;
     }
}

@end

