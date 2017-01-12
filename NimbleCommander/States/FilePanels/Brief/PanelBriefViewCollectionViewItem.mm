#include <NimbleCommander/Core/Theming/Theme.h>
#include "../PanelViewPresentationItemsColoringFilter.h"
#include "../PanelView.h"
#include "PanelBriefView.h"
#include "PanelBriefViewItemCarrier.h"
#include "PanelBriefViewCollectionViewItem.h"

@implementation PanelBriefViewItem
{
    VFSListingItem                  m_Item;
    PanelDataItemVolatileData       m_VD;
    bool                            m_PanelActive;
}

@synthesize panelActive = m_PanelActive;

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Item = VFSListingItem{};
    m_VD = PanelData::VolatileData{};
    m_PanelActive = false;
}

- (nullable instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        m_PanelActive = false;
        PanelBriefViewItemCarrier *v = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
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
    self.carrier.filename = m_Item.NSDisplayName();
    self.carrier.layoutConstants = self.briefView.layoutConstants;
    [self.carrier setNeedsDisplay:true];
}


- (void) setPanelActive:(bool)_active
{
    if( m_PanelActive != _active ) {
        m_PanelActive = _active;
        
        if( self.selected  ) {
            self.carrier.background = self.selectedBackgroundColor;
            if( m_Item )
                [self updateColoring];
        }
    }
}

- (void)setSelected:(BOOL)selected
{
    if( self.selected == selected )
        return;
    [super setSelected:selected];
    
    self.carrier.background = selected ? self.selectedBackgroundColor : nil;
    if( m_Item )
        [self updateColoring];
}

- (NSColor*) selectedBackgroundColor
{
    if( m_PanelActive )
        return CurrentTheme().FilePanelsBriefSelectedActiveItemBackgroundColor();
    else
        return CurrentTheme().FilePanelsBriefSelectedInactiveItemBackgroundColor();
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

- (void) updateColoring
{
    assert( m_Item );
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

- (void) setVD:(PanelDataItemVolatileData)_vd
{
    if( m_VD == _vd )
        return;
    m_VD = _vd;
    [self updateColoring];
    self.carrier.qsHighlight = {_vd.qs_highlight_begin, _vd.qs_highlight_end};
    self.carrier.highlighted = _vd.is_highlighted();
}

- (void) setIcon:(NSImageRep*)_icon
{
    self.carrier.icon = _icon;
}

- (void) setupFieldEditor:(NSScrollView*)_editor
{
    [self.carrier setupFieldEditor:_editor];
}

@end
