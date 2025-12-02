// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItem.h"
#include "PanelGalleryCollectionViewItemCarrier.h"

using namespace nc::panel::gallery;

@implementation NCPanelGalleryCollectionViewItem {
//    NSImageView *m_ImageView;
//    NSTextField *m_Label;
//    ItemLayout m_ItemLayout;
    
    
    NCPanelGalleryCollectionViewItemCarrier *m_Carrier; // == self.view
}

//@synthesize itemLayout = m_ItemLayout;

- (instancetype)initWithNibName:(nullable NSString *) [[maybe_unused]] _nib_name_or_nil
                         bundle:(nullable NSBundle *) [[maybe_unused]] _nib_bundle_or_nil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
//        m_PanelActive = false;
        const auto rc = NSMakeRect(0, 0, 10, 10);
        m_Carrier = [[NCPanelGalleryCollectionViewItemCarrier alloc] initWithFrame:rc];
        m_Carrier.controller = self;
        self.view = m_Carrier;
    }
    return self;
}

//- (void)viewDidLoad
//{
//    [super viewDidLoad];
//
//    self.view.wantsLayer = YES; // Required for layer-backed background
//
//    m_ImageView = [[NSImageView alloc]
//        initWithFrame:NSMakeRect(0, 20, self.view.bounds.size.width, self.view.bounds.size.height - 20)];
//    m_ImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
//    m_ImageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
//
//    m_Label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, self.view.bounds.size.width, 20)];
//    m_Label.editable = NO;
//    m_Label.bezeled = NO;
//    m_Label.drawsBackground = NO;
//    m_Label.alignment = NSTextAlignmentCenter;
//    m_Label.font = [NSFont systemFontOfSize:12];
//    m_Label.autoresizingMask = NSViewWidthSizable;
//
//    [self.view addSubview:m_ImageView];
//    [self.view addSubview:m_Label];
//
//    self.imageView = m_ImageView;
//    self.textField = m_Label;
//}

- (void)prepareForReuse
{
    [super prepareForReuse];
    // TODO: implement    
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];

    if( selected ) {
        self.view.layer.backgroundColor = [[NSColor selectedContentBackgroundColor] CGColor];
    }
    else {
        self.view.layer.backgroundColor = [[NSColor clearColor] CGColor];
    }
}

//@property (nonatomic) NSImage *icon;

- (void)setIcon:(NSImage *)_icon
{
    m_Carrier.icon = _icon;
}

- (NSImage*)icon
{
    return m_Carrier.icon;
}

- (ItemLayout)itemLayout
{
    return m_Carrier.itemLayout;
}

- (void)setItemLayout:(ItemLayout)_item_layout
{
    m_Carrier.itemLayout = _item_layout;    
}

@end
