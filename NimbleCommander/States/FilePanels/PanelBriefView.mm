#include <VFS/VFS.h>
#include <Habanero/CFStackAllocator.h>
#include "../../../Files/PanelData.h"
#include "../../../Files/PanelView.h"
#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/Config.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionViewLayout.h"
#include "PanelBriefViewCollectionViewItem.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";
vector<PanelViewPresentationItemsColoringRule> g_ColoringRules;




//- (void)prepareForReuse NS_AVAILABLE_MAC(10_11);

static auto g_ItemsCount = 0;


@interface PanelBriefViewCollectionView : NSCollectionView
@end

@implementation PanelBriefViewCollectionView

- (void)keyDown:(NSEvent *)event
{
    NSView *sv = self.superview;
    while( sv != nil && objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    
    if( auto pv = objc_cast<PanelView>(sv) )
        [pv keyDown:event];
}

@end

@implementation PanelBriefView
{
    NSScrollView                        *m_ScrollView;
    PanelBriefViewCollectionView        *m_CollectionView;
    PanelBriefViewCollectionViewLayout  *m_Layout;
    
    PanelData                           *m_Data;
    vector<short>                        m_FilenamesPxWidths;
//    int                 m_CursorPosition;
}

//@synthesize cursorPosition = m_CursorPosition;

//@property (nonatomic) int cursorPosition;

//NSCollectionViewDelegate, NSCollectionViewDataSource

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
//@property NSCollectionViewScrollDirection scrollDirection; // default is NSCollectionViewScrollDirectionVertical
        m_Layout = [[PanelBriefViewCollectionViewLayout alloc] init];
        m_Layout.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
        m_Layout.itemSize = NSMakeSize(100, 20);
        //@property NSSize itemSize;
        
        m_CollectionView.collectionViewLayout = m_Layout;
        m_CollectionView.selectable = true;
//        NSSet<NSIndexPath *> *sel = m_CollectionView.selectionIndexPaths;
        
        
        [m_CollectionView registerClass:PanelBriefViewItem.class forItemWithIdentifier:@"Slide"];
        
        //- (void)registerClass:(nullable Class)itemClass forItemWithIdentifier:(NSString *)identifier NS_AVAILABLE_MAC(10_11);
        
//@property (nullable, strong) __kindof NSCollectionViewLayout *collectionViewLayout NS_AVAILABLE_MAC(10_11);
        
        m_ScrollView.documentView = m_CollectionView;
        
        
//        self.scrollview = NSScrollView.alloc().initWithFrame_(NSZeroRect)
//        self.collectionview = NSCollectionView.alloc().initWithFrame_(NSZeroRect)
//        self.scrollview.setDocumentView_(self.paxPictureView_CollectionView)
        
    }
    return self;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if( !m_Data )
        return 0;
    return m_Data->SortedDirectoryEntries().size();
//    return 10;
}

/* Asks the data source to provide an NSCollectionViewItem for the specified represented object.
 
 Your implementation of this method is responsible for creating, configuring, and returning the appropriate item for the given represented object.  You do this by sending -makeItemWithIdentifier:forIndexPath: method to the collection view and passing the identifier that corresponds to the item type you want.  Upon receiving the item, you should set any properties that correspond to the data of the corresponding model object, perform any additional needed configuration, and return the item.
 
 You do not need to set the location of the item's view inside the collection view’s bounds. The collection view sets the location of each item automatically using the layout attributes provided by its layout object.
 
 This method must always return a valid item instance.
 */
- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    MachTimeBenchmark mtb1;
    PanelBriefViewItem *item = [collectionView makeItemWithIdentifier:@"Slide" forIndexPath:indexPath];
//    mtb1.ResetMicro("PanelBriefViewItem ");
    assert(item);
