#include "ToolsMenuDelegate.h"
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "MainWindowFilePanelState+Menu.h"

@implementation ToolsMenuDelegateInfoWrapper
{
    shared_ptr<const ExternalTool> m_ET;
}

@synthesize object = m_ET;

- (id) initWithTool:(shared_ptr<const ExternalTool>)_et
{
    self = [super init];
    if(self)
        m_ET = _et;

    return self;
}

@end

static NSMenuItem *ItemForTool( const shared_ptr<const ExternalTool> &_tool, int _ind )
{
    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.title = _tool->m_Title.empty() ?
        [NSString stringWithFormat:@"Tool #%i", _ind] :
        [NSString stringWithUTF8StdString:_tool->m_Title];
    item.representedObject = [[ToolsMenuDelegateInfoWrapper alloc] initWithTool:_tool];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
    if( !_tool->m_ExecutablePath.empty() )
        item.action = @selector(onExternMenuActionCalled:);
    else
        item.action = nil;
#pragma clang diagnostic pop
    item.keyEquivalent = _tool->m_Shorcut.Key();
    item.keyEquivalentModifierMask = _tool->m_Shorcut.modifiers;
    return item;
}

@implementation ToolsMenuDelegate
{
    bool m_IsDirty;
    ExternalToolsStorage::ObservationTicket m_ToolsObserver;
    __weak NSMenu                          *m_MyMenu;
}

- (id) init
{
    self = [super init];
    if( self ) {
        m_IsDirty = true;
    }
    return self;
}

- (void) toolsHaveChanged
{
    m_IsDirty = true;
    [self menuNeedsUpdate:m_MyMenu];
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    // this delegate need to trigger update of the menu later, so will store the pointer
    if( !m_MyMenu )
        m_MyMenu = menu;
    
    // deferred observer setup
    if( !m_ToolsObserver )
        m_ToolsObserver = AppDelegate.me.externalTools.ObserveChanges(
            objc_callback(self, @selector(toolsHaveChanged)) );
    
    if( m_IsDirty ) {
        const auto tools = AppDelegate.me.externalTools.GetAllTools();
        
        [menu removeAllItems];
        for( int i = 0, e = (int)tools.size(); i != e; ++i )
            [menu addItem:ItemForTool(tools[i], i)];
    
        m_IsDirty = false;
    }
}

@end
