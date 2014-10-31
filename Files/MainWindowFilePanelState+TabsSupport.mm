#import "3rd_party/MMTabBarView/MMTabBarView/MMAttachedTabBarButton.h"
#import "MainWindowFilePanelState+TabsSupport.h"
#import "PanelView.h"
#import "PanelController.h"
#import "FilePanelMainSplitView.h"

// duplicate!
static auto g_DefsPanelsLeftOptions  = @"FilePanelsLeftPanelViewState";
static auto g_DefsPanelsRightOptions = @"FilePanelsRightPanelViewState";

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
        [pc AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    if(tabView == m_MainSplitView.rightTabbedHolder.tabView)
        [pc AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
}

- (void) updateTabNameForController:(PanelController*)_controller
{
    path p = [_controller GetCurrentDirectoryPathRelativeToHost];
    string name = p == "/" ? p.native() : p.parent_path().filename().native();
    
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
    PanelController *pc = [PanelController new];
    pc.state = self;
    
    if(aTabView == m_MainSplitView.leftTabbedHolder.tabView) {
        pc.options = [NSUserDefaults.standardUserDefaults dictionaryForKey:g_DefsPanelsLeftOptions];
        m_LeftPanelControllers.emplace_back(pc);
        [m_MainSplitView.leftTabbedHolder addPanel:pc.view];
    }
    else if(aTabView == m_MainSplitView.rightTabbedHolder.tabView) {
        pc.options = [NSUserDefaults.standardUserDefaults dictionaryForKey:g_DefsPanelsRightOptions];
        m_RightPanelControllers.emplace_back(pc);
        [m_MainSplitView.rightTabbedHolder addPanel:pc.view];
    }
    else
        assert(0); // something is really broken
    
    [pc GoToDir:"/"
            vfs:VFSNativeHost::SharedHost()
   select_entry:""
          async:false];
    
    [self ActivatePanelByController:pc];
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

@end

