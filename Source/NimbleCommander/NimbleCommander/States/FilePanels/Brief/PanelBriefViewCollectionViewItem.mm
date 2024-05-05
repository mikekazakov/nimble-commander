// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/Theme.h>
#include <Panel/UI/PanelViewPresentationItemsColoringFilter.h>
#include "../PanelView.h"
#include "PanelBriefView.h"
#include "PanelBriefViewItemCarrier.h"
#include "PanelBriefViewCollectionViewItem.h"

using namespace nc::panel;

@implementation PanelBriefViewItem {
    VFSListingItem m_Item;
    data::ItemVolatileData m_VD;
    bool m_PanelActive;
}

@synthesize panelActive = m_PanelActive;

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Item = VFSListingItem{};
    m_VD = data::ItemVolatileData{};
    m_PanelActive = false;
    [super setSelected:false];
    self.carrier.backgroundColor = nil;
    self.carrier.tagAccentColor = nil;
    self.carrier.qsHighlight = {};
}

- (instancetype)initWithNibName:(nullable NSString *) [[maybe_unused]] nibNameOrNil
                         bundle:(nullable NSBundle *) [[maybe_unused]] nibBundleOrNil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        m_PanelActive = false;
        const auto rc = NSMakeRect(0, 0, 10, 10);
        PanelBriefViewItemCarrier *v = [[PanelBriefViewItemCarrier alloc] initWithFrame:rc];
        v.controller = self;
        self.view = v;
    }
    return self;
}

- (PanelBriefViewItemCarrier *)carrier
{
    return static_cast<PanelBriefViewItemCarrier *>(self.view);
}

- (VFSListingItem)item
{
    return m_Item;
}

- (void)setItem:(VFSListingItem)_item
{
    m_Item = _item;
    self.carrier.filename = m_Item.DisplayNameNS();
    self.carrier.isSymlink = m_Item.IsSymlink();
    [self updateItemLayout];
}

- (void)updateItemLayout
{
    if( auto *bv = self.briefView )
        self.carrier.layoutConstants = bv.layoutConstants;
}

- (void)setPanelActive:(bool)_active
{
    if( m_PanelActive == _active )
        return;
    m_PanelActive = _active;

    [self updateBackgroundColor];
    [self updateForegroundColor];
    [self updateAccentColor];
}

- (void)setSelected:(BOOL)selected
{
    if( self.selected == selected )
        return;
    [super setSelected:selected];

    [self updateBackgroundColor];
    [self updateForegroundColor];
    [self updateAccentColor];
}

- (NSColor *)selectedBackgroundColor
{
    if( m_PanelActive )
        return nc::CurrentTheme().FilePanelsBriefFocusedActiveItemBackgroundColor();
    else
        return nc::CurrentTheme().FilePanelsBriefFocusedInactiveItemBackgroundColor();
}

- (PanelBriefView *)briefView
{
    return static_cast<PanelBriefView *>(self.collectionView.delegate);
}

- (int)itemIndex
{
    if( auto c = self.collectionView )
        if( auto p = [c indexPathForItem:self] )
            return static_cast<int>(p.item);
    return -1;
}

- (int)columnIndex
{
    const auto index = self.itemIndex;
    if( index < 0 )
        return -1;

    const auto items_per_column = self.briefView.itemsInColumn;
    if( items_per_column == 0 )
        return -1;

    return index / items_per_column;
}

- (void)updateForegroundColor
{
    if( !m_Item )
        return;

    if( self.briefView ) {
        const auto &rules = nc::CurrentTheme().FilePanelsItemsColoringRules();
        const bool focus = self.selected && m_PanelActive;
        for( const auto &i : rules )
            if( i.filter.Filter(m_Item, m_VD) ) {
                self.carrier.filenameColor = focus ? i.focused : i.regular;
                break;
            }
    }
}

- (void)updateBackgroundColor
{
    if( self.selected ) {
        self.carrier.backgroundColor = self.selectedBackgroundColor;
    }
    else {
        if( m_VD.is_selected() ) {
            self.carrier.backgroundColor = nc::CurrentTheme().FilePanelsBriefSelectedItemBackgroundColor();
        }
        else {
            self.carrier.backgroundColor = nil;
        }
    }
}

- (void)updateAccentColor
{
    if( !m_Item )
        return;

    if( m_PanelActive && m_Item.HasTags() && (m_VD.is_selected() || self.selected) ) {
        self.carrier.tagAccentColor = NSColor.whiteColor; // TODO: Pick from Themes
    }
    else {
        self.carrier.tagAccentColor = nil;
    }
}

- (void)setVD:(data::ItemVolatileData)_vd
{
    if( m_VD == _vd )
        return;
    m_VD = _vd;
    [self updateForegroundColor];
    [self updateBackgroundColor];
    [self updateAccentColor];
    self.carrier.qsHighlight = _vd.highlight;
    self.carrier.highlighted = _vd.is_highlighted();
}

- (void)setIcon:(NSImage *)_icon
{
    self.carrier.icon = _icon;
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor
{
    [self.carrier setupFieldEditor:_editor];
}

@end
