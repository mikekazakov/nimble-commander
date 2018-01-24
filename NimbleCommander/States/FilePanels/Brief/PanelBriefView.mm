// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include <Habanero/algo.h>
#include <Utility/FontExtras.h>
#include "../PanelData.h"
#include "../PanelDataSortMode.h"
#include "../PanelView.h"
#include "../PanelViewPresentationItemsColoringFilter.h"
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "../IconsGenerator2.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionView.h"
#include "PanelBriefViewCollectionViewLayout.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewCollectionViewBackground.h"
#include "TextWidthsCache.h"

using namespace ::nc::panel;
using namespace ::nc::panel::brief;

// font_size, double_icon, icon_size, line_height, text_baseline
static const array< tuple<int8_t, int8_t, int8_t, int8_t, int8_t>, 21> g_FixedLayoutData = {{
    make_tuple(10, 0,  0, 17, 5),
    make_tuple(10, 1, 16, 17, 5),
    make_tuple(10, 2, 32, 35, 14),
    make_tuple(11, 0,  0, 17, 5),
    make_tuple(11, 1, 16, 17, 5),
    make_tuple(11, 2, 32, 35, 14),
    make_tuple(12, 0,  9, 19, 5),
    make_tuple(12, 1, 16, 19, 5),
    make_tuple(12, 2, 32, 35, 13),
    make_tuple(13, 0,  0, 19, 4),
    make_tuple(13, 1, 16, 19, 4),
    make_tuple(13, 2, 32, 35, 12),
    make_tuple(14, 0,  0, 19, 4),
    make_tuple(14, 1, 16, 19, 4),
    make_tuple(14, 2, 32, 35, 12),
    make_tuple(15, 0,  0, 21, 6),
    make_tuple(15, 1, 16, 21, 6),
    make_tuple(15, 2, 32, 35, 12),
    make_tuple(16, 0,  0, 22, 6),
    make_tuple(16, 1, 16, 22, 6),
    make_tuple(16, 2, 32, 35, 12)
}};

static PanelBriefViewItemLayoutConstants BuildItemsLayout(NSFont *_font,
                                                          PanelBriefViewColumnsLayout _layout)
{
    assert( _font );
    static const short insets[4] = {7, 1, 5, 1};

    // TODO: generic case for custom font (not SF)

    short icon_size = 16;
    short line_height = 20;
    short text_baseline = 4;
    const int font_size = (int)floor(_font.pointSize+0.5);
    
    // check predefined values
    auto pit = find_if(begin(g_FixedLayoutData), end(g_FixedLayoutData), [&](auto &l) {
        return get<0>(l) == font_size && get<1>(l) == _layout.icon_scale;
    });
    
    if( pit != end(g_FixedLayoutData) ) {
        // use hardcoded stuff to mimic Finder's layout
        icon_size = get<2>(*pit);
        line_height = get<3>(*pit);
        text_baseline = get<4>(*pit);
    }
    else {
        // try to calculate something by ourselves
        auto font_info = FontGeometryInfo( (__bridge CTFontRef)_font );
        line_height = short(font_info.LineHeight()) + insets[1] + insets[3];
        if( _layout.icon_scale == 1 && line_height < 17 )
            line_height = 17;
        else if( _layout.icon_scale == 2 && line_height < 35 )
            line_height = 35;
        
        text_baseline = insets[1] + short(font_info.Descent());
        icon_size = _layout.icon_scale * 16;
    }
    

    PanelBriefViewItemLayoutConstants lc;
    lc.inset_left = (int8_t)insets[0]/*7*/;
    lc.inset_top = (int8_t)insets[1]/*1*/;
    lc.inset_right = (int8_t)insets[2]/*5*/;
    lc.inset_bottom = (int8_t)insets[3]/*1*/;
    lc.icon_size = icon_size/*16*/;
    lc.font_baseline = text_baseline /*4*/;
    lc.item_height = line_height /*20*/;
    
    return lc;
}

bool PanelBriefViewItemLayoutConstants::operator ==(const PanelBriefViewItemLayoutConstants &_rhs)
const noexcept
{
    return
    inset_left == _rhs.inset_left       &&
    inset_top == _rhs.inset_top         &&
    inset_right == _rhs.inset_right     &&
    inset_bottom == _rhs.inset_bottom   &&
    icon_size == _rhs.icon_size         &&
    font_baseline == _rhs.font_baseline &&
    item_height == _rhs.item_height;
}