//    AAPLImageFile *imageFile = [self imageFileAtIndexPath:indexPath];
//    item.representedObject = imageFile;
    
    MachTimeBenchmark mtb;
    if( m_Data ) {
        const auto index = (int)indexPath.item;
        auto vfs_item = m_Data->EntryAtSortPosition(index);
        [item setItem:vfs_item];
        [item setVD:m_Data->VolatileDataAtSortPosition(index)];
    }

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
/*
static CGFloat maxWidthOfStringsUsingCTFramesetter(NSArray *strings, NSRange range) {
    NSString *bigString = [[strings subarrayWithRange:range] componentsJoinedByString:@"\n"];
    NSAttributedString *richText = [[NSAttributedString alloc] initWithString:bigString attributes:@{ NSFontAttributeName: (__bridge NSFont *)font }];
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    CGFloat width = 0.0;
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)richText);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, bigString.length), path, NULL);
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
    for (id item in lines) {
        CTLineRef line = (__bridge CTLineRef)item;
        width = MAX(width, CTLineGetTypographicBounds(line, NULL, NULL, NULL));
    }
    CFRelease(frame);
    CFRelease(setter);
    CFRelease(path);
    return (CGFloat)width;
}
*/
- (void) calculateFilenamesWidths
{
    
//    auto item = m_Data->EntryAtSortPosition( (int)indexPath.item );
//    if( !item )
//        return res;
//    
//    static auto attrs = @{NSFontAttributeName:[NSFont labelFontOfSize:13]};
//    
//    //    NSRect rc = [[item.NSDisplayName() copy]boundingRectWithSize:NSMakeSize(10000, 500)
//    //                                                   options:0
//    //                                                attributes:attrs
//    //                                                   context:nil];
//    NSRect rc = [item.NSDisplayName() boundingRectWithSize:NSMakeSize(10000, 500)
//                                                   options:0
//                                                attributes:attrs
//                                                   context:nil];
    const auto count = m_Data ? (int)m_Data->SortedDirectoryEntries().size() : 0;
    static auto attrs = @{NSFontAttributeName:[NSFont labelFontOfSize:13]};
    
//    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
//    paragraphStyle.lineBreakMode = lineBreakMode;
    
    
    m_FilenamesPxWidths.resize( count );
#if 0
    for( auto i = 0; i < count; ++i ) {
        auto item = m_Data->EntryAtSortPosition( i );
        if( !item ) {
            m_FilenamesPxWidths[ i ] = 50; // backup
        }
        else {
            NSSize sz = [item.NSDisplayName() sizeWithAttributes:attrs];
            auto v = (short)floor( sz.width + 0.5 );
            
//            - (NSSize)sizeWithAttributes:(nullable NSDictionary<NSString *, id> *)attrs NS_AVAILABLE(10_0, 7_0);
            
//            NSRect rc = [item.NSDisplayName() boundingRectWithSize:NSMakeSize(10000, 500)
//                                                           options:0
//                                                        attributes:attrs
//                                                           context:nil];
//            auto v = (short)floor( rc.size.width + 0.5 );
            

//            NSAttributedString
//            CFStackAllocator allocator;
//            CFAttributedStringRef attr_str =  CFAttributedStringCreate(nullptr,
//                                                                       item.CFDisplayName(),
//                                                                       (CFDictionaryRef)attrs);
//            
//            CTLineRef line = CTLineCreateWithAttributedString(attr_str);
//            
//            
//            CGRect ct_rc = CTLineGetBoundsWithOptions( line, 0 );
//            auto v = (short)floor( ct_rc.size.width + 0.5 );
//            
//            
//            CFRelease(line);
//            
//            
//            CFRelease(attr_str);
            
            m_FilenamesPxWidths[i] = v;

            
            
            
        }
    }
#endif
    static const CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    
    const auto items_per_chunk = 300;
    vector<NSRange> chunks;
    for( int i = 0; i < count; i += items_per_chunk )
        chunks.emplace_back( NSMakeRange(i, min(items_per_chunk, count - i)) );
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    for( auto r: chunks )
        dispatch_group_async(group, queue, [&, r]{
            CFMutableStringRef storage = CFStringCreateMutable(nullptr, r.length * 100);
            for( auto i = (int)r.location; i < r.location + r.length; ++i ) {
                CFStringAppend(storage, m_Data->EntryAtSortPosition(i).CFDisplayName());
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
                m_FilenamesPxWidths[ r.location + i++ ] = (short)floor( lineWidth + 0.5 );
            }
            CFRelease(frameRef);
            CFRelease(framesetterRef);
            CFRelease(stringRef);
            CFRelease(storage);
        });
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
//    for( auto w: m_FilenamesPxWidths )
//        cout << w << endl;
    
//    NSMutableString *storage = [[NSMutableString alloc] initWithCapacity:count * 100];
//    for( auto i = 0; i < count; ++i ) {
//        auto item = m_Data->EntryAtSortPosition( i );
//        [storage appendString:item ? item.NSDisplayName() : @""];
//        [storage appendString:@"\n"];
//    }
//    
//    CFAttributedStringRef stringRef = CFAttributedStringCreate(NULL, (CFStringRef)storage, (CFDictionaryRef)attrs);
//    CTFramesetterRef framesetterRef = CTFramesetterCreateWithAttributedString(stringRef);
//    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), NULL);    
//    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetterRef, CFRangeMake(0, storage.length), path, NULL);
//    
//    NSArray *lines = (__bridge NSArray*)CTFrameGetLines(frameRef);
//    int i = 0;
//    for( id item in lines ) {
//        CTLineRef line = (__bridge CTLineRef)item;
//        double lineWidth = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
//        auto v = (short)floor( lineWidth + 0.5 );
//        m_FilenamesPxWidths[i] = v;
//        ++i;
//    }
//    
//    CFRelease(frameRef);
//    CFRelease(framesetterRef);
//    CFRelease(stringRef);
    
    
    
    
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
//    vector<short>                       m_FilenamesPxWidths;
//    bool                                m_FilenamesPxWidthsIsValid;
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
    [self calculateFilenamesWidths];
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
        NSRect item_rect = [m_CollectionView itemAtIndexPath:path].view.frame;
        if( !NSContainsRect(vis_rect, item_rect)) {
            [m_CollectionView scrollToItemsAtIndexPaths:ind scrollPosition:NSCollectionViewScrollPositionCenteredHorizontally];
        }
    }
}

