#import "../../../Files/3rd_party/MMTabBarView/MMTabBarView/MMAttachedTabBarButton.h"
#include <Habanero/CommonPaths.h>
#include "MainWindowFilePanelsStateToolbarDelegate.h"
#include <VFS/Native.h>
#include "MainWindowFilePanelState+TabsSupport.h"
#include "PanelView.h"
#include "PanelController.h"
#include "../../../Files/FilePanelMainSplitView.h"

template <class _Cont, class _Tp>
inline void erase_from(_Cont &__cont_, const _Tp& __value_)
{
    __cont_.erase(remove(begin(__cont_),
                         end(__cont_),
                         __value_),
                  end(__cont_)
                  );
}

@implementation MainWindowFilePanelState (TabsSupport)

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    return true;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    // just set current PanelView to first responder
    assert( [tabViewItem.view isKindOfClass:PanelView.class] );
    [self.window makeFirstResponder:tabViewItem.view];
  
    PanelController *pc = (PanelController *)((PanelView*)tabViewItem.view).delegate;
    if(tabView == m_MainSplitView.leftTabbedHolder.tabView)
        [pc AttachToControls:m_ToolbarDelegate.leftPanelSpinningIndicator
                       share:m_ToolbarDelegate.leftPanelShareButton];
    if(tabView == m_MainSplitView.rightTabbedHolder.tabView)
        [pc AttachToControls:m_ToolbarDelegate.rightPanelSpinningIndicator
                       share:m_ToolbarDelegate.rightPanelShareButton];
    
    m_MainSplitView.leftOverlay = nil;
    m_MainSplitView.rightOverlay = nil;
}

- (void) updateTabNameForController:(PanelController*)_controller
{
    path p = _controller.currentDirectoryPath;
    string name = p == "/" ? p.native() : p.parent_path().filename().native();
    if( name == "/" && _controller.isUniform && _controller.vfs->Parent() )
        name = path(_controller.vfs->JunctionPath()).filename().native(); // source file name for vfs like archives and xattr
    
    NSArray *tabs;
    if([self isLeftController:_controller])
        tabs = m_MainSplitView.leftTabbedHolder.tabView.tabViewItems;
    else if([self isRightController:_controller])
        tabs = m_MainSplitView.rightTabbedHolder.tabView.tabViewItems;
    
    if(tabs)
        for(NSTabViewItem *it in tabs)
            if(it.view == _controller.view)
                it.label = [NSString stringWithUTF8String:name.c_str()];
}

- (void)addNewTabToTabView:(NSTabView *)aTabView
{
    [self spawnNewTabInTabView:aTabView autoDirectoryLoading:true activateNewPanel:true];
}

- (PanelController*)spawnNewTabInTabView:(NSTabView *)aTabView autoDirectoryLoading:(bool)_load activateNewPanel:(bool)_activate
{
    PanelController *pc = [PanelController new];
    pc.state = self;
    PanelController *source = nil;
    if( aTabView == m_MainSplitView.leftTabbedHolder.tabView ) {
        source = self.leftPanelController;
        m_LeftPanelControllers.emplace_back(pc);
        [m_MainSplitView.leftTabbedHolder addPanel:pc.view];
    }
    else if( aTabView == m_MainSplitView.rightTabbedHolder.tabView ) {
        source = self.rightPanelController;
        m_RightPanelControllers.emplace_back(pc);
        [m_MainSplitView.rightTabbedHolder addPanel:pc.view];
    }
    else
        assert(0); // something is really broken
    
    [pc copyOptionsFromController:source];
    if( _load ) {
        if( source.isUniform ) {
            [pc GoToDir:source.currentDirectoryPath vfs:source.vfs select_entry:"" async:false];
        }
        else if( !source.history.Empty() ) {
            auto h = source.history.All();
            [pc GoToVFSPromise:h.back().get().vfs onPath:h.back().get().path];
        }
        else
            [pc GoToDir:CommonPaths::Home() vfs:VFSNativeHost::SharedHost() select_entry:"" async:false];
    }
    
    if( _activate )
        [self ActivatePanelByController:pc];
    
    return pc;
}

/*- (BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem
{
    return false;
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    return true;
}

- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
}*/

