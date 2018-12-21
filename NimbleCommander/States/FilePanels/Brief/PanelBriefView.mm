// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
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
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionView.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewCollectionViewBackground.h"
#include "TextWidthsCache.h"
#include "../Helpers/IconRepositoryCleaner.h"
#include "PanelBriefViewFixedWidthLayout.h"
#include "PanelBriefViewDynamicWidthLayout.h"
#include "PanelBriefViewFixedNumberLayout.h"
#include <Utility/ObjCpp.h>

using namespace ::nc::panel;
using namespace ::nc::panel::brief;
using ::nc::vfsicon::IconRepository;

// font_size, double_icon, icon_size, line_height, text_baseline
using LayoutDataT = std::tuple<int8_t, int8_t, int8_t, int8_t, int8_t>;
static const std::array<LayoutDataT, 21> g_FixedLayoutData = {{
    std::make_tuple(10, 0,  0, 17, 5),
    std::make_tuple(10, 1, 16, 17, 5),
    std::make_tuple(10, 2, 32, 35, 14),
    std::make_tuple(11, 0,  0, 17, 5),
    std::make_tuple(11, 1, 16, 17, 5),
    std::make_tuple(11, 2, 32, 35, 14),
    std::make_tuple(12, 0,  9, 19, 5),
    std::make_tuple(12, 1, 16, 19, 5),
    std::make_tuple(12, 2, 32, 35, 13),
    std::make_tuple(13, 0,  0, 19, 4),
    std::make_tuple(13, 1, 16, 19, 4),
    std::make_tuple(13, 2, 32, 35, 12),
    std::make_tuple(14, 0,  0, 19, 4),
    std::make_tuple(14, 1, 16, 19, 4),
    std::make_tuple(14, 2, 32, 35, 12),
    std::make_tuple(15, 0,  0, 21, 6),
    std::make_tuple(15, 1, 16, 21, 6),
    std::make_tuple(15, 2, 32, 35, 12),
    std::make_tuple(16, 0,  0, 22, 6),
    std::make_tuple(16, 1, 16, 22, 6),
    std::make_tuple(16, 2, 32, 35, 12)
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
    const int font_size = (int)std::floor(_font.pointSize+0.5);
    
    // check predefined values
    auto pit = find_if(begin(g_FixedLayoutData), end(g_FixedLayoutData), [&](auto &l) {
        return std::get<0>(l) == font_size && std::get<1>(l) == _layout.icon_scale;
    });
    
    if( pit != end(g_FixedLayoutData) ) {
        // use hardcoded stuff to mimic Finder's layout
        icon_size = std::get<2>(*pit);
        line_height = std::get<3>(*pit);
        text_baseline = std::get<4>(*pit);
    }
    else {
        // try to calculate something by ourselves
        auto font_info = nc::utility::FontGeometryInfo( (__bridge CTFontRef)_font );
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
    NSCollectionViewLayout<NCPanelBriefViewLayoutProtocol> *m_Layout;
    
    PanelBriefViewCollectionViewBackground *m_Background;
    data::Model                        *m_Data;
    std::vector<short>                  m_IntrinsicItemsWidths;
    IconRepository                     *m_IconsRepository;
    std::unordered_map<IconRepository::SlotKey, int> m_IconSlotToItemIndexMapping; 
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

- (id)initWithFrame:(NSRect)frameRect andIR:(IconRepository&)_ir
{
    self = [super initWithFrame:frameRect];
    if( !self )
        return nil;
    
    m_IconsRepository = &_ir;
        
    m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
    m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_ScrollView.wantsLayer = true;
    m_ScrollView.contentView.copiesOnScroll = true;
    m_ScrollView.drawsBackground = g_ScrollingBackground;
    m_ScrollView.backgroundColor = g_ScrollingBackground ?
        CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor() :
        NSColor.clearColor;
    [self addSubview:m_ScrollView];
    
    const auto views_dict = NSDictionaryOfVariableBindings(m_ScrollView);
    const auto add_constraints = [&](NSString *_vis_fmt) {
        const auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vis_fmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views_dict]; 
        [self addConstraints:constraints];
    };
    add_constraints(@"V:|-(0)-[m_ScrollView]-(0)-|");
    add_constraints(@"|-(0)-[m_ScrollView]-(0)-|");
    
    m_CollectionView = [[PanelBriefViewCollectionView alloc] initWithFrame:frameRect];
    m_CollectionView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    m_CollectionView.dataSource = self;
    m_CollectionView.delegate = self;
    
    m_Background = [[PanelBriefViewCollectionViewBackground alloc]
                    initWithFrame:NSMakeRect(0, 0, 100, 100)];
    m_CollectionView.backgroundView = m_Background;
    m_CollectionView.backgroundColors = @[NSColor.clearColor];
    
    [self calculateItemLayout];    
        
    [m_CollectionView registerClass:PanelBriefViewItem.class forItemWithIdentifier:@"A"];
    
    m_ScrollView.documentView = m_CollectionView;
    
    __weak PanelBriefView* weak_self = self;
    m_IconsRepository->SetUpdateCallback([=](IconRepository::SlotKey _icon_no,
                                             NSImage* _icon){
        if( auto strong_self = weak_self )
            [strong_self onIconUpdated:_icon_no image:_icon];
    });    
    m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
        ThemesManager::Notifications::FilePanelsBrief|
        ThemesManager::Notifications::FilePanelsGeneral,
        objc_callback(self, @selector(themeDidChange)));
    
    return self;
}

-(void) dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
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

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
            [i setPanelActive:active];
    }    
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return m_Data ? m_Data->SortedDirectoryEntries().size() : 0;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    PanelBriefViewItem *item = [collectionView makeItemWithIdentifier:@"A" forIndexPath:indexPath];
    assert(item);
    
    if( m_Data ) {
        const auto index = (int)indexPath.item;
        if( auto vfs_item = m_Data->EntryAtSortPosition(index) ) {
            [item setItem:vfs_item];
            
            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            
            if( m_IconsRepository->IsValidSlot(vd.icon) == false )
                vd.icon = m_IconsRepository->Register(vfs_item); 

            if( m_IconsRepository->IsValidSlot(vd.icon) == true ) {
                [item setIcon:m_IconsRepository->AvailableIconForSlot(vd.icon)];
                m_IconsRepository->ScheduleIconProduction(vd.icon, vfs_item);
                m_IconSlotToItemIndexMapping[vd.icon] = index;
            }
            else {
                [item setIcon:m_IconsRepository->AvailableIconForListingItem(vfs_item)];
            }
                        
            [item setVD:vd];
        }
        [item setPanelActive:m_PanelView.active];
    }
    
    return item;
}

