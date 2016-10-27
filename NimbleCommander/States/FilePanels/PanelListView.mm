#include "../../../Files/Config.h"
#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/PanelData.h"
#include "../../../Files/PanelView.h"
#include "PanelListView.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";

static NSParagraphStyle *ParagraphStyle( NSLineBreakMode _mode )
{
    static NSParagraphStyle *styles[3];
    static once_flag once;
    call_once(once, []{
        NSMutableParagraphStyle *p0 = [NSMutableParagraphStyle new];
        p0.alignment = NSLeftTextAlignment;
        p0.lineBreakMode = NSLineBreakByTruncatingHead;
        styles[0] = p0;
        
        NSMutableParagraphStyle *p1 = [NSMutableParagraphStyle new];
        p1.alignment = NSLeftTextAlignment;
        p1.lineBreakMode = NSLineBreakByTruncatingTail;
        styles[1] = p1;
        
        NSMutableParagraphStyle *p2 = [NSMutableParagraphStyle new];
        p2.alignment = NSLeftTextAlignment;
        p2.lineBreakMode = NSLineBreakByTruncatingMiddle;
        styles[2] = p2;
    });
    
    switch( _mode ) {
        case NSLineBreakByTruncatingHead:   return styles[0];
        case NSLineBreakByTruncatingTail:   return styles[1];
        case NSLineBreakByTruncatingMiddle: return styles[2];
        default:                            return nil;
    }
}

@interface PanelListViewRowView : NSTableRowView

- (id) initWithItem:(VFSListingItem)_item atIndex:(int)index;

@property (nonatomic, readonly) VFSListingItem item;
@property (nonatomic) PanelData::PanelVolatileData vd;
@property (nonatomic, weak) PanelListView *listView;
@property (nonatomic, readonly) NSColor *rowColor;
@property (nonatomic) bool panelActive;
@property (nonatomic, readonly) int itemIndex;

//- (void) setPanelActive:(bool)_active;

@end

@interface PanelListViewNameView : NSView

- (void) setFilename:(NSString*)_filename;

@end

@implementation PanelListViewNameView
{
    NSString        *m_Filename;
    NSDictionary    *m_TextAttributes;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
//        m_Filename = _filename;
//        self.wantsLayer = true;

    }
    return self;
}

- (void) setFilename:(NSString*)_filename
{
    m_Filename = _filename;
}

- (void) drawRect:(NSRect)dirtyRect
{
    if( auto v = objc_cast<PanelListViewRowView>(self.superview) ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        
        if( auto c = v.rowColor  ) {
            CGContextSetFillColorWithColor(context, c.CGColor);
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
        }
    }
    
    [m_Filename drawWithRect:self.bounds
                     options:0
                  attributes:m_TextAttributes];
}

- (void) buildPresentation
{
    auto text_color = NSColor.blackColor;
    const auto row_view = (PanelListViewRowView*)self.superview;
    const auto list_view = row_view.listView;
    const auto &rules = row_view.listView.coloringRules;
    const auto focus = row_view.selected && row_view.panelActive;
    const auto item = row_view.item;
    const auto vd = row_view.vd;
    for( const auto &i: rules )
        if( i.filter.Filter(item, vd) ) {
            text_color = focus ? i.focused : i.regular;
            break;
        }
    
    m_TextAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:13],
                         NSForegroundColorAttributeName: text_color,
                         NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};
    
    [self setNeedsDisplay:true];
}

@end


@implementation PanelListViewRowView
{
    VFSListingItem                  m_Item;
    PanelData::PanelVolatileData    m_VD;
    NSColor*                        m_RowColor;
    bool                            m_PanelActive;
    int                             m_ItemIndex;
}
//@property (nonatomic) int itemIndex;
@synthesize rowColor = m_RowColor;
@synthesize itemIndex = m_ItemIndex;
@synthesize item = m_Item;

- (id) initWithItem:(VFSListingItem)_item atIndex:(int)index;
//- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
        m_Item = _item;
        m_ItemIndex = index;
        m_RowColor = NSColor.blackColor;
        self.selected = false;
        [self updateBackgroundColor];
        m_PanelActive = false;
    }
    return self;
}

- (void) setPanelActive:(bool)panelActive
{
    if( m_PanelActive != panelActive ) {
        m_PanelActive = panelActive;
        
        if( self.selected )
            [self updateBackgroundColor];    
    }
}

- (bool) panelActive
{
    return m_PanelActive;
}

- (void) setVd:(PanelData::PanelVolatileData)vd
{
    if( m_VD != vd ) {
        m_VD = vd;
        // ....
        [self notifySubviewsToRebuildPresentation];
    }
}

- (PanelData::PanelVolatileData) vd
{
    return m_VD;
}

- (void) setSelected:(BOOL)selected
{
    if( selected != self.selected ) {
        [super setSelected:selected];
        [self updateBackgroundColor];
        [self notifySubviewsToRebuildPresentation];
    }
}

- (void) updateBackgroundColor
{
//@property(getter=isEmphasized) BOOL emphasized;    
    
    if( self.selected ) {
        m_RowColor = m_PanelActive ? NSColor.blueColor : NSColor.lightGrayColor;
    }
    else {
        m_RowColor = m_ItemIndex % 2 ? NSColor.controlAlternatingRowBackgroundColors[1] : NSColor.controlAlternatingRowBackgroundColors[0];
    }
    
    for( NSView *w in self.subviews )
        [w setNeedsDisplay:true];
    [self setNeedsDisplay:true];
    
}

- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSetFillColorWithColor(context, m_RowColor.CGColor);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

- (void)viewDidMoveToSuperview
{
    if( self.superview )
        [self notifySubviewsToRebuildPresentation];
    
}

- (void) notifySubviewsToRebuildPresentation
{
    for( NSView *w in self.subviews ) {
        if( [w respondsToSelector:@selector(buildPresentation)] )
            [(id)w buildPresentation];
        [w setNeedsDisplay:true];
    }
}

- (void)didAddSubview:(NSView *)subview
{
    if( [subview respondsToSelector:@selector(buildPresentation)] )
        [(id)subview buildPresentation];
}

@end

@interface PanelListViewTableView : NSTableView

@end

@implementation PanelListViewTableView

- (BOOL)acceptsFirstResponder
{
    return false;
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


@implementation PanelListView
{
    NSScrollView                       *m_ScrollView;
    PanelListViewTableView             *m_TableView;
    PanelData                          *m_Data;
    __weak PanelView                   *m_PanelView;    
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_ScrollView = [[NSScrollView alloc] initWithFrame:frameRect];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_ScrollView.wantsLayer = true;
        m_ScrollView.layer.drawsAsynchronously = true;
        m_ScrollView.contentView.copiesOnScroll = true;
        m_ScrollView.hasVerticalScroller = true;
        [self addSubview:m_ScrollView];
    
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ScrollView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ScrollView]-(0)-|" options:0 metrics:nil views:views]];

        m_TableView = [[PanelListViewTableView alloc] initWithFrame:frameRect];
        m_TableView.dataSource = self;
        m_TableView.delegate = self;
        m_TableView.allowsMultipleSelection = false;
        m_TableView.allowsEmptySelection = false;
        m_TableView.allowsColumnSelection = false;
        m_TableView.usesAlternatingRowBackgroundColors = true;
        
        NSTableColumn *col1 = [[NSTableColumn alloc] initWithIdentifier:@"A"];
        col1.title = @"Name";
        col1.width = 200;
        [m_TableView addTableColumn:col1];

        NSTableColumn *col2 = [[NSTableColumn alloc] initWithIdentifier:@"B"];
        col2.title = @"Cadabra";
        col2.width = 200;
        [m_TableView addTableColumn:col2];
        
        
        m_ScrollView.documentView = m_TableView;
        
        
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
//        for( PanelBriefViewItem *i in m_CollectionView.visibleItems )
//            [i setPanelActive:active];
        [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
            rowView.panelActive = active;
        }];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Data ? m_Data->SortedDirectoryEntries().size() : 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if( !m_Data )
        return nil;
    
    if( PanelListViewRowView *w = objc_cast<PanelListViewRowView>([tableView rowViewAtRow:row makeIfNecessary:false]) ) {
        
        if( auto vfs_item = w.item ) {
            NSString *identifier = tableColumn.identifier;
            
            unichar col_id = [identifier characterAtIndex:0];
            if( col_id == 'A' ) {
                PanelListViewNameView *nv = [tableView makeViewWithIdentifier:identifier owner:self];
                if( !nv ) {
                    nv = [[PanelListViewNameView alloc] initWithFrame:NSRect()];
                    nv.identifier = identifier;
                }
                
                [nv setFilename:vfs_item.NSDisplayName()];
                
                return nv;
            }
        }
        
        
    }
    
    
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    if( m_Data ) {
        if( auto item = m_Data->EntryAtSortPosition((int)row) ) {
            auto &vd = m_Data->VolatileDataAtSortPosition((int)row);
            
            PanelListViewRowView *row_view = [[PanelListViewRowView alloc] initWithItem:item atIndex:(int)row];
            row_view.listView = self;
//            row_view.item = item;
//            row_view.itemIndex = (int)row;
            row_view.vd = vd;
            row_view.panelActive = m_PanelView.active;
            return row_view;
        }
    }
    return nil;
}

- (void) dataChanged
{
    [m_TableView reloadData];
}

- (void) syncVolatileData
{
    [m_TableView enumerateAvailableRowViewsUsingBlock:^(PanelListViewRowView *rowView, NSInteger row) {
        rowView.vd = m_Data->VolatileDataAtSortPosition((int)row);
    }];
}

- (void) setData:(PanelData*)_data
{
    m_Data = _data;
    [self dataChanged];    
}

- (int)itemsInColumn
{
    return 0;
}

- (void)setCursorPosition:(int)cursorPosition
{
    [m_TableView selectRowIndexes:[NSIndexSet indexSetWithIndex:cursorPosition]
             byExtendingSelection:false];
}

- (void)frameDidChange
{
//    MachTimeBenchmark mtb;
    [m_ScrollView layoutSubtreeIfNeeded];
//    mtb.ResetMicro();
    
}


//
//@property (nonatomic, readonly) int itemsInColumn;
//@property (nonatomic) int cursorPosition;

- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules
{
//    return g_ColoringRules;
    static vector<PanelViewPresentationItemsColoringRule> rules;
    static once_flag once;
    call_once(once,[]{
        auto cr = GlobalConfig().Get(g_ConfigColoring);
        if( cr.IsArray() )
            for( auto i = cr.Begin(), e = cr.End(); i != e; ++i )
                rules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
        rules.emplace_back(); // always have a default ("others") non-filtering filter at the back
    });
    return rules;
}

@end
