#include "ConnectionsMenuDelegate.h"
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "NetworkConnectionsManager.h"

#include <NimbleCommander/Core/ConfigBackedNetworkConnectionsManager.h>
static NetworkConnectionsManager &ConnectionsManager()
{
    return ConfigBackedNetworkConnectionsManager::Instance();
}

@interface ConnectionsMenuDelegate()

@property (strong) IBOutlet NSMenuItem *recentConnectionsMenuItem;

@end

@implementation ConnectionsMenuDelegate
{
    vector<NetworkConnectionsManager::Connection> m_Connections;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    if( (menu.propertiesToUpdate & NSMenuPropertyItemTitle) == 0 )
        return; // we should update this menu only when it's shown, not by a key press
  
    // there's no "dirty" state for MRU, so need to fetch data on every access current state
    // and compare it with previously used. this is ugly, but it's much better than rebuilding whole
    // menu every time. Better approach would be making NetworkConnectionsManager observable.
    auto &ncm = ConnectionsManager();
    auto connections = ncm.AllConnectionsByMRU();
    if( m_Connections != connections ) {
        m_Connections = move(connections);
    
        while( menu.numberOfItems > 6 ) // <- BAD MAGIC NUMBER!
            [menu removeItemAtIndex:menu.numberOfItems-1];
        
        self.recentConnectionsMenuItem.hidden = m_Connections.empty();
        
        for( auto &c: m_Connections ) {
            NSMenuItem *regular_item = [[NSMenuItem alloc] init];
            regular_item.indentationLevel = 1;
            regular_item.title = [NSString stringWithUTF8StdString:ncm.TitleForConnection(c)];
            regular_item.representedObject = [[AnyHolder alloc] initWithAny:any{c}];
            regular_item.action = @selector(OnGoToSavedConnectionItem:);
            [menu addItem:regular_item];
        }
    }
}

@end