static std::vector<CFStringRef> GatherDisplayFilenames(const data::Model *_data)
{
    if( _data == nullptr )
        return {};
    
    const auto &sorted_idices = _data->SortedDirectoryEntries();
    const auto &listing = _data->Listing();
    const auto count = (int)sorted_idices.size();
    auto strings = std::vector<CFStringRef>(count, nullptr);
    for( int i = 0; i < count; ++i )
        strings[i] = listing.DisplayFilenameCF( sorted_idices[i] );
    return strings;
}

- (void) calculateFilenamesWidths
{
    const auto strings = GatherDisplayFilenames(m_Data);
    const auto count = (int)strings.size();
    
    if( count == 0 ) {
        m_IntrinsicItemsWidths.clear();
        return;
    }
    
    const auto font = CurrentTheme().FilePanelsBriefFont();
    auto widths = TextWidthsCache::Instance().Widths(strings, font);
    assert( (int)widths.size() == count );
    
    const auto &layout = m_ItemLayout;
    const short width_addition = 2 * layout.inset_left +  layout.icon_size + layout.inset_right;     
    if( m_ColumnsLayout.dynamic_width_equal ) {
        const auto max_width = *std::max_element( widths.begin(), widths.begin() );
        const short width =  max_width + width_addition;
        std::fill(widths.begin(), widths.end(), width);
    }
    else {
        std::for_each(widths.begin(), widths.end(),
                      [width_addition](auto &width){ width += width_addition; } );
    }
    m_IntrinsicItemsWidths = std::move(widths);
}

