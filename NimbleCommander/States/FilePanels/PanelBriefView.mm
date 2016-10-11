#include <VFS/VFS.h>
#include "../../../Files/PanelData.h"
#include "../../../Files/PanelView.h"
#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/Config.h"
#include "PanelBriefView.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";
vector<PanelViewPresentationItemsColoringRule> g_ColoringRules;

@interface PanelBriefViewItemCarrier : NSView

@property NSTextField *label;
@property NSColor *background;

@end

@implementation PanelBriefViewItemCarrier
{
    NSTextField *m_Label;
    NSColor *m_Background;
}

@synthesize label = m_Label;
@synthesize background = m_Background;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 50, 20)];
        m_Label.bordered = false;
        m_Label.editable = false;
        m_Label.drawsBackground = false;
        m_Label.font = [NSFont labelFontOfSize:13];
        m_Label.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:m_Label];
        
        m_Background = NSColor.yellowColor;
    }
    return self;
}

- (void) doLayout
{
    [m_Label setFrame:NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height)];
}

- (void)setFrameOrigin:(NSPoint)newOrigin
{
    [super setFrameOrigin:newOrigin];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self doLayout];
}

- (void) setFrame:(NSRect)frame
{
    [super setFrame:frame];
    [self doLayout];
}

//@property NSRect frame;

//-(id)initWithCoder:(NSCoder *)coder
//{
//    self = [super initWithCoder:coder];
//    if( self ) {
//        m_Label = [coder decodeObjectForKey:@"label"];
//        m_Background = [coder decodeObjectForKey:@"background"];
//    }
//    return self;
//}

//- (void)encodeWithCoder: (NSCoder *)coder
//{
//    [super encodeWithCoder:coder];
//    [coder encodeObject:m_Label forKey:@"label"];
//    [coder encodeObject:m_Background forKey: @"background"];
//}

- (void)drawRect:(NSRect)dirtyRect
{
    if( m_Background  ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    }
}

@end

@interface PanelBriefViewItem : NSCollectionViewItem

//@property (strong) NSView *view;

- (void) setItem:(VFSListingItem)_item;
- (void) setVD:(PanelData::PanelVolatileData)_vd;

@end

//- (void)prepareForReuse NS_AVAILABLE_MAC(10_11);

static auto g_ItemsCount = 0;

@implementation PanelBriefViewItem
{
    VFSListingItem                  m_Item;
    PanelData::PanelVolatileData    m_VD;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
}

- (nullable instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if( self ) {
//        static PanelBriefViewItemCarrier* proto = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
//        static
//        NSKeyedArchiver
//        static NSData *archived_proto = [NSKeyedArchiver archivedDataWithRootObject:proto];
//        NSView * myViewCopy = [NSKeyedUnarchiver unarchiveObjectWithData:archivedView];
        
        //self.view = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        
//        MachTimeBenchmark mtb;
self.view = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
//        self.view = [NSKeyedUnarchiver unarchiveObjectWithData:archived_proto];
//        mtb.ResetMicro("PanelBriefViewItemCarrier ");
        
        
        
        g_ItemsCount++;
//        cout << g_ItemsCount << endl;
    }
    return self;
}

- (void) dealloc
{
    g_ItemsCount--;
//    cout << g_ItemsCount << endl;
    
}

- (PanelBriefViewItemCarrier*) carrier
{
    return (PanelBriefViewItemCarrier*)self.view;
}

- (void) setItem:(VFSListingItem)_item
{
    m_Item = _item;
    
    self.carrier.label.stringValue = m_Item.NSDisplayName();
}

- (void)setSelected:(BOOL)selected
{
    if( self.selected == selected )
        return;
    [super setSelected:selected];
    
    if( selected )
        self.carrier.background = NSColor.blueColor;
    else
        self.carrier.background = nil/*NSColor.yellowColor*/;
    
    if( m_Item)
        [self updateColoring];
    [self.carrier setNeedsDisplay:true];
}

- (void) updateColoring
{
    assert( m_Item );
    for( const auto &i: g_ColoringRules ) {
        if( i.filter.Filter(m_Item, m_VD) ) {
            self.carrier.label.textColor = self.selected ? i.focused : i.regular;
            break;
        }
    }
}

- (void) setVD:(PanelData::PanelVolatileData)_vd
{
    if( m_VD == _vd )
        return;
    m_VD = _vd;
    [self updateColoring];
}

@end

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

@interface PanelBriefViewCollectionViewLayout : NSCollectionViewFlowLayout/*NSCollectionViewLayout*/

- (int) rowsCount;

@end

@implementation PanelBriefViewCollectionViewLayout

- (id) init
{
    self = [super init];
    if( self ) {
        self.minimumInteritemSpacing = 0;
        self.minimumLineSpacing = 0;
    }
    return self;
}

