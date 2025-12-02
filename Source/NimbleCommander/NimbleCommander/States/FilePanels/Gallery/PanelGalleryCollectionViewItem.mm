// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItem.h"
#include "PanelGalleryCollectionViewItemCarrier.h"
#include <Utility/ObjCpp.h>
#include <cassert>

using namespace nc::panel::gallery;

@implementation NCPanelGalleryCollectionViewItem {
    VFSListingItem m_Item;
    //    data::ItemVolatileData m_VD; // TODO
}

//@synthesize itemLayout = m_ItemLayout;

- (instancetype)initWithNibName:(nullable NSString *) [[maybe_unused]] _nib_name_or_nil
                         bundle:(nullable NSBundle *) [[maybe_unused]] _nib_bundle_or_nil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        //        m_PanelActive = false;
        const auto rc = NSMakeRect(0, 0, 10, 10);
        const auto carrier = [[NCPanelGalleryCollectionViewItemCarrier alloc] initWithFrame:rc];
        carrier.controller = self;
        self.view = carrier;
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
    //    [super prepareForReuse];
    // TODO: implement

    [super prepareForReuse];
    m_Item = VFSListingItem{};
    //    m_VD = data::ItemVolatileData{};
    //    m_PanelActive = false;
    //    [super setSelected:false];
    //    self.carrier.backgroundColor = nil;
    //    self.carrier.tagAccentColor = nil;
    //    self.carrier.qsHighlight = {};
}

- (NCPanelGalleryCollectionViewItemCarrier *)carrier
{
    assert(nc::objc_cast<NCPanelGalleryCollectionViewItemCarrier>(self.view));
    return static_cast<NCPanelGalleryCollectionViewItemCarrier *>(self.view);
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

- (void)setIcon:(NSImage *)_icon
{
    self.carrier.icon = _icon;
}

- (NSImage *)icon
{
    return self.carrier.icon;
}

- (ItemLayout)itemLayout
{
    return self.carrier.itemLayout;
}

- (void)setItemLayout:(ItemLayout)_item_layout
{
    self.carrier.itemLayout = _item_layout;
}

- (VFSListingItem)item
{
    return m_Item;
}

- (void)setItem:(VFSListingItem)_item
{
    m_Item = _item;
    self.carrier.filename = m_Item.DisplayNameNS();
    //    self.carrier.isSymlink = m_Item.IsSymlink();
    //    [self updateItemLayout];
}

@end
