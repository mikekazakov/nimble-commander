#include <VFS/VFS.h>
#include <Habanero/CFStackAllocator.h>
#include "../../../Files/PanelData.h"
#include "../../../Files/PanelView.h"
#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/Config.h"
#include "IconsGenerator2.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionViewLayout.h"
#include "PanelBriefViewCollectionViewItem.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";
vector<PanelViewPresentationItemsColoringRule> g_ColoringRules;

static auto g_ItemsCount = 0;

static vector<short> CalculateStringsWidths( const vector<CFStringRef> &_strings, NSFont *_font )
{
    static const auto path = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    static const auto items_per_chunk = 300;
    
    auto attrs = @{NSFontAttributeName:_font};
    
    const auto count = (int)_strings.size();
    vector<short> widths( count );
    
    vector<NSRange> chunks;
    for( int i = 0; i < count; i += items_per_chunk )
        chunks.emplace_back( NSMakeRange(i, min(items_per_chunk, count - i)) );
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    for( auto r: chunks )
        dispatch_group_async(group, queue, [&, r]{
            CFMutableStringRef storage = CFStringCreateMutable(NULL, r.length * 100);
            for( auto i = (int)r.location; i < r.location + r.length; ++i ) {
                CFStringAppend(storage, _strings[i]);
                CFStringAppend(storage, CFSTR("\n"));
            }
            
            const auto storage_length = CFStringGetLength(storage);
            CFAttributedStringRef stringRef = CFAttributedStringCreate(NULL, storage, (CFDictionaryRef)attrs);
            CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString(stringRef);
            CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, storage_length), path, NULL);
            NSArray *lines = (__bridge NSArray*)CTFrameGetLines(frameRef);
            int i = 0;
            for( id item in lines ) {
                CTLineRef line = (__bridge CTLineRef)item;
                double lineWidth = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
                widths[ r.location + i++ ] = (short)floor( lineWidth + 0.5 );
            }
            CFRelease(frameRef);
            CFRelease(framesetterRef);
            CFRelease(stringRef);
            CFRelease(storage);
        });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return widths;
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

@implementation PanelBriefView
{
    NSScrollView                       *m_ScrollView;
    PanelBriefViewCollectionView       *m_CollectionView;
    PanelBriefViewCollectionViewLayout *m_Layout;
    PanelData                          *m_Data;
    vector<short>                       m_FilenamesPxWidths;
    IconsGenerator2                     m_IconsGenerator;
}

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
        
        m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_ScrollView];
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ScrollView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
        
        m_CollectionView = [[PanelBriefViewCollectionView alloc] initWithFrame:frameRect];
        m_CollectionView.dataSource = self;
        m_CollectionView.delegate = self;
        
        
        m_Layout = [[PanelBriefViewCollectionViewLayout alloc] init];
        m_CollectionView.collectionViewLayout = m_Layout;
        [m_CollectionView registerClass:PanelBriefViewItem.class forItemWithIdentifier:@"Item"];
        
        m_ScrollView.documentView = m_CollectionView;
        
        __weak PanelBriefView* weak_self = self;
        m_IconsGenerator.SetUpdateCallback([=](uint16_t _icon){
            if( auto strong_self = weak_self )
                [strong_self onIconUpdated:_icon];
        });
    }
    return self;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return m_Data ? m_Data->SortedDirectoryEntries().size() : 0;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    MachTimeBenchmark mtb1;
    PanelBriefViewItem *item = [collectionView makeItemWithIdentifier:@"Item" forIndexPath:indexPath];
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
    m_FilenamesPxWidths = CalculateStringsWidths(strings, [NSFont labelFontOfSize:13]);
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
//    return NSMakeSize( self.bounds.size.width / 1, 20);
    
    const auto index = (int)indexPath.item;
    assert( index < m_FilenamesPxWidths.size() );
    
    NSSize sz = NSMakeSize( m_FilenamesPxWidths[index], 20);

    sz.width += 6;
    
    if( sz.width < 50 )
        sz.width = 50;
    else if( sz.width > 200 )
        sz.width = 200;
    
    return sz;
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
    PanelBriefViewItemLayoutConstants lc;
    lc.inset_left = 7;
    lc.inset_top = 1;
    lc.inset_right = 5;
    lc.inset_bottom = 1;
    lc.icon_size = 16;
    lc.font_baseline = 4;
    lc.item_height = 20;
    return lc;
}

- (void) onIconUpdated:(uint16_t)_icon
{
    dispatch_assert_main_queue();
    for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
            const auto index = (int)index_path.item;
            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            if( vd.icon == _icon ) {
                auto vfs_item = m_Data->EntryAtSortPosition(index);
                NSImageRep *icon = m_IconsGenerator.ImageFor(vfs_item, vd);
                [i setIcon:icon];
            }
        }
}

@end