bool PanelBriefViewItemLayoutConstants::operator !=(const PanelBriefViewItemLayoutConstants &_rhs)
const noexcept
{
    return !(*this == _rhs);
}

@implementation PanelBriefView
{
    NSScrollView                       *m_ScrollView;
    PanelBriefViewCollectionView       *m_CollectionView;
    PanelBriefViewCollectionViewLayout *m_Layout;
    PanelBriefViewCollectionViewBackground *m_Background;
    data::Model                        *m_Data;
    vector<short>                       m_FilenamesPxWidths;
    short                               m_MaxFilenamePxWidth;
    IconsGenerator2                    *m_IconsGenerator;
    PanelBriefViewItemLayoutConstants   m_ItemLayout;
    PanelBriefViewColumnsLayout         m_ColumnsLayout;
    __weak PanelView                   *m_PanelView;
    data::SortMode                      m_SortMode;
    ThemesManager::ObservationTicket    m_ThemeObservation;
}

@synthesize columnsLayout = m_ColumnsLayout;
@synthesize sortMode = m_SortMode;

static const auto g_ScrollingBackground =
    [NSCollectionView instancesRespondToSelector:@selector(setBackgroundViewScrollsWithContent:)];

- (void) setData:(data::Model*)_data
{
    m_Data = _data;
    [self dataChanged];
}

- (id)initWithFrame:(NSRect)frameRect andIC:(IconsGenerator2&)_ic
{
    self = [super initWithFrame:frameRect];
    if( !self )
        return nil;
    
    m_IconsGenerator = &_ic;
    
    [self calculateItemLayout];
    
    m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
    m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_ScrollView.wantsLayer = true;
    m_ScrollView.contentView.copiesOnScroll = true;
    m_ScrollView.drawsBackground = g_ScrollingBackground;
    m_ScrollView.backgroundColor = g_ScrollingBackground ?
        CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor() :
        NSColor.clearColor;
    [self addSubview:m_ScrollView];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_ScrollView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
    
    m_CollectionView = [[PanelBriefViewCollectionView alloc] initWithFrame:frameRect];
    m_CollectionView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
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
    m_IconsGenerator->SetUpdateCallback([=](uint16_t _icon_no, NSImage* _icon){
        if( auto strong_self = weak_self )
            [strong_self onIconUpdated:_icon_no image:_icon];
    });
    m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
        ThemesManager::Notifications::FilePanelsBrief|
        ThemesManager::Notifications::FilePanelsGeneral,
        objc_callback(self, @selector(themeDidChange)));
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(frameDidChange)
                                               name:NSViewFrameDidChangeNotification
                                             object:self];
    return self;
}

-(void) dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isOpaque
{
    return true;
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
    PanelBriefViewItem *item = [collectionView makeItemWithIdentifier:@"A" forIndexPath:indexPath];
    assert(item);
    
    if( m_Data ) {
        const auto index = (int)indexPath.item;
        if( auto vfs_item = m_Data->EntryAtSortPosition(index) ) {
            [item setItem:vfs_item];
            
            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            
            NSImage *icon = m_IconsGenerator->ImageFor(vfs_item, vd);
            
            [item setVD:vd];
            [item setIcon:icon];
        }
        [item setPanelActive:m_PanelView.active];
    }
    
//    - (NSImageRep*) itemRequestsIcon:(PanelBriefViewItem*)_item;
    

//    mtb.ResetMicro("setting up PanelBriefViewItem ");
    
    return item;
}

- (CGFloat)collectionView:(NSCollectionView *)collectionView
                   layout:(NSCollectionViewLayout*)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

- (CGFloat)collectionView:(NSCollectionView *)collectionView
                   layout:(NSCollectionViewLayout*)collectionViewLayout
minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