//@property (nonatomic, readonly) itemsInColumn
- (int) itemsInColumn
{
    return m_Layout.rowsCount;
}

- (void) syncVolatileData
{
    // ...
    //return m_Data->SortedDirectoryEntries().size();
        //auto vfs_item = m_Data->EntryAtSortPosition( (int)indexPath.item );
    NSArray<PanelBriefViewItem *> *visible_items = (NSArray<PanelBriefViewItem *>*)m_CollectionView.visibleItems;
    for( PanelBriefViewItem *i in visible_items ) {
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:i]) {
            int index = (int)index_path.item;
            [i setVD:m_Data->VolatileDataAtSortPosition(index)];
        }
    }
//    */
//    - (NSArray<NSCollectionViewItem *> *)visibleItems NS_AVAILABLE_MAC(10_11);
//    
//    /* Returns the index paths of the items that are currently displayed by the CollectionView. Note that these indexPaths correspond to the same items as "visibleItems", and thus may include items whose views fall outside the CollectionView's current "visibleRect".
//     */
//    - (NSSet<NSIndexPath *> *)indexPathsForVisibleItems NS_AVAILABLE_MAC(10_11);
//    
//    /* Returns the index path of the specified item (or nil if the specified item is not in the collection view).
//     */
//    - (nullable NSIndexPath *)indexPathForItem:(NSCollectionViewItem *)item NS_AVAILABLE_MAC(10_11);
//
}

- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules
{
    return g_ColoringRules;
}

//- (NSArray<NSCollectionViewItem *> *)visibleItems


@end