- (std::vector<short>&)collectionViewProvideIntrinsicItemsWidths:(NSCollectionView *)collectionView
{
    return m_IntrinsicItemsWidths;
}

- (void) updateItemsLayoutEngine
{
    const auto columns_layout = m_ColumnsLayout;
    if( columns_layout.mode == PanelBriefViewColumnsLayout::Mode::FixedWidth ) {
        if( auto fixed_width = objc_cast<NCPanelBriefViewFixedWidthLayout>(m_Layout) ) {
            fixed_width.itemWidth = columns_layout.fixed_mode_width;
            fixed_width.itemHeight = m_ItemLayout.item_height;
        }
        else {
            auto layout = [[NCPanelBriefViewFixedWidthLayout alloc] init];
            layout.itemHeight = m_ItemLayout.item_height;
            layout.itemWidth = columns_layout.fixed_mode_width;
            layout.layoutDelegate = self;
            m_Layout = layout;
            m_CollectionView.collectionViewLayout = layout;
        }
    }
    else if( columns_layout.mode == PanelBriefViewColumnsLayout::Mode::FixedAmount ) {
        if( auto fixed_number = objc_cast<NCPanelBriefViewFixedNumberLayout>(m_Layout) ) {
            fixed_number.columnsPerScreen = columns_layout.fixed_amount_value;
            fixed_number.itemHeight = m_ItemLayout.item_height;
        }
        else {
            auto layout = [[NCPanelBriefViewFixedNumberLayout alloc] init];
            layout.itemHeight = m_ItemLayout.item_height;
            layout.columnsPerScreen = columns_layout.fixed_amount_value;
            layout.layoutDelegate = self;
            m_Layout = layout;
            m_CollectionView.collectionViewLayout = layout;
        }
    }
    else if( columns_layout.mode == PanelBriefViewColumnsLayout::Mode::DynamicWidth ) {
        if( auto dynamic_width = objc_cast<NCPanelBriefViewDynamicWidthLayout>(m_Layout) ) {
            dynamic_width.itemMinWidth  = columns_layout.dynamic_width_min;
            dynamic_width.itemMaxWidth = columns_layout.dynamic_width_max;
            dynamic_width.itemHeight = m_ItemLayout.item_height;
        }
        else {
            auto layout = [[NCPanelBriefViewDynamicWidthLayout alloc] init];
            layout.itemHeight = m_ItemLayout.item_height;
            layout.itemMinWidth  = columns_layout.dynamic_width_min;
            layout.itemMaxWidth = columns_layout.dynamic_width_max;            
            layout.layoutDelegate = self;
            m_Layout = layout;
            m_CollectionView.collectionViewLayout = layout;
        }        
    }
}

- (void) calculateItemLayout
{
    m_ItemLayout = BuildItemsLayout(CurrentTheme().FilePanelsBriefFont(), m_ColumnsLayout);
    [self updateItemsLayoutEngine];
    
    [self setupIconsPxSize];

    m_Background.rowHeight = m_ItemLayout.item_height;
    
    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
        [i updateItemLayout];    
}

- (void) setupIconsPxSize
{
    if( self.window ) {
        const auto px_size = int(m_ItemLayout.icon_size * self.window.backingScaleFactor);
        m_IconsRepository->SetPxSize(px_size);
    }
    else {
        m_IconsRepository->SetPxSize(m_ItemLayout.icon_size);
    }
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self setupIconsPxSize]; // we call this here due to a possible DPI change
}