- (int) rowsCount
{
//    @property CGFloat minimumLineSpacing;
//    @property CGFloat minimumInteritemSpacing;
//    @property NSSize itemSize;
 
//@property (nullable, readonly, weak) NSCollectionView *collectionView;
    //double height = self.collectionView.bounds.size.height;
    
    double height = self.collectionViewContentSize.height;
//    self.m
    double n = floor(height / (self.itemSize.height  + self.minimumInteritemSpacing ));
//        double n = floor(height / (20  + 1));
    return int(n);
}

//- (nullable NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    NSCollectionViewLayoutAttributes *attributes = [self.class.layoutAttributesClass layoutAttributesForItemWithIndexPath:indexPath];
//    
////    NSSize res = NSMakeSize(50, 20);
//    int n = (int)indexPath.item;
//    int rows = self.rowsCount;
//
//    NSRect f;
//    f.origin.x = n * 100;
//    f.origin.y = (n % rows) * 20;
//    f.size.width = 100;
//    f.size.height = 20;
//    
//    
//    
//    attributes.frame = f;
////    [attributes setZIndex:[indexPath item]];
//    return attributes;
//}

//@property(readonly) NSSize collectionViewContentSize;

- (NSArray<__kindof NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(NSRect)rect
{
    NSArray<__kindof NSCollectionViewLayoutAttributes *> *attrs = [super layoutAttributesForElementsInRect:rect];
    const int items_per_column = self.rowsCount;
    
    struct Col {
        short width = 0;
        short origin = numeric_limits<short>::max();
    };
    vector<Col> columns;
    
    
    for( NSCollectionViewLayoutAttributes *i in attrs ) {
        const int index = (int)i.indexPath.item;
        const int row = index % items_per_column;
        const int col = index / items_per_column;
        NSRect orig_frame = i.frame;
        
        if( col >= columns.size() )
            columns.resize(col+1);
        
        if( columns[col].width < orig_frame.size.width )
            columns[col].width = orig_frame.size.width;
        if( columns[col].origin > orig_frame.origin.x )
            columns[col].origin = orig_frame.origin.x;
    }

    const double item_height = self.itemSize.height;
    for( NSCollectionViewLayoutAttributes *i in attrs ) {
        const int index = (int)i.indexPath.item;
        const int row = index % items_per_column;
        const int col = index / items_per_column;
        NSRect orig_frame = i.frame;
        
//        int x_origin = 0;
//        for( auto n = 0; n < col; ++n ) x_origin += column_widths[n];
        
        
        //NSRect new_frame = NSMakeRect(orig_frame.origin.x,
        NSRect new_frame = NSMakeRect(columns[col].origin,
//                                      row * (self.itemSize.height + self.minimumInteritemSpacing),
                                      row * item_height,
                                      columns[col].width,
                                      item_height);
        
        i.frame = new_frame;
        
    }
    
    return attrs;
    
    
}

- (NSArray<__kindof NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect11:(NSRect)rect
{
    //let frame = NSMakeRect(self.containerPadding.left, self.containerPadding.top + ((self.itemHeight + self.verticalSpacing) * CGFloat(indexPath.item)),

    int items_amount = (int)[self.collectionView numberOfItemsInSection:0];
    NSMutableArray<__kindof NSCollectionViewLayoutAttributes *> *attr_array = [[NSMutableArray alloc] init];
    
//    float ff = [(id<NSCollectionViewDelegateFlowLayout>)self.collectionView.delegate collectionView:self.collectionView layout:self minimumLineSpacingForSectionAtIndex:0];
    
    //- (CGFloat)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
    //{
    //    return 0;
    //}

    
//
    int items_per_column = self.rowsCount;

    double x_offset = 0;
    
    for( int i = 0; i < items_amount; ++i ) {
        NSIndexPath *ip = [NSIndexPath indexPathForItem:i inSection:0];
//        if( NSCollectionViewLayoutAttributes*  )
        double max_width = 0;
        double y_offset = 0;
//        for( int row = 0; row < items_per_column; ++row ) {
        for( int row = 0; row < 5; ++row ) {
//            NSSize sz = [(id<NSCollectionViewDelegateFlowLayout>)self.collectionView.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:ip];
            NSSize sz = NSMakeSize(50, 20);
            
            max_width = max(max_width, sz.width);
            
            NSRect frame = NSMakeRect(/*x_offset*/ 0,
                                      /*y_offset*/ row * 20,
                                      sz.width,
                                      sz.height);
            y_offset += sz.height;
            
////- (nullable NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
//            NSCollectionViewLayoutAttributes *attr = [self layoutAttributesForItemAtIndexPath:ip];
            NSCollectionViewLayoutAttributes *attr = [self.class.layoutAttributesClass layoutAttributesForItemWithIndexPath:ip];
            attr.frame = frame;
//                        attr.frame = NSMakeRect(300, 300, 100, 100);
//
//            FOUNDATION_EXPORT BOOL NSContainsRect(NSRect aRect, NSRect bRect);
//            FOUNDATION_EXPORT BOOL NSIntersectsRect(NSRect aRect, NSRect bRect);
//            
//            if( NSIntersectsRect(<#NSRect aRect#>, <#NSRect bRect#>)  )

//            if( NSContainsRect(rect, frame) )
                [attr_array addObject:attr];
            
//            let frame = NSMakeRect(self.containerPadding.left, self.containerPadding.top + ((self.itemHeight + self.verticalSpacing) * CGFloat(indexPath.item)), self.collectionViewContentSize.width - self.containerPadding.left - self.containerPadding.right, self.itemHeight)
//            
//            let itemAttributes = NSCollectionViewLayoutAttributes(forItemWithIndexPath: indexPath)
//            itemAttributes.frame = frame
            
            
            
        }
        break;
        x_offset += max_width;
    }
    
    return attr_array;
    
//[self.class.layoutAttributesClass layoutAttributesForItemWithIndexPath:indexPath];
    
}

//- (NSArray<__kindof NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(NSRect)rect
//{
//    NSArray<__kindof NSCollectionViewLayoutAttributes *> *a = [super layoutAttributesForElementsInRect:rect];
// 
//    if( a.count == 0 )
//        return a;
//    

    
/*
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [NSCollectionViewLayoutAttributes] {
        
        let defaultAttributes = super.layoutAttributesForElementsInRect(rect)
        
        if defaultAttributes.count == 0 {
            // we rely on 0th element being present,
            // bail if missing (when there's no work to do anyway)
            return defaultAttributes
        }
        
        var leftAlignedAttributes = [NSCollectionViewLayoutAttributes]()
        
        var xCursor = self.sectionInset.left // left margin
        
        // if/when there is a new row, we want to start at left margin
        // the default FlowLayout will sometimes centre items,
        // i.e. new rows do not always start at the left edge
        
        var lastYPosition = defaultAttributes[0].frame.origin.y
        
        for attributes in defaultAttributes {
            if attributes.frame.origin.y != lastYPosition {
                // we have changed line
                xCursor = self.sectionInset.left
                lastYPosition = attributes.frame.origin.y
            }
            
            attributes.frame.origin.x = xCursor
            // by using the minimumInterimitemSpacing we no we'll never go
            // beyond the right margin, so no further checks are required
            xCursor += attributes.frame.size.width + minimumInteritemSpacing
            
            leftAlignedAttributes.append(attributes)
        }
        return leftAlignedAttributes
    }
*/
    
//    
//    return a;
//}

@end


@implementation PanelBriefView
{
    NSScrollView                        *m_ScrollView;
    PanelBriefViewCollectionView        *m_CollectionView;
    PanelBriefViewCollectionViewLayout  *m_Layout;
    
    PanelData                       *m_Data;
//    int                 m_CursorPosition;
}

//@synthesize cursorPosition = m_CursorPosition;

//@property (nonatomic) int cursorPosition;

//NSCollectionViewDelegate, NSCollectionViewDataSource

- (void) setData:(PanelData*)_data
{
    m_Data = _data;
    
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
        
        
        
//        m_Data = &_data;
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

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSSize res = NSMakeSize(100, 20);
//    res.width += indexPath.item * 10;
    
//    return res;
    
    
    auto item = m_Data->EntryAtSortPosition( (int)indexPath.item );
    if( !item )
        return res;

    static auto attrs = @{NSFontAttributeName:[NSFont labelFontOfSize:13]};
    
//    NSRect rc = [[item.NSDisplayName() copy]boundingRectWithSize:NSMakeSize(10000, 500)
//                                                   options:0
//                                                attributes:attrs
//                                                   context:nil];
    NSRect rc = [item.NSDisplayName() boundingRectWithSize:NSMakeSize(10000, 500)
                                                         options:0
                                                      attributes:attrs
                                                         context:nil];

    
    
    
//    return NSMakeSize(200, 20);
    
    rc.size.width += 6;
    rc.size.width = floor( rc.size.width + 0.5 );
    
//    res.width += rand() % 100;
    
//    return res;
    
    if( rc.size.width < 50 )
        res.width = 50;
    else if( rc.size.width > 200 )
        res.width = 200;
    else
        res.width = rc.size.width;
    
//    cout << res.width << endl;
    
//    return NSMakeSize(rc.size.width, 20);
    return res;
}

- (void) dataChanged
{
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

//- (NSArray<NSCollectionViewItem *> *)visibleItems

@end