- (void) calculateFilenamesWidths
{
    const auto min_width = 50;

    const auto count = m_Data ? (int)m_Data->SortedDirectoryEntries().size() : 0;
    vector<reference_wrapper<const string>> strings;
    strings.reserve(count);
    for( auto i = 0; i < count; ++i )
        strings.emplace_back( ref(m_Data->EntryAtSortPosition(i).DisplayName()) );
    
    m_FilenamesPxWidths = TextWidthsCache::Instance().Widths(strings,
                                                             CurrentTheme().FilePanelsBriefFont());
    
    auto max_it = max_element( begin(m_FilenamesPxWidths), end(m_FilenamesPxWidths) );
    m_MaxFilenamePxWidth = max_it != end(m_FilenamesPxWidths) ? *max_it : min_width;
}

- (NSSize)collectionView:(NSCollectionView *)collectionView
                  layout:(NSCollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    const auto &layout = m_ItemLayout;
    const auto index = (int)indexPath.item;
    
    switch( m_ColumnsLayout.mode ) {
        case PanelBriefViewColumnsLayout::Mode::DynamicWidth: {
            assert( index < (int)m_FilenamesPxWidths.size() );
            short width = m_ColumnsLayout.dynamic_width_equal ?
                m_MaxFilenamePxWidth :
                m_FilenamesPxWidths[index];
            width += 2*layout.inset_left + layout.icon_size + layout.inset_right;
            width = clamp(width,
                          m_ColumnsLayout.dynamic_width_min,
                          m_ColumnsLayout.dynamic_width_max );
            return NSMakeSize( width, layout.item_height );
        }
        case PanelBriefViewColumnsLayout::Mode::FixedWidth: {
            return NSMakeSize( m_ColumnsLayout.fixed_mode_width, layout.item_height );
        }
        case PanelBriefViewColumnsLayout::Mode::FixedAmount: {
            assert( m_ColumnsLayout.fixed_amount_value != 0);
            const int rows_count = m_Layout.rowsCount;
            const int colums_per_screen = m_ColumnsLayout.fixed_amount_value;
            const int screen_width = (int)self.bounds.size.width;
            const int column = index / rows_count;
            const int column_in_chunk = column % colums_per_screen;
            const int width_per_col = screen_width / colums_per_screen;
            const int remainer = screen_width % colums_per_screen;
            return NSMakeSize(width_per_col + (column_in_chunk >= remainer ? 0 : 1),
                              layout.item_height );
        }
        default:
            break;
    }
    
    return {50, 20};
}

- (void) calculateItemLayout
{
    m_ItemLayout = BuildItemsLayout(CurrentTheme().FilePanelsBriefFont(), m_ColumnsLayout);
    m_IconsGenerator->SetIconSize( m_ItemLayout.icon_size );

    if( m_Background )
        m_Background.rowHeight = m_ItemLayout.item_height;
    
    if( m_Layout )
        m_Layout.itemSize = NSMakeSize(100, m_ItemLayout.item_height);
    
    if( m_CollectionView )
        for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
            [i updateItemLayout];
    
}

- (void) dataChanged
{
    dispatch_assert_main_queue();
    assert( m_Data );
    [self calculateFilenamesWidths];
    m_IconsGenerator->SyncDiscardedAndOutdated( *m_Data );
    [m_CollectionView reloadData];
    [self syncVolatileData];
    [m_Background setNeedsDisplay:true];
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
    
    if( cursorPosition >= 0 && cursorPosition >= entries_count ) {
        // currently data<->cursor invariant is temporary broken => skipping this request
        return;
    }
    
    if( cursorPosition < 0 )
        m_CollectionView.selectionIndexPaths = [NSSet set];
    else {
        const auto ind = [NSSet setWithObject:[NSIndexPath indexPathForItem:cursorPosition
                                                                  inSection:0]];
        m_CollectionView.selectionIndexPaths = ind;
        
        const auto vis_rect = m_ScrollView.documentVisibleRect;
        const auto item_rect = [m_CollectionView frameForItemAtIndex:cursorPosition];
        if( !NSContainsRect(vis_rect, item_rect) ) {
            const auto scroll_mode = [&]{
                if( item_rect.origin.x < vis_rect.origin.x )
                    return NSCollectionViewScrollPositionLeft;
                if( NSMaxX(item_rect) > NSMaxX(vis_rect) )
                    return NSCollectionViewScrollPositionRight;
                return NSCollectionViewScrollPositionCenteredHorizontally;
            }();
            [m_CollectionView scrollToItemsAtIndexPaths:ind scrollPosition:scroll_mode];
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
    const auto index = [NSIndexPath indexPathForItem:_sorted_item_index inSection:0];
    if( auto i = objc_cast<PanelBriefViewItem>([m_CollectionView itemAtIndexPath:index]) )
        [i setupFieldEditor:_editor];
}

- (int) itemsInColumn
{
    return m_Layout.rowsCount;
}

- (int) columns
{
    if( !m_Data )
        return 1;
    
    const auto items_total = m_Data->SortedDirectoryEntries().size();
    const auto items_in_column = self.itemsInColumn;
    
    return (int)(items_total/items_in_column) + (items_total % items_in_column ? 1 : 0);
}

- (void) syncVolatileData
{
    dispatch_assert_main_queue();
    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
            const auto index = (int)index_path.item;
            // need to firstly check if we're still in sync with panel data
            if( m_Data->IsValidSortPosition(index) )
                [i setVD:m_Data->VolatileDataAtSortPosition(index)];
        }
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
}

- (PanelBriefViewItemLayoutConstants) layoutConstants
{
    return m_ItemLayout;
}

- (void) onIconUpdated:(uint16_t)_icon_no image:(NSImage*)_image
{
    dispatch_assert_main_queue();
    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
            const auto index = (int)index_path.item;
            if( m_Data->IsValidSortPosition(index) ) {
                auto &vd = m_Data->VolatileDataAtSortPosition(index);
                if( vd.icon == _icon_no ) {
                    [i setIcon:_image];
                    break;
                }
            }
        }
}

