#include "PanelBriefViewCollectionViewLayout.h"

@implementation PanelBriefViewCollectionViewLayout

- (id) init
{
    self = [super init];
    if( self ) {
        self.minimumInteritemSpacing = 0;
        self.minimumLineSpacing = 0;
        self.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
    }
    return self;
}

- (int) rowsCount
{
    const double view_height = self.collectionViewContentSize.height;
    const double item_height = self.itemSize.height;
    const double n = floor(view_height / item_height);
    return int(n);
}

- (NSArray<__kindof NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(NSRect)rect
{
    NSArray<__kindof NSCollectionViewLayoutAttributes *> *attrs = [super layoutAttributesForElementsInRect:rect];
    
    const int items_per_column = self.rowsCount;
    const double item_height = self.itemSize.height;
    
    struct Col {
        int width = 0;
        int origin = numeric_limits<int>::max();
    };
    vector<Col> columns;
    
    for( NSCollectionViewLayoutAttributes *i in attrs ) {
        const int index = (int)i.indexPath.item;
        const int row = index % items_per_column;
        const int col = index / items_per_column;
        
        if( col >= columns.size() )
            columns.resize(col+1);
        
        const NSRect orig_frame = i.frame;
        if( columns[col].width < orig_frame.size.width )
            columns[col].width = orig_frame.size.width;
        if( columns[col].origin > orig_frame.origin.x )
            columns[col].origin = orig_frame.origin.x;
    }
    
    for( NSCollectionViewLayoutAttributes *i in attrs ) {
        const int index = (int)i.indexPath.item;
        const int row = index % items_per_column;
        const int col = index / items_per_column;
        const NSRect orig_frame = i.frame;
        
        NSRect new_frame = NSMakeRect(columns[col].origin,
                                      row * item_height,
                                      columns[col].width,
                                      item_height);
        
        i.frame = new_frame;
    }

    return attrs;
}

@end

