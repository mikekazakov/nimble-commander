// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewCollectionViewLayout.h"

@implementation PanelBriefViewCollectionViewLayout
{
    vector<int> m_ColumnPositions;
    vector<int> m_ColumnWidths;
}

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
    const double view_height = self.collectionView.bounds.size.height;
    const double item_height = self.itemSize.height;
    const double n = floor(view_height / item_height);
    return int(n);
}

- (NSArray<__kindof NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(NSRect)rect
{
    const auto orig_attrs = [super layoutAttributesForElementsInRect:rect];
    const auto attrs = [[NSArray alloc] initWithArray:orig_attrs copyItems:true];

    const int items_per_column = self.rowsCount;
    if( !items_per_column )
        return attrs;
    
    const double item_height = self.itemSize.height;
    
    struct Col {
        int width = 0;
        int origin = numeric_limits<int>::max();
    };
    vector<Col> columns;
    
    for( NSCollectionViewLayoutAttributes *i in attrs ) {
        const int index = (int)i.indexPath.item;
        const int col = index / items_per_column;
        
        if( col >= (int)columns.size() )
            columns.resize(col+1);
        
        const NSRect orig_frame = i.frame;
        if( columns[col].width < orig_frame.size.width )
            columns[col].width = int(orig_frame.size.width);
        if( columns[col].origin > orig_frame.origin.x )
            columns[col].origin = int(orig_frame.origin.x);
    }
    
    for( NSCollectionViewLayoutAttributes *i in attrs ) {
        const int index = (int)i.indexPath.item;
        const int row = index % items_per_column;
        const int col = index / items_per_column;
        
        NSRect new_frame = NSMakeRect(columns[col].origin,
                                      row * item_height,
                                      columns[col].width,
                                      item_height);
        
        i.frame = new_frame;
    }
    
    if( m_ColumnPositions.size() < columns.size() )
        m_ColumnPositions.resize( columns.size(), numeric_limits<int>::max() );
    if( m_ColumnWidths.size() < columns.size() )
        m_ColumnWidths.resize(columns.size(), 0);
    
    bool any_changes = false;
    for( int i = 0, e = (int)columns.size(); i != e; ++i ) {
        if( columns[i].origin != numeric_limits<int>::max() ) {
            if(columns[i].origin != m_ColumnPositions[i]) {
                m_ColumnPositions[i] = columns[i].origin;
                any_changes = true;
            }
        }
        if( columns[i].width != 0 ) {
            if( columns[i].width != m_ColumnWidths[i] ) {
                m_ColumnWidths[i] = columns[i].width;
                any_changes = true;
            }
        }
    }

    static const bool draws_grid =
        [self.collectionView respondsToSelector:@selector(setBackgroundViewScrollsWithContent:)];
    if( draws_grid && any_changes )
        [self.collectionView.backgroundView setNeedsDisplay:true];

    return attrs;
}

- (const vector<int>&) columnPositions
{
    dispatch_assert_main_queue();
    return m_ColumnPositions;
}

- (const vector<int>&) columnWidths
{
    dispatch_assert_main_queue();
    return m_ColumnWidths;
}

@end