- (void) dataChanged
{
    dispatch_assert_main_queue();
    assert( m_Data );
    [self calculateFilenamesWidths];
    m_IconSlotToItemIndexMapping.clear();
    IconRepositoryCleaner{*m_IconsRepository, *m_Data}.SweepUnusedSlots();
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

- (void) ensureItemIsVisible:(int)_item_index
{
    if( _item_index < 0 )
        return;
    
    const auto visible_rect = m_ScrollView.documentVisibleRect;
    const auto item_rect = [m_CollectionView frameForItemAtIndex:_item_index];
    if( !NSContainsRect(visible_rect, item_rect) ) {
        const auto index_path = [NSIndexPath indexPathForItem:_item_index inSection:0];
        const auto indices = [NSSet setWithObject:index_path];
        if( visible_rect.size.width >= item_rect.size.width ) {
            const auto scroll_mode = [&]{
                if( item_rect.origin.x < visible_rect.origin.x )
                    return NSCollectionViewScrollPositionLeft;
                if( NSMaxX(item_rect) > NSMaxX(visible_rect) )
                    return NSCollectionViewScrollPositionRight;
                return NSCollectionViewScrollPositionCenteredHorizontally;
            }();
            [m_CollectionView scrollToItemsAtIndexPaths:indices
                                         scrollPosition:scroll_mode];
        }
        else {
            // TODO: this call can be redundant.
            // Need to check whether the scroll position is already optimal
            [m_CollectionView scrollToItemsAtIndexPaths:indices
                                         scrollPosition:NSCollectionViewScrollPositionLeft];
        }
    }
}

- (void) setCursorPosition:(int)_cursor_position
{
    if( self.cursorPosition == _cursor_position )
        return;
    
    const auto entries_count = [m_CollectionView numberOfItemsInSection:0];
    
    if( _cursor_position >= 0 && _cursor_position >= entries_count ) {
        // currently data<->cursor invariant is temporary broken => skipping this request
        return;
    }
    
    if( _cursor_position < 0 ) {
        m_CollectionView.selectionIndexPaths = [NSSet set];
    }
    else {
        const auto index_path = [NSIndexPath indexPathForItem:_cursor_position inSection:0];
        const auto indices = [NSSet setWithObject:index_path];
        m_CollectionView.selectionIndexPaths = indices;
        [self ensureItemIsVisible:_cursor_position];
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
    return m_Layout.rowsNumber;
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

- (void)collectionView:(NSCollectionView *)collectionView
didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
}

- (PanelBriefViewItemLayoutConstants) layoutConstants
{
    return m_ItemLayout;
}

- (void) onIconUpdated:(IconRepository::SlotKey)_icon_no image:(NSImage*)_image
{
    dispatch_assert_main_queue();
    const auto it = m_IconSlotToItemIndexMapping.find(_icon_no);
    if( it != end(m_IconSlotToItemIndexMapping) ) {
        const auto index = [NSIndexPath indexPathForItem:it->second inSection:0];        
        if( auto item = objc_cast<PanelBriefViewItem>([m_CollectionView itemAtIndexPath:index]) ) {
            [item setIcon:_image];
        }
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
        return m_Layout.rowsNumber;
    }
    else {
        const auto items_per_column = m_Layout.rowsNumber;
        const auto prob_vis_items = ( NSArray<PanelBriefViewItem*> *) m_CollectionView.visibleItems;
        const auto vis_rect = m_ScrollView.documentVisibleRect;
        std::vector<int> visible_item_columns;
        
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

- (void)collectionViewDidLayoutItems:(NSCollectionView *)collectionView
{    
    static const bool draws_grid =
        [m_CollectionView respondsToSelector:@selector(setBackgroundViewScrollsWithContent:)];
    if( draws_grid )
        [m_CollectionView.backgroundView setNeedsDisplay:true];
}

@end

