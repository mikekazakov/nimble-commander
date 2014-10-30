#import "MainWindowFilePanelState+TabsSupport.h"
#import "PanelView.h"
#import "PanelController.h"
#import "FilePanelMainSplitView.h"

// duplicate!
static auto g_DefsPanelsLeftOptions  = @"FilePanelsLeftPanelViewState";
static auto g_DefsPanelsRightOptions = @"FilePanelsRightPanelViewState";

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

@end

