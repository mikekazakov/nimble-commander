#include "ToolsMenuDelegate.h"
#include "../../../Files/AppDelegate.h"
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
    shared_ptr<ExternalToolsStorage::ChangesObserver>   m_ToolsObserver;
    bool m_IsDirty;
}

- (id) init
{
    self = [super init];
    if( self ) {
        m_IsDirty = true;
    }
    return self;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu
{
    // deferred observer setup
    if( !m_ToolsObserver )
        m_ToolsObserver = AppDelegate.me.externalTools.ObserveChanges([=]{
            m_IsDirty = true;
        });
    
    if( m_IsDirty )
        m_Tools = AppDelegate.me.externalTools.GetAllTools();
    
    return m_Tools.size();
}

- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    if( !m_IsDirty || index >= m_Tools.size() )
        return false;
    
    auto et = m_Tools[index];
    item.title = [NSString stringWithUTF8StdString:et->m_Title];
    item.representedObject = [[ToolsMenuDelegateInfoWrapper alloc] initWithTool:et];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
    item.action = @selector(onExternMenuActionCalled:);
#pragma clang diagnostic pop    
    item.keyEquivalent = et->m_Shorcut.Key();
    item.keyEquivalentModifierMask = et->m_Shorcut.modifiers;
    
    if( index == m_Tools.size() - 1 )
        m_IsDirty = false;
    
    return true;
}

@end
