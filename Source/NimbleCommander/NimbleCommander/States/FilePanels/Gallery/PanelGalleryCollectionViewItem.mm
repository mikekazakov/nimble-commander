// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItem.h"
#include "PanelGalleryCollectionViewItemCarrier.h"
#include <NimbleCommander/Core/Theming/Theme.h>
#include <Utility/ObjCpp.h>
#include <cassert>

using namespace nc::panel::gallery;

@implementation NCPanelGalleryCollectionViewItem {
    VFSListingItem m_Item;
    nc::panel::data::ItemVolatileData m_VD;
    bool m_PanelActive;
}

- (instancetype)initWithNibName:(nullable NSString *) [[maybe_unused]] _nib_name_or_nil
                         bundle:(nullable NSBundle *) [[maybe_unused]] _nib_bundle_or_nil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        m_PanelActive = true;
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
    [super prepareForReuse];
    m_Item = VFSListingItem{};
    m_VD = nc::panel::data::ItemVolatileData{};
    m_PanelActive = false;
    [super setSelected:false];
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

    [self updateBackgroundColor];

    //    [self updateBackgroundColor];
    //    [self updateForegroundColor];
    //    [self updateAccentColor];

    //    if( selected ) {
    //        self.view.layer.backgroundColor = [[NSColor selectedContentBackgroundColor] CGColor];
    //    }
    //    else {
    //        self.view.layer.backgroundColor = [[NSColor clearColor] CGColor];
    //    }
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

- (void)setVd:(nc::panel::data::ItemVolatileData)_vd
{
    if( m_VD == _vd )
        return;
    m_VD = _vd;

    [self updateBackgroundColor];

    //    [self updateBackgroundColor];
    //    [self updateAccentColor];
    //    self.carrier.qsHighlight = _vd.highlight;
    //    self.carrier.highlighted = _vd.is_highlighted();
}

- (nc::panel::data::ItemVolatileData)vd
{
    return m_VD;
}

static NSColor *Blend(NSColor *_front, NSColor *_back)
{
    const auto alpha = _front.alphaComponent;
    if( alpha == 1. )
        return _front;
    if( alpha == 0. )
        return _back;

    const auto cs = NSColorSpace.genericRGBColorSpace;
    _front = [_front colorUsingColorSpace:cs];
    _back = [_back colorUsingColorSpace:cs];
    const auto r = (_front.redComponent * alpha) + (_back.redComponent * (1. - alpha));
    const auto g = (_front.greenComponent * alpha) + (_back.greenComponent * (1. - alpha));
    const auto b = (_front.blueComponent * alpha) + (_back.blueComponent * (1. - alpha));
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.];
}

- (void)updateBackgroundColor
{
    NSColor *const front_color = [&] -> NSColor * {
        if( self.selected ) {

            if( m_PanelActive )
                return nc::CurrentTheme().FilePanelsBriefFocusedActiveItemBackgroundColor();
            else
                return nc::CurrentTheme().FilePanelsBriefFocusedInactiveItemBackgroundColor();
        }
        else {
            if( m_VD.is_selected() ) {
                return nc::CurrentTheme().FilePanelsBriefSelectedItemBackgroundColor();
            }
            else {
                return nil;
            }
        }
    }();
    NSColor *const back_color = nc::CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor();
    NSColor *const final_color = [&] -> NSColor * {
        if( front_color ) {
            const auto alpha = front_color.alphaComponent;
            if( alpha == 1. )
                return front_color;
            return Blend(front_color, back_color);
        }
        else {
            return back_color;
        }
    }();
    self.carrier.backgroundColor = final_color;
}

- (void)setPanelActive:(bool)_active
{
    if( m_PanelActive == _active )
        return;
    m_PanelActive = _active;

    // update?
    [self updateBackgroundColor];
}

- (bool)panelActive
{
    return m_PanelActive;
}

@end
