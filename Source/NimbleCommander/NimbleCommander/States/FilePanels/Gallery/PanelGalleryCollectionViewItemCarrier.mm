// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItemCarrier.h"
#include "PanelGalleryCollectionViewItem.h"

using namespace nc::panel::gallery;

@implementation NCPanelGalleryCollectionViewItemCarrier {
    __weak NCPanelGalleryCollectionViewItem *m_Controller;
    NSImage *m_Icon;
    NSString *m_Filename;
    ItemLayout m_ItemLayout;
}

@synthesize controller = m_Controller;
@synthesize icon = m_Icon;
@synthesize filename = m_Filename;
@synthesize itemLayout = m_ItemLayout;

//@property(nonatomic, weak) NCPanelGalleryCollectionViewItem *controller;
//@property(nonatomic) NSImage *icon;
//@property(nonatomic) NSString *filename;
//@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.autoresizingMask = NSViewNotSizable;
        self.autoresizesSubviews = false;
        //        self.postsFrameChangedNotifications = false; // ???
        //        self.postsBoundsChangedNotifications = false; // ???
    }
    return self;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)wantsDefaultClipping
{
    return false;
}

- (void)drawRect:(NSRect) [[maybe_unused]] _dirty_rect
{
    const auto bounds = self.bounds;
    const auto context = NSGraphicsContext.currentContext.CGContext;

    NSColor *background = NSColor.purpleColor; // ????????????????????????????
    CGContextSetFillColorWithColor(context, background.CGColor);
    CGContextFillRect(context, bounds);

    const auto icon_rect = NSMakeRect(m_ItemLayout.icon_left_margin,
                                      bounds.size.height - static_cast<double>(m_ItemLayout.icon_top_margin) -
                                          static_cast<double>(m_ItemLayout.icon_size),
                                      m_ItemLayout.icon_size,
                                      m_ItemLayout.icon_size);
    [m_Icon drawInRect:icon_rect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0
        respectFlipped:false
                 hints:nil];
}

@end
