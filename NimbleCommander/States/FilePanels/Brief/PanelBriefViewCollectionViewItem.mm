// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/Theme.h>
#include "../PanelViewPresentationItemsColoringFilter.h"
#include "../PanelView.h"
#include "PanelBriefView.h"
#include "PanelBriefViewItemCarrier.h"
#include "PanelBriefViewCollectionViewItem.h"

using namespace nc::panel;

@implementation PanelBriefViewItem
{
    VFSListingItem                  m_Item;
    data::ItemVolatileData          m_VD;
    bool                            m_PanelActive;
}

@synthesize panelActive = m_PanelActive;

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Item = VFSListingItem{};
    m_VD = data::ItemVolatileData{};
    m_PanelActive = false;
    [super setSelected:false];
    self.carrier.background = nil;
    self.carrier.qsHighlight = {0, 0};
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil
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

- (PanelBriefViewItemCarrier*) carrier
{
    return (PanelBriefViewItemCarrier*)self.view;
}

- (VFSListingItem)item
{
    return m_Item;
}

- (void) setItem:(VFSListingItem)_item
{
    m_Item = _item;
    self.carrier.filename = m_Item.DisplayNameNS();
    self.carrier.isSymlink = m_Item.IsSymlink();    
    [self updateItemLayout];
}

- (void) updateItemLayout
{
    if( auto *bv = self.briefView )
        self.carrier.layoutConstants = bv.layoutConstants;
}

- (void) setPanelActive:(bool)_active
{
    if( m_PanelActive == _active )
        return;
    
    m_PanelActive = _active;
    
    if( self.selected  ) {
        [self updateBackgroundColor];
        [self updateForegroundColor];
    }
}

- (void)setSelected:(BOOL)selected
{
    if( self.selected == selected )
        return;
    [super setSelected:selected];
    
    [self updateBackgroundColor];
    [self updateForegroundColor];
}

- (NSColor*) selectedBackgroundColor
{
    if( m_PanelActive )
        return CurrentTheme().FilePanelsBriefFocusedActiveItemBackgroundColor();
    else
        return CurrentTheme().FilePanelsBriefFocusedInactiveItemBackgroundColor();
}

- (PanelBriefView*)briefView
{
    return (PanelBriefView*)self.collectionView.delegate;
}

- (int) itemIndex
{
    if( auto c = self.collectionView )
        if( auto p = [c indexPathForItem:self] )
            return (int)p.item;
    return -1;
}

- (int) columnIndex
{
    const auto index = self.itemIndex;
    if( index < 0 )
        return -1;
    
    const auto items_per_column = self.briefView.itemsInColumn;
    if( items_per_column == 0 )
        return -1;
    
    return index / items_per_column;
}

- (void) updateForegroundColor
{
    if( !m_Item )
        return;
    
    if( self.briefView ) {
        const auto &rules = CurrentTheme().FilePanelsItemsColoringRules();
        const bool focus = self.selected && m_PanelActive;
        for( const auto &i: rules )
            if( i.filter.Filter(m_Item, m_VD) ) {
                self.carrier.filenameColor = focus ? i.focused : i.regular;
                break;
            }
    }
}

- (void) updateBackgroundColor
{
    if( self.selected ) {
        self.carrier.background = self.selectedBackgroundColor;
    }
    else {
        if( m_VD.is_selected() ) {
            self.carrier.background = CurrentTheme().FilePanelsBriefSelectedItemBackgroundColor();
        }
        else {
            self.carrier.background = nil;
        }
    }
}

- (void) setVD:(data::ItemVolatileData)_vd
{
    if( m_VD == _vd )
        return;
    m_VD = _vd;
    [self updateForegroundColor];
    [self updateBackgroundColor];
    self.carrier.qsHighlight = {_vd.qs_highlight_begin, _vd.qs_highlight_end};
    self.carrier.highlighted = _vd.is_highlighted();
}

- (void) setIcon:(NSImage*)_icon
{
    self.carrier.icon = _icon;
}

- (void) setupFieldEditor:(NSScrollView*)_editor
{
    [self.carrier setupFieldEditor:_editor];
}

@end
