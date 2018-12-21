// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "RecentlyClosedMenuDelegate.h"
#include "../ListingPromise.h"
#include "LocationFormatter.h"
#include "../PanelController.h"
#include "../PanelHistory.h"
#include "../MainWindowFilePanelState.h"
#include "../MainWindowFilePanelState+TabsSupport.h"
#include <NimbleCommander/Core/AnyHolder.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>

using namespace nc::panel;

@implementation NCPanelsRecentlyClosedMenuDelegate
{
    NSMenu *m_Menu;
    NSMenuItem *m_RestoreLast;
    std::shared_ptr<nc::panel::ClosedPanelsHistory> m_Storage;
    std::function<MainWindowFilePanelState*()> m_Locator;
}

- (instancetype) initWithMenu:(NSMenu*)_menu
                      storage:(std::shared_ptr<nc::panel::ClosedPanelsHistory>)_storage
                panelsLocator:(std::function<MainWindowFilePanelState*()>)_locator
{
    assert( _menu );
    assert( _storage );
    assert( _locator );
    if( self = [super init] ) {
        m_Menu = _menu;
        m_Menu.delegate = self;
        
        m_Storage = move(_storage);
        m_Locator = move(_locator);
        m_RestoreLast = [_menu itemAtIndex:0];
        m_RestoreLast.target = self;
        m_RestoreLast.action = @selector(restoreLastClosed:);
    }
    return self;
}

- (BOOL)menuHasKeyEquivalent:(NSMenu*)menu
                    forEvent:(NSEvent*)event
                      target:(__nullable id* __nonnull)target
                      action:(__nullable SEL* __nonnull)action
{
    if( m_RestoreLast.keyEquivalentModifierMask == event.modifierFlags &&
        [m_RestoreLast.keyEquivalent isEqualToString:event.charactersIgnoringModifiers] ) {
        *target = m_RestoreLast.target;
        *action = m_RestoreLast.action;
    }
    return false;
}

static NSString *ShrinkTitleForRecentlyClosedMenu(NSString *_title)
{
    static const auto text_font = [NSFont menuFontOfSize:13];
    static const auto text_attributes = @{NSFontAttributeName:text_font};
    static const auto max_width = 450;
    return StringByTruncatingToWidth(_title, max_width, kTruncateAtMiddle, text_attributes);
}

- (NSMenuItem*)buildMenuItem:(const ListingPromise &)_listing_promise
{
    const auto options = (loc_fmt::Formatter::RenderOptions)
        (loc_fmt::Formatter::RenderMenuTitle | loc_fmt::Formatter::RenderMenuTooltip);
    const auto rep = loc_fmt::ListingPromiseFormatter{}.Render(options, _listing_promise);
    
    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.title = ShrinkTitleForRecentlyClosedMenu(rep.menu_title);
    item.toolTip = rep.menu_tooltip;
    return item;
}

static RestoreClosedTabRequest::Side CurrentSide(MainWindowFilePanelState *_state)
{
    if( !_state )
        return RestoreClosedTabRequest::Side::Left;
    
    if( _state.activePanelController == _state.rightPanelController )
        return RestoreClosedTabRequest::Side::Right;
    else
        return RestoreClosedTabRequest::Side::Left;
}

- (void)purgeMenu
{
    while( m_Menu.numberOfItems > 2 )
        [m_Menu removeItemAtIndex:m_Menu.numberOfItems - 1];
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    auto current_state = m_Locator();
    auto side = CurrentSide(current_state);
    
    auto records = m_Storage->FrontElements( m_Storage->Size() );
    
    [self purgeMenu];
    
    for( auto &listing_promise: records ) {
        auto item = [self buildMenuItem:listing_promise];
        if( current_state ) {
            item.target = current_state;
            item.action = @selector(respawnRecentlyClosedCallout:);
            item.representedObject = [[AnyHolder alloc] initWithAny:std::any{
                RestoreClosedTabRequest(side, listing_promise)
            }];
        }
        
        [menu addItem:item];
    }
}

- (void)menuDidClose:(NSMenu *)menu
{
    [self purgeMenu];
}

- (void)restoreLastClosed:(id)_sender
{
    auto current_state = m_Locator();
    if( !current_state ) {
        NSBeep();
        return;
    }
    
    auto records = m_Storage->FrontElements(1);
    if( records.empty() ) {
        NSBeep();
        return;
    }
    
    auto payload = [[AnyHolder alloc] initWithAny:std::any{
        RestoreClosedTabRequest(CurrentSide(current_state), records.front())
    }];
    objc_cast<NSMenuItem>(_sender).representedObject = payload;
    [current_state respawnRecentlyClosedCallout:_sender];
    objc_cast<NSMenuItem>(_sender).representedObject = nil;
}

- (BOOL) validateMenuItem:(NSMenuItem *)_item
{
    if( _item == m_RestoreLast ) {
        auto current_state = m_Locator();
        if( !current_state )
            return false;
        return m_Storage->Size() != 0;
    }
    
    return true;
}

@end
