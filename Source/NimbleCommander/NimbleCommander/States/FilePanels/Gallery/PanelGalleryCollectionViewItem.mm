// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItem.h"
#include "PanelGalleryCollectionViewItemCarrier.h"
#include <Panel/UI/PanelViewPresentationItemsColoringFilter.h>
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

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Item = VFSListingItem{};
    m_VD = nc::panel::data::ItemVolatileData{};
    m_PanelActive = false;
    [super setSelected:false];
    //    self.carrier.backgroundColor = nil;
    self.carrier.qsHighlight = {};
}

- (NCPanelGalleryCollectionViewItemCarrier *)carrier
{
    assert(nc::objc_cast<NCPanelGalleryCollectionViewItemCarrier>(self.view));
    return static_cast<NCPanelGalleryCollectionViewItemCarrier *>(self.view);
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateForegroundColor];
    [self updateBackgroundColor];
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

    [self updateForegroundColor];
    [self updateBackgroundColor];
    self.carrier.qsHighlight = _vd.highlight;
    //    self.carrier.highlighted = _vd.is_highlighted();
}

- (nc::panel::data::ItemVolatileData)vd
{
    return m_VD;
}

- (NSColor *)deduceBackgroundColor
{
    if( self.selected ) {
        if( m_PanelActive )
            return nc::CurrentTheme().FilePanelsGalleryFocusedActiveItemBackgroundColor();
        else
            return nc::CurrentTheme().FilePanelsGalleryFocusedInactiveItemBackgroundColor();
    }
    else {
        if( m_VD.is_selected() ) {
            return nc::CurrentTheme().FilePanelsGallerySelectedItemBackgroundColor();
        }
        else {
            return nc::CurrentTheme().FilePanelsGalleryBackgroundColor();
        }
    }
}

- (void)updateBackgroundColor
{
    self.carrier.backgroundColor = [self deduceBackgroundColor];
}

- (void)updateForegroundColor
{
    if( !m_Item )
        return;

    const auto &rules = nc::CurrentTheme().FilePanelsItemsColoringRules();
    const bool focus = self.selected && m_PanelActive;
    for( const auto &i : rules )
        if( i.filter.Filter(m_Item, m_VD) ) {
            self.carrier.filenameColor = focus ? i.focused : i.regular;
            break;
        }
}

- (void)setPanelActive:(bool)_active
{
    if( m_PanelActive == _active )
        return;
    m_PanelActive = _active;

    [self updateForegroundColor];
    [self updateBackgroundColor];
}

- (bool)panelActive
{
    return m_PanelActive;
}

@end
