// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ByteCountFormatter.h>
#include "../PanelViewPresentationSettings.h"
#include "PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewSizeView.h"

using namespace nc::panel;

// use values from 0xFFFFFFFFFFFFFFFDu to encode additional states
static const auto g_InvalidSize                 = 0xFFFFFFFFFFFFFFFFu;
static const auto g_NonCalculatedSizeForDotDot  = g_InvalidSize - 1;
static const auto g_NonCalculatedSizeForDir     = g_InvalidSize - 2;

static uint64_t ExtractSizeFromInfos(const VFSListingItem &_dirent,
                                     const data::ItemVolatileData &_vd)
{
    if( _dirent.IsDir() ) {
        if( _vd.is_size_calculated() )
            return _vd.size;
        else
            return _dirent.IsDotDot() ? g_NonCalculatedSizeForDotDot : g_NonCalculatedSizeForDir;
    }
    else {
        return _dirent.Size();
    }
}

static NSString *SizeStringFromEncodedSize( uint64_t _sz )
{
    if( _sz == g_InvalidSize )
        return @"";
    if( _sz == g_NonCalculatedSizeForDir )
        return NSLocalizedString(@"__MODERNPRESENTATION_FOLDER_WORD", "Folders dummy string when size is not available, for English is 'Folder'");
    if( _sz == g_NonCalculatedSizeForDotDot )
        return NSLocalizedString(@"__MODERNPRESENTATION_UP_WORD", "Upper-level in directory, for English is 'Up'");

    return ByteCountFormatter::Instance().ToNSString( _sz, GetFileSizeFormat() );
}

@implementation PanelListViewSizeView
{
    NSString        *m_String;
    NSDictionary    *m_TextAttributes;
    uint64_t         m_Size;
    __weak PanelListViewRowView *m_RowView;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Size = g_InvalidSize;
        m_String = @"";
    }
    return self;
}

- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (void) viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    if( auto rv = objc_cast<PanelListViewRowView>(self.superview) )
        m_RowView = rv;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Size = g_InvalidSize;
    m_String = @"";
}

- (void) drawRect:(NSRect)dirtyRect
{
    if( auto rv = m_RowView ) {
        if( auto lv = rv.listView ) {

            const auto bounds = self.bounds;
            const auto geometry = lv.geometry;
            
            [rv.rowBackgroundColor set];
            NSRectFill(self.bounds);
            DrawTableVerticalSeparatorForView(self);
            
            const auto text_rect = NSMakeRect(geometry.LeftInset(),
                                              geometry.TextBaseLine(),
                                              bounds.size.width -  geometry.LeftInset() - geometry.RightInset(),
                                              0);
            [m_String drawWithRect:text_rect
                           options:0
                        attributes:m_TextAttributes
                           context:nil];
        }
    }
}

static NSParagraphStyle *PStyle()
{
    static const auto style = []{
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.alignment = NSTextAlignmentRight;
        p.lineBreakMode = NSLineBreakByClipping;
        return p;
    }();
    return style;
}

- (void) setSizeWithItem:(const VFSListingItem &)_dirent
                   andVD:(const data::ItemVolatileData &)_vd
{
    if( !_dirent )
        return;
    
    const auto new_sz = ExtractSizeFromInfos( _dirent, _vd );
    if( new_sz != m_Size ) {
        m_Size = new_sz;
        m_String = SizeStringFromEncodedSize( m_Size );
        [self setNeedsDisplay:true];
    }
}

- (void) buildPresentation
{
    if( auto row_view = objc_cast<PanelListViewRowView>(self.superview) ) {
        m_TextAttributes = @{NSFontAttributeName: row_view.listView.font,
                             NSForegroundColorAttributeName: row_view.rowTextColor,
                             NSParagraphStyleAttributeName: PStyle()};
        [self setNeedsDisplay:true];
    }
}

@end
