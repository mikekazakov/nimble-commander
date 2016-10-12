#include "PanelBriefViewCollectionViewLayout.h"

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
    const double view_height = self.collectionViewContentSize.height;
    const double item_height = self.itemSize.height;
    const double n = floor(view_height / item_height);
    return int(n);
}

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
@end

