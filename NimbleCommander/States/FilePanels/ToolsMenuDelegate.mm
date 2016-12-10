#include "ToolsMenuDelegate.h"
#include "../../Bootstrap/AppDelegate.h"
#include "../../../Files/MainWindowFilePanelState+Menu.h"

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


@implementation ToolsMenuDelegate
{
    vector<shared_ptr<const ExternalTool>>              m_Tools;
    ExternalToolsStorage::ObservationTicket             m_ToolsObserver;
    __weak NSMenu                                      *m_MyMenu;
}

- (id) init
{
    self = [super init];
    if( self ) {
    }
    return self;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu
{
    // deferred observer setup
    if( !m_ToolsObserver )
        m_ToolsObserver = AppDelegate.me.externalTools.ObserveChanges([=]{
            [self menuNeedsUpdate:m_MyMenu];
        });
    if( m_MyMenu == nil )
        m_MyMenu = menu;
    
    m_Tools = AppDelegate.me.externalTools.GetAllTools();
    
    return m_Tools.size();
}

- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    assert( index < m_Tools.size() );
    auto et = m_Tools[index];
    item.title = et->m_Title.empty() ?
        [NSString stringWithFormat:@"Tool #%ld", index] :
        [NSString stringWithUTF8StdString:et->m_Title];
    item.representedObject = [[ToolsMenuDelegateInfoWrapper alloc] initWithTool:et];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
    if( !et->m_ExecutablePath.empty() )
        item.action = @selector(onExternMenuActionCalled:);
    else
        item.action = nil;
#pragma clang diagnostic pop
    item.keyEquivalent = et->m_Shorcut.Key();
    item.keyEquivalentModifierMask = et->m_Shorcut.modifiers;
    
    return true;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    if( !m_MyMenu ) m_MyMenu = menu;
    if( !menu )     menu = m_MyMenu;
    if( !menu )     return;
    
    NSInteger count = [self numberOfItemsInMenu:menu];
    while( menu.numberOfItems < count )
        [menu insertItem:[NSMenuItem new] atIndex:0];
    while( menu.numberOfItems > count )
        [menu removeItemAtIndex:0];
    for( NSInteger index = 0; index < count; index++ )
        [self menu:menu updateItem:[menu itemAtIndex:index] atIndex:index shouldCancel:NO];
}

@end