- (void)tabView:(NSTabView *)aTabView didMoveTabViewItem:(NSTabViewItem *)tabViewItem toIndex:(NSUInteger)index
{
    PanelController *pc =  (PanelController*)(((PanelView*)tabViewItem.view).delegate);
    if( [self isLeftController:pc] ) {
        auto it = find(begin(m_LeftPanelControllers), end(m_LeftPanelControllers), pc);
        if(it == end(m_LeftPanelControllers))
            return;
        
        m_LeftPanelControllers.erase(it);
        m_LeftPanelControllers.insert(begin(m_LeftPanelControllers)+index, pc);
        
    }
    else if( [self isRightController:pc] ) {
        auto it = find(begin(m_RightPanelControllers), end(m_RightPanelControllers), pc);
        if(it == end(m_RightPanelControllers))
            return;
        
        m_RightPanelControllers.erase(it);
        m_RightPanelControllers.insert(begin(m_RightPanelControllers)+index, pc);
    }
}

- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView
{
    return aTabView.numberOfTabViewItems > 1;
}

- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView
{
    return @[PanelController.dragAndDropPrivateUTI];
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
    [self updateTabBarsVisibility];
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    // NB! at this moment a tab was already removed from NSTabView objects
    assert( [tabViewItem.view isKindOfClass:PanelView.class] );
    assert( [((PanelView*)tabViewItem.view).delegate isKindOfClass:PanelController.class] );
    PanelController *pc = (PanelController*)((PanelView*)tabViewItem.view).delegate;
    
    erase_from(m_LeftPanelControllers, pc);
    erase_from(m_RightPanelControllers, pc);
}

- (void) closeCurrentTab
{
    PanelController *cur = self.activePanelController;
    if(!cur)
        return;

    NSTabViewItem *it;
    MMTabBarView *bar;
    
    if( cur.view == m_MainSplitView.leftTabbedHolder.current ) {
        it = [m_MainSplitView.leftTabbedHolder tabViewItemForController:cur];
        bar = m_MainSplitView.leftTabbedHolder.tabBar;
    }
    else if( cur.view == m_MainSplitView.rightTabbedHolder.current ) {
        it = [m_MainSplitView.rightTabbedHolder tabViewItemForController:cur];
        bar = m_MainSplitView.rightTabbedHolder.tabBar;
    }
    
    if(it && bar)
        if(MMAttachedTabBarButton *bb = [bar attachedButtonForTabViewItem:it])
            [bar performSelector:bb.closeButtonAction withObject:bb.closeButton afterDelay:0.0];
}

- (unsigned) currentSideTabsCount
{
    if( !self.isPanelActive )
        return 0;
    
    PanelController *cur = self.activePanelController;
    int tabs = 1;
    if( [self isLeftController:cur] )
        tabs = m_MainSplitView.leftTabbedHolder.tabsCount;
    else if( [self isRightController:cur] )
        tabs = m_MainSplitView.rightTabbedHolder.tabsCount;
    return tabs;
}

- (MMTabBarView*) activeTabBarView
{
    PanelController *cur = self.activePanelController;
    if(!cur)
        return nil;
    
    if([self isLeftController:cur])
        return m_MainSplitView.leftTabbedHolder.tabBar;
    else if([self isRightController:cur])
        return m_MainSplitView.rightTabbedHolder.tabBar;
    
    return nil;
}

- (FilePanelsTabbedHolder*) activeFilePanelsTabbedHolder
{
    PanelController *cur = self.activePanelController;
    if(!cur)
        return nil;
    
    if([self isLeftController:cur])
        return m_MainSplitView.leftTabbedHolder;
    else if([self isRightController:cur])
        return m_MainSplitView.rightTabbedHolder;
    
    return nil;
}

- (void) selectPreviousFilePanelTab
{
    FilePanelsTabbedHolder *th = self.activeFilePanelsTabbedHolder;
    if(!th)
        return;
    
    [th selectPreviousFilePanelTab];
}

- (void) selectNextFilePanelTab
{
    FilePanelsTabbedHolder *th = self.activeFilePanelsTabbedHolder;
    if(!th)
        return;

    [th selectNextFilePanelTab];
}

- (void) updateTabBarsVisibility
{
    unsigned lc = m_MainSplitView.leftTabbedHolder.tabsCount, rc = m_MainSplitView.rightTabbedHolder.tabsCount;
    bool should_be_shown = m_ShowTabs ? true : (lc > 1 || rc > 1);
    m_MainSplitView.leftTabbedHolder.tabBarShown = should_be_shown;
    m_MainSplitView.rightTabbedHolder.tabBarShown = should_be_shown;
}

- (void) updateTabBarButtons
{
    [m_MainSplitView.leftTabbedHolder.tabBar  enumerateAttachedButtonsUsingBlock:^(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop) {
            [aButton setNeedsDisplay];
        }];
    [m_MainSplitView.rightTabbedHolder.tabBar  enumerateAttachedButtonsUsingBlock:^(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop) {
            [aButton setNeedsDisplay];
            }];
}

@end