- (void) updateFixedAmountLayout
{
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
    const auto previous_scroll_position = m_ScrollView.contentView.bounds.origin;
    const auto previous_delta = column_stick ?
        column_positions[*column_stick] - int(previous_scroll_position.x) :
        0;
    
    // rearrange stuff now
    [m_Layout invalidateLayout];
    [self layoutSubtreeIfNeeded];
    
    // find a new delta between sticked column and visible rect
    const auto new_scroll_position = m_ScrollView.contentView.bounds.origin;
    const auto new_delta = (column_stick &&
                            *column_stick < (int)column_positions.size() &&
                            column_positions[*column_stick] != numeric_limits<int>::max() ) ?
        column_positions[*column_stick] - int(new_scroll_position.x) :
        0;
    
    // if there is the difference - adjust scroll position
    if( previous_delta != new_delta ) {
        const auto new_pos = NSMakePoint(new_scroll_position.x + new_delta - previous_delta,
                                         new_scroll_position.y);
        [m_ScrollView.documentView scrollPoint:new_pos];
    }
}

- (void)frameDidChange
{
    // special treating for FixedAmount layout mode
    if( m_ColumnsLayout.mode == PanelBriefViewColumnsLayout::Mode::FixedAmount ) {
        if( !self.window.visible )
            // the is really a HACK:
            // we have to push update into next cycle, since it could be ignored if triggered in
            // the middle of another update cycle, which happens on resize during initial layout.
            // sadface.
            dispatch_to_main_queue([=]{
                [self updateFixedAmountLayout];
            });
        else
            [self updateFixedAmountLayout];
    }
}

- (void) setColumnsLayout:(PanelBriefViewColumnsLayout)columnsLayout
{
    if( columnsLayout != m_ColumnsLayout ) {
        m_ColumnsLayout = columnsLayout;
        [self calculateItemLayout];
        [m_Layout invalidateLayout];
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
    NSRect rect;
    rect = m_CollectionView.visibleRect;
    rect.origin.x += rect.size.width;
    [m_CollectionView scrollRectToVisible:rect];
}

- (void) onScrollToBeginning:(NSEvent*)_event
{
    NSRect rect;
    rect =  m_CollectionView.visibleRect;
    rect.origin.x = 0;
    [m_CollectionView scrollRectToVisible:rect];
}

- (void) onScrollToEnd:(NSEvent*)_event
{
    NSRect rect;
    rect = m_CollectionView.visibleRect;
    rect.origin.x = m_CollectionView.bounds.size.width - rect.size.width;
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

- (void)themeDidChange
{
    const auto cp = self.cursorPosition;
    [self calculateItemLayout];
    [m_CollectionView reloadData];
    self.cursorPosition = cp;
    m_Background.needsDisplay = true;
    if( g_ScrollingBackground )
        m_ScrollView.backgroundColor = CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor();
}

@end

