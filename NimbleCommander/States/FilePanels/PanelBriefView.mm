#include <VFS/VFS.h>
#include <Habanero/CFStackAllocator.h>
#include <Habanero/algo.h>
#include <Utility/FontExtras.h>
#include "../../../Files/PanelData.h"
#include "../../../Files/PanelView.h"
#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/Config.h"
#include "IconsGenerator2.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionViewLayout.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewCollectionViewBackground.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";
vector<PanelViewPresentationItemsColoringRule> g_ColoringRules;

static auto g_ItemsCount = 0;

bool PanelBriefViewColumnsLayout::operator ==(const PanelBriefViewColumnsLayout& _rhs) const noexcept
{
    return mode == _rhs.mode &&
            fixed_mode_width == _rhs.fixed_mode_width &&
            fixed_amount_value == _rhs.fixed_amount_value &&
            dynamic_width_min == _rhs.dynamic_width_min &&
            dynamic_width_max == _rhs.dynamic_width_max &&
            dynamic_width_equal == _rhs.dynamic_width_equal;
}

bool PanelBriefViewColumnsLayout::operator !=(const PanelBriefViewColumnsLayout& _rhs) const noexcept
{
    return !(*this == _rhs);
}


@interface PanelBriefViewCollectionView : NSCollectionView
@end

@implementation PanelBriefViewCollectionView

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.selectable = true;
    }
    return self;
}

- (void)keyDown:(NSEvent *)event
{
    NSView *sv = self.superview;
    while( sv != nil && objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    
    if( auto pv = objc_cast<PanelView>(sv) )
        [pv keyDown:event];
}

- (void)mouseDown:(NSEvent *)event
{
}

- (void)mouseUp:(NSEvent *)event
{
}

@end

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
    IconsGenerator2                     m_IconsGenerator;
    NSFont                             *m_Font;
    PanelBriefViewItemLayoutConstants   m_ItemLayout;
    PanelBriefViewColumnsLayout         m_ColumnsLayout;
}

@synthesize font = m_Font;
@synthesize regularBackgroundColor;
@synthesize alternateBackgroundColor;
@synthesize columnsLayout = m_ColumnsLayout;

- (void) setData:(PanelData*)_data
{
    m_Data = _data;
    [self dataChanged];
}

- (id)initWithFrame:(NSRect)frameRect
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

-(void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
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
        auto vfs_item = m_Data->EntryAtSortPosition(index);
        [item setItem:vfs_item];
        
        auto &vd = m_Data->VolatileDataAtSortPosition(index);
        
        NSImageRep*icon = m_IconsGenerator.ImageFor(vfs_item, vd);
        
        [item setVD:vd];
        [item setIcon:icon];
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
            short width = m_ColumnsLayout.dynamic_width_equal ? m_MaxFilenamePxWidth : m_FilenamesPxWidths[index];
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
    m_IconsGenerator.SyncDiscardedAndOutdated( *m_Data );
    [m_CollectionView reloadData];
    [self syncVolatileData];
}

- (int) cursorPosition
{
//    return m_CursorPosition;
//    NSIndexPath *sel = m_CollectionView.selectionIndexPaths;
    NSSet<NSIndexPath *> *sel = m_CollectionView.selectionIndexPaths;
    NSArray *indeces = sel.allObjects;
    if( indeces.count == 0 )
        return -1;
    else
        return (int)((NSIndexPath*)indeces[0]).item;
}

- (void) setCursorPosition:(int)cursorPosition
{
    if( cursorPosition >= 0 && cursorPosition >= m_Data->SortedDirectoryEntries().size() ) {
        // temporary solution
        // currently data<->cursor invariant is broken
        return;
    }
    
    if( cursorPosition < 0 )
        m_CollectionView.selectionIndexPaths = [NSSet set];
    else {
        NSIndexPath *path = [NSIndexPath indexPathForItem:cursorPosition inSection:0];
        NSSet *ind = [NSSet setWithObject:[NSIndexPath indexPathForItem:cursorPosition inSection:0]];
        m_CollectionView.selectionIndexPaths = ind;
        
        
        NSRect vis_rect = m_ScrollView.documentVisibleRect;
        
        NSCollectionViewItem *collection_item = [m_CollectionView itemAtIndexPath:path];
//        NSRect item_rect = [m_CollectionView itemAtIndexPath:path].view.frame;
        if( !collection_item || !NSContainsRect(vis_rect, collection_item.view.frame) )
            dispatch_to_main_queue([=]{
                [m_CollectionView scrollToItemsAtIndexPaths:ind scrollPosition:NSCollectionViewScrollPositionCenteredHorizontally];
            });
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
    if( m_ColumnsLayout.mode == PanelBriefViewColumnsLayout::Mode::FixedAmount ) {
//        [m_CollectionView reloadData];
//        MachTimeBenchmark mtb;
        [m_CollectionView.collectionViewLayout invalidateLayout];
//        mtb.ResetMicro();
    }
}

@end

