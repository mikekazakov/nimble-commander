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

@property (nonatomic) VFSListingItem item;
@property (nonatomic) PanelData::PanelVolatileData vd;

- (PanelListView*)listView;

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
    if( auto v = objc_cast<NSTableRowView>(self.superview) ) {
        
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        
        if( auto c = v.backgroundColor  ) {
            CGContextSetFillColorWithColor(context, c.CGColor);
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
        }
    }
    
//@property(copy) NSColor *backgroundColor;    
    
//    NSDictionary *attr = @{NSFontAttributeName: [NSFont systemFontOfSize:13],
//                           NSForegroundColorAttributeName: NSColor.blackColor,
//                           NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};

    
    [m_Filename drawWithRect:self.bounds
                     options:0
                  attributes:m_TextAttributes];
    
    
}

- (void) buildPresentation
{
//    if( self.briefView ) {

//    }
    
    NSColor *text_color = NSColor.blackColor;
    PanelListViewRowView* row_view = (PanelListViewRowView*)self.superview;
    const auto &rules = row_view.listView.coloringRules;
//    const bool focus = self.selected && m_PanelActive;
    const bool focus = row_view.selected;
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
    
    
}


@end


//- (void) setVD:(PanelData::PanelVolatileData)_vd;
@implementation PanelListViewRowView
{
    VFSListingItem                  m_Item;
    PanelData::PanelVolatileData    m_VD;
}

- (void) setItem:(VFSListingItem)item
{
    if( m_Item != item ) {
        m_Item = item;
        /// ...
    }
}

- (VFSListingItem) item
{
    return m_Item;
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
//    int a = 10;
    if( selected != self.selected ) {
        [super setSelected:selected];

        
//@property(copy) NSColor *backgroundColor;        
  
        if( selected ) {
            self.backgroundColor = NSColor.blueColor;
            
            
        }
        else {
            
            self.backgroundColor = NSColor.controlAlternatingRowBackgroundColors[0];
        }
        
        [self notifySubviewsToRebuildPresentation];
    }
}

- (PanelListView*)listView
{
    return (PanelListView*)((NSTableView*)self.superview).delegate;
}

- (void) notifySubviewsToRebuildPresentation
{
    for( NSView *w in self.subviews ) {
        if( [w respondsToSelector:@selector(buildPresentation)] )
            [(id)w buildPresentation];
        [w setNeedsDisplay:true];
    }
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
//        m_ScrollView.canDrawSubviewsIntoLayer = true;
        m_ScrollView.hasVerticalScroller = true;
//        @property BOOL hasHorizontalScroller;
//        @property BOOL canDrawSubviewsIntoLayer NS_AVAILABLE_MAC(10_9);
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

        
        NSTableColumn *col1 = [[NSTableColumn alloc] initWithIdentifier:@"A"];
        col1.title = @"Abra";
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
            
            PanelListViewRowView *row_view = [[PanelListViewRowView alloc] initWithFrame:NSRect()];
            row_view.item = item;
            row_view.vd = vd;
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
    MachTimeBenchmark mtb;
    [m_ScrollView layoutSubtreeIfNeeded];
    mtb.ResetMicro();
    
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
