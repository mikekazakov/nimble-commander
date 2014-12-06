//
//  MainWindowFilePanelState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState.h"
#import "PanelController.h"
#import "PanelController+DataAccess.h"
#import "Common.h"
#import "ApplicationSkins.h"
#import "AppDelegate.h"
#import "ClassicPanelViewPresentation.h"
#import "ModernPanelViewPresentation.h"
#import "MainWndGoToButton.h"
#import "OperationsController.h"
#import "OperationsSummaryViewController.h"
#import "MessageBox.h"
#import "QuickPreview.h"
#import "MainWindowController.h"
#import "VFS.h"
#import "FilePanelMainSplitView.h"
#import "BriefSystemOverview.h"
#import "sysinfo.h"
#import "LSUrls.h"
#import "ActionsShortcutsManager.h"
#import "common_paths.h"
#import "SandboxManager.h"
#import "FileCopyOperation.h"

static auto g_DefsPanelsLeftOptions  = @"FilePanelsLeftPanelViewState";
static auto g_DefsPanelsRightOptions = @"FilePanelsRightPanelViewState";
static auto g_DefsGeneralShowTabs = @"GeneralShowTabs";

@implementation MainWindowFilePanelState

@synthesize OperationsController = m_OperationsController;

- (id) initWithFrame:(NSRect)frameRect Window:(NSWindow*)_wnd;
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        m_ShowTabs = [defaults boolForKey:g_DefsGeneralShowTabs];
        
        m_OperationsController = [[OperationsController alloc] init];
        m_OpSummaryController = [[OperationsSummaryViewController alloc] initWithController:m_OperationsController
                                                                                     window:_wnd];
        
        m_LeftPanelControllers.emplace_back([PanelController new]);
        m_RightPanelControllers.emplace_back([PanelController new]);
  
        auto left_controller = m_LeftPanelControllers.front();
        auto right_controller = m_RightPanelControllers.front();
        
        [self CreateControls];
        
        // panel creation and preparation
        left_controller.state = self;
        [left_controller AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
        right_controller.state = self;
        [right_controller AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];

        
        left_controller.options = [NSUserDefaults.standardUserDefaults dictionaryForKey:g_DefsPanelsLeftOptions];
        right_controller.options = [NSUserDefaults.standardUserDefaults dictionaryForKey:g_DefsPanelsRightOptions];

        
        // now load data into panels, on any fails - go into home dir
        NSString *lp = [defaults stringForKey:@"FirstPanelPath"];
        NSString *rp = [defaults stringForKey:@"SecondPanelPath"];
        
        if(!configuration::is_sandboxed) { // regular waypath
            if(!lp || !lp.length || [left_controller GoToDir:lp.fileSystemRepresentation
                                                               vfs:VFSNativeHost::SharedHost()
                                                      select_entry:""
                                                             async:false] < 0)
                [left_controller GoToDir:CommonPaths::Get(CommonPaths::Home)
                                           vfs:VFSNativeHost::SharedHost()
                                  select_entry:""
                                         async:false];
        
            if(!rp || !rp.length || [right_controller GoToDir:rp.fileSystemRepresentation
                                                                vfs:VFSNativeHost::SharedHost()
                                                       select_entry:""
                                                              async:false] < 0)
                [right_controller GoToDir:"/"
                                            vfs:VFSNativeHost::SharedHost()
                                   select_entry:""
                                          async:false];
        }
        else { // on sandboxed version it's bit more complicated
            if(!lp ||
               !lp.length ||
               !SandboxManager::Instance().CanAccessFolder(lp.fileSystemRepresentation) ||
               [left_controller GoToDir:lp.fileSystemRepresentation
                                          vfs:VFSNativeHost::SharedHost()
                                 select_entry:""
                                        async:false] < 0) {
                   // failed to load saved panel path (or there was no saved path)
                   // try to go to some path we can
                   if(SandboxManager::Instance().Empty() ||
                      [left_controller GoToDir:SandboxManager::Instance().FirstFolderWithAccess()
                                                 vfs:VFSNativeHost::SharedHost()
                                        select_entry:""
                                               async:false] < 0) {
                          // failed to go to folder with granted access(or no such folders)
                          // as last resort - go to startup cwd
                          [left_controller GoToDir:((AppDelegate*)NSApplication.sharedApplication.delegate).startupCWD
                                                     vfs:VFSNativeHost::SharedHost()
                                            select_entry:""
                                                   async:false];
                    }
            }
            
            if(!rp ||
               !rp.length ||
               !SandboxManager::Instance().CanAccessFolder(rp.fileSystemRepresentation) ||
               [right_controller GoToDir:rp.fileSystemRepresentation
                                           vfs:VFSNativeHost::SharedHost()
                                  select_entry:""
                                         async:false] < 0) {
                   // failed to load saved panel path (or there was no saved path)
                   // try to go to some path we can
                   if(SandboxManager::Instance().Empty() ||
                      [right_controller GoToDir:SandboxManager::Instance().FirstFolderWithAccess()
                                                  vfs:VFSNativeHost::SharedHost()
                                         select_entry:""
                                                async:false] < 0) {
                          // failed to go to folder with granted access(or no such folders)
                          // as last resort - go to startup cwd
                          [right_controller GoToDir:((AppDelegate*)NSApplication.sharedApplication.delegate).startupCWD
                                                      vfs:VFSNativeHost::SharedHost()
                                             select_entry:""
                                                    async:false];
                      }
               }
        }
        
        [self updateTabBarsVisibility];
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:g_DefsGeneralShowTabs options:0 context:NULL];
    }
    return self;
}

- (void) dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:g_DefsGeneralShowTabs];
}

- (BOOL)acceptsFirstResponder { return true; }
- (NSToolbar*)toolbar { return m_Toolbar; }
- (NSView*) windowContentView { return self; }

- (void) CreateControls
{
    m_MainSplitView = [[FilePanelMainSplitView alloc] initWithFrame:NSRect()];
    m_MainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [m_MainSplitView.leftTabbedHolder addPanel:m_LeftPanelControllers.front().view];
    [m_MainSplitView.rightTabbedHolder addPanel:m_RightPanelControllers.front().view];
    m_MainSplitView.leftTabbedHolder.tabBar.delegate = self;
    m_MainSplitView.rightTabbedHolder.tabBar.delegate = self;
    [self addSubview:m_MainSplitView];
    
    m_LeftPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 23)];
    m_LeftPanelGoToButton.target = self;
    m_LeftPanelGoToButton.action = @selector(LeftPanelGoToButtonAction:);
    [m_LeftPanelGoToButton SetOwner:self];
    
    m_RightPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 23)];
    m_RightPanelGoToButton.target = self;
    m_RightPanelGoToButton.action = @selector(RightPanelGoToButtonAction:);
    [m_RightPanelGoToButton SetOwner:self];
    
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
    {
        m_LeftPanelShareButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 23)];
        m_LeftPanelShareButton.bezelStyle = NSTexturedRoundedBezelStyle;
        m_LeftPanelShareButton.image = [NSImage imageNamed:NSImageNameShareTemplate];
        [m_LeftPanelShareButton sendActionOn:NSLeftMouseDownMask];
        m_LeftPanelShareButton.refusesFirstResponder = true;
    
        m_RightPanelShareButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 23)];
        m_RightPanelShareButton.bezelStyle = NSTexturedRoundedBezelStyle;
        m_RightPanelShareButton.image = [NSImage imageNamed:NSImageNameShareTemplate];
        [m_RightPanelShareButton sendActionOn:NSLeftMouseDownMask];
        m_RightPanelShareButton.refusesFirstResponder = true;
    }
    
    m_LeftPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    m_LeftPanelSpinningIndicator.indeterminate = YES;
    m_LeftPanelSpinningIndicator.style = NSProgressIndicatorSpinningStyle;
    m_LeftPanelSpinningIndicator.controlSize = NSSmallControlSize;
    m_LeftPanelSpinningIndicator.displayedWhenStopped = NO;
    
    m_RightPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    m_RightPanelSpinningIndicator.indeterminate = YES;
    m_RightPanelSpinningIndicator.style = NSProgressIndicatorSpinningStyle;
    m_RightPanelSpinningIndicator.controlSize = NSSmallControlSize;
    m_RightPanelSpinningIndicator.displayedWhenStopped = NO;
    
    m_SeparatorLine = [[NSBox alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    m_SeparatorLine.boxType = NSBoxSeparator;
    [self addSubview:m_SeparatorLine];
    
    NSString *toolbar_id = [NSString stringWithFormat:@"filepanels_toolbar_%llu", (uint64_t)((__bridge void*)self)];
    m_Toolbar = [[NSToolbar alloc] initWithIdentifier:toolbar_id];
    m_Toolbar.delegate = self;
    m_Toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    m_Toolbar.showsBaselineSeparator = false;
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_MainSplitView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_SeparatorLine(<=1)]-(==0)-[m_MainSplitView]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_MainSplitView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SeparatorLine]-(==0)-|" options:0 metrics:nil views:views]];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    auto f = [](NSString *_id, NSView *_v) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:_id];
        item.view = _v;
        return item;
    };
#define item(a, b) if([itemIdentifier isEqualToString:a]) return f(a, b)
    item(@"filepanels_left_goto_button",        m_LeftPanelGoToButton);
    item(@"filepanels_right_goto_button",       m_RightPanelGoToButton);
    item(@"filepanels_left_share_button",       m_LeftPanelShareButton);
    item(@"filepanels_right_share_button",      m_RightPanelShareButton);
    item(@"filepanels_left_spinning_indicator", m_LeftPanelSpinningIndicator);
    item(@"filepanels_right_spinning_indicator",m_RightPanelSpinningIndicator);
    item(@"filepanels_operations_box",          m_OpSummaryController.view);
#undef item
    return nil;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    static NSArray *allowed_items =
        sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8 ?
               @[ @"filepanels_left_goto_button",
                  @"filepanels_left_share_button",
                  @"filepanels_left_spinning_indicator",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_operations_box",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_right_spinning_indicator",
                  @"filepanels_right_share_button",
                  @"filepanels_right_goto_button"] :
               @[ @"filepanels_left_goto_button",
                  @"filepanels_left_spinning_indicator",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_operations_box",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_right_spinning_indicator",
                  @"filepanels_right_goto_button"];
    return allowed_items;
}

- (void) Assigned
{
    [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType, (__bridge NSString *)kUTTypeFileURL] returnTypes:@[]];
    
    // if we alredy were active and have some focused view - restore it
    if(m_LastResponder)
        [self.window makeFirstResponder:m_LastResponder];
    m_LastResponder = nil;
    
    // if we don't know which view should be active - make left panel a first responder
    if(!self.isPanelActive)
        [self.window makeFirstResponder:m_MainSplitView.leftTabbedHolder.current];
    
    [self UpdateTitle];
}

- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{
    if(([sendType isEqualToString:NSFilenamesPboardType] ||
        [sendType isEqualToString:(__bridge NSString *)kUTTypeFileURL]) &&
       self.isPanelActive &&
       self.activePanelData->Host()->IsNativeFS() )
        return self;
    
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
    if([types containsObject:NSFilenamesPboardType])
        return [self WriteFilesnamesPBoard:pboard];
        
    if([types containsObject:(__bridge NSString *)kUTTypeFileURL])
        return [self WriteURLSPBoard:pboard];
    
    return NO;
}

- (bool)WriteFilesnamesPBoard:(NSPasteboard *)pboard
{
    if(!self.isPanelActive ||
       !self.activePanelData->Host()->IsNativeFS())
        return false;
    
    NSMutableArray *filenames = [NSMutableArray new];
    
    PanelData *pd = self.activePanelData;
    string dir_path = pd->DirectoryPathWithTrailingSlash();
    if(pd->Stats().selected_entries_amount > 0) {
        for(auto &i: pd->StringsFromSelectedEntries())
            [filenames addObject:[NSString stringWithUTF8String:(dir_path + i.c_str()).c_str()]];
    }
    else {
        auto const *item = self.activePanelView.item;
        if(item && !item->IsDotDot())
            [filenames addObject:[NSString stringWithUTF8String:(dir_path + item->Name()).c_str()]];
    }
    
    if(filenames.count == 0)
        return false;
    
    [pboard clearContents];
    [pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    return [pboard setPropertyList:filenames forType:NSFilenamesPboardType] == TRUE;
}

- (bool)WriteURLSPBoard:(NSPasteboard *)pboard
{
    if(!self.isPanelActive ||
       !self.activePanelData->Host()->IsNativeFS())
        return false;
    
    NSMutableArray *fileurls = [NSMutableArray new];
    
    PanelData *pd = self.activePanelData;
    string dir_path = pd->DirectoryPathWithTrailingSlash();
    if(pd->Stats().selected_entries_amount > 0) {
        for(auto &i: pd->StringsFromSelectedEntries())
            [fileurls addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8String:(dir_path + i.c_str()).c_str()]]];
    }
    else {
        auto const *item = self.activePanelView.item;
        if(item && !item->IsDotDot())
            [fileurls addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8String:(dir_path + item->Name()).c_str()]]];
    }
    
    if(fileurls.count == 0)
        return false;
    
    [pboard clearContents]; // clear pasteboard to take ownership
    return [pboard writeObjects:fileurls]; // write the URLs
}

- (void) Resigned
{
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if(_wnd == nil)
    {
        m_LastResponder = nil;
        NSResponder *resp = self.window.firstResponder;
        if(resp != nil &&
           [resp isKindOfClass:NSView.class] &&
           [(NSView*)resp isDescendantOf:self] )
            m_LastResponder = resp;
    }
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender
{
    if(![PanelController ensureCanGoToNativeFolderSync:m_LeftPanelGoToButton.path])
        return;
    m_MainSplitView.leftOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    [self.leftPanelController GoToDir:m_LeftPanelGoToButton.path
                                  vfs:VFSNativeHost::SharedHost()
                         select_entry:""
                                async:true];
}

- (IBAction)RightPanelGoToButtonAction:(id)sender
{
    if(![PanelController ensureCanGoToNativeFolderSync:m_RightPanelGoToButton.path])
        return;
    m_MainSplitView.rightOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    [self.rightPanelController GoToDir:m_RightPanelGoToButton.path
                                   vfs:VFSNativeHost::SharedHost()
                          select_entry:""
                                 async:true];
}

- (IBAction)LeftPanelGoto:(id)sender{
    NSPoint p = NSMakePoint(0, self.frame.size.height);
    p = [self convertPoint:p toView:nil];
    p = [self.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
    [m_LeftPanelGoToButton SetAnchorPoint:p IsRight:false];
    [m_LeftPanelGoToButton performClick:self];
}

- (IBAction)RightPanelGoto:(id)sender{
    NSPoint p = NSMakePoint(self.frame.size.width, self.frame.size.height);
    p = [self convertPoint:p toView:nil];
    p = [self.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
    [m_RightPanelGoToButton SetAnchorPoint:p IsRight:true];
    [m_RightPanelGoToButton performClick:self];
}

- (bool) isPanelActive
{
    return self.activePanelController != nil;
}

- (PanelView*) activePanelView
{
    PanelController *pc = self.activePanelController;
    return pc ? pc.view : nil;
}

- (PanelData*) activePanelData
{
    PanelController *pc = self.activePanelController;
    return pc ? &pc.data : nullptr;
}

- (PanelController*) activePanelController
{
    if(!self.window)
        return nil;
    NSResponder *r = self.window.firstResponder;
    for(auto pc: m_LeftPanelControllers)  if(r == pc.view) return pc;
    for(auto pc: m_RightPanelControllers) if(r == pc.view) return pc;
    return nil;
}

- (PanelController*) oppositePanelController
{
    PanelController* act = self.activePanelController;
    if(!act)
        return nil;
    if(act == self.leftPanelController)
        return self.rightPanelController;
    return self.leftPanelController;
}

- (PanelData*) oppositePanelData
{
    PanelController* pc = self.oppositePanelController;
    return pc ? &pc.data : nullptr;
}

- (PanelView*) oppositePanelView
{
    PanelController* pc = self.oppositePanelController;
    return pc ? pc.view : nil;
}

- (PanelController*) leftPanelController
{
    PanelView *pv = m_MainSplitView.leftTabbedHolder.current;
    if(!pv) return nil;
    assert( [pv.delegate isKindOfClass:PanelController.class] );
    return (PanelController*)pv.delegate;
}

- (PanelController*) rightPanelController
{
    PanelView *pv = m_MainSplitView.rightTabbedHolder.current;
    if(!pv) return nil;
    assert( [pv.delegate isKindOfClass:PanelController.class] );
    return (PanelController*)pv.delegate;
}

- (bool) isLeftController:(PanelController*)_controller
{
    return any_of(begin(m_LeftPanelControllers), end(m_LeftPanelControllers), [&](auto p){ return p == _controller; });
}

- (bool) isRightController:(PanelController*)_controller
{
    return any_of(begin(m_RightPanelControllers), end(m_RightPanelControllers), [&](auto p){ return p == _controller; });
}

- (void) HandleTabButton
{
    if([m_MainSplitView anyCollapsedOrOverlayed])
        return;
    PanelController *cur = self.activePanelController;
    if(!cur)
        return;
    if([self isLeftController:cur])
        [self.window makeFirstResponder:m_MainSplitView.rightTabbedHolder.current];
    else
        [self.window makeFirstResponder:m_MainSplitView.leftTabbedHolder.current];
}

- (void)ActivatePanelByController:(PanelController *)controller
{
    if([self isLeftController:controller]) {
        if(m_MainSplitView.leftTabbedHolder.current == controller.view) {
            [self.window makeFirstResponder:m_MainSplitView.leftTabbedHolder.current];
            return;
        }
        for(NSTabViewItem *it in m_MainSplitView.leftTabbedHolder.tabView.tabViewItems)
            if(it.view == controller.view) {
                [m_MainSplitView.leftTabbedHolder.tabView selectTabViewItem:it];
                [self.window makeFirstResponder:it.view];
                return;
            }
    }
    else if([self isRightController:controller]) {
        if(m_MainSplitView.rightTabbedHolder.current == controller.view) {
            [self.window makeFirstResponder:m_MainSplitView.rightTabbedHolder.current];
            return;
        }
        for(NSTabViewItem *it in m_MainSplitView.rightTabbedHolder.tabView.tabViewItems)
            if(it.view == controller.view) {
                [m_MainSplitView.rightTabbedHolder.tabView selectTabViewItem:it];
                [self.window makeFirstResponder:it.view];
                return;
            }
    }
}

- (void)activePanelChangedTo:(PanelController *)controller
{
    [self UpdateTitle];
    [self updateTabBarButtons];
}

- (void) UpdateTitle
{
    auto data = self.activePanelData;
    if(!data) {
        self.window.title = @"";
        return;
    }
    string path_raw = data->VerboseDirectoryFullPath();
    
    NSString *path = [NSString stringWithUTF8String:path_raw.c_str()];
    if(path == nil)
    {
        self.window.title = @"...";
        return;
    }
    
    // find window geometry
    NSWindow* window = [self window];
    float leftEdge = NSMaxX([[window standardWindowButton:NSWindowZoomButton] frame]);
    NSButton* fsbutton = [window standardWindowButton:NSWindowFullScreenButton];
    float rightEdge = fsbutton ? [fsbutton frame].origin.x : NSMaxX([window frame]);
         
    // Leave 8 pixels of padding around the title.
    const int kTitlePadding = 8;
    float titleWidth = rightEdge - leftEdge - 2 * kTitlePadding;
         
    // Sending |titleBarFontOfSize| 0 returns default size
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont titleBarFontOfSize:0] forKey:NSFontAttributeName];
    window.title = StringByTruncatingToWidth(path, titleWidth, kTruncateAtStart, attributes);
}

- (void) savePanelsOptions
{
    [self savePanelOptionsFor:self.leftPanelController];
    [self savePanelOptionsFor:self.rightPanelController];
}

- (void) savePanelOptionsFor:(PanelController*)_pc
{
    if(_pc == self.leftPanelController)
        [NSUserDefaults.standardUserDefaults setObject:_pc.options forKey:g_DefsPanelsLeftOptions];
    else if(_pc == self.rightPanelController)
        [NSUserDefaults.standardUserDefaults setObject:_pc.options forKey:g_DefsPanelsRightOptions];
}

- (void)flagsChanged:(NSEvent *)event
{
    for(auto p: m_LeftPanelControllers) [p ModifierFlagsChanged:event.modifierFlags];
    for(auto p: m_RightPanelControllers) [p ModifierFlagsChanged:event.modifierFlags];
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if(_panel == nil)
        return;

    if(_panel == self.activePanelController)
        [self UpdateTitle];
    
    [self updateTabNameForController:_panel];
    
    if(_panel == self.leftPanelController)
        [m_LeftPanelGoToButton SetCurrentPath:_panel.currentDirectoryPath
                                           at:_panel.VFS];
    if(_panel == self.rightPanelController)
        [m_RightPanelGoToButton SetCurrentPath:_panel.currentDirectoryPath
                                            at:_panel.VFS];
}

- (void) DidBecomeKeyWindow
{
    // update key modifiers state for views
    unsigned long flags = [NSEvent modifierFlags];
    for(auto p: m_LeftPanelControllers) [p ModifierFlagsChanged:flags];
    for(auto p: m_RightPanelControllers) [p ModifierFlagsChanged:flags];
}

- (void)WindowDidResize
{
    [self UpdateTitle];
    
    // update some toolbar items' visibility
    // hardcoded for now, mb write some separate class later
    if(m_Toolbar.visible && sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8) {
        if(self.window.frame.size.width < 686) {
            if(m_Toolbar.items.count == [self toolbarAllowedItemIdentifiers:m_Toolbar].count) {
                // need to hide spinning indicators
                [m_Toolbar removeItemAtIndex:6];
                [m_Toolbar removeItemAtIndex:2];
            }
        }
        else {
            if(m_Toolbar.items.count < [self toolbarAllowedItemIdentifiers:m_Toolbar].count) {
                // need to show spinning indicators
                [m_Toolbar insertItemWithItemIdentifier:@"filepanels_left_spinning_indicator" atIndex:2];
                [m_Toolbar insertItemWithItemIdentifier:@"filepanels_right_spinning_indicator" atIndex:6];
            }
        }
    }
}

- (void)WindowWillClose
{
   [self SavePanelPaths];
}

- (void)SavePanelPaths
{
    [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithUTF8String:self.leftPanelController.lastNativeDirectoryPath.c_str()]
                                            forKey:@"FirstPanelPath"];
    [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithUTF8String:self.rightPanelController.lastNativeDirectoryPath.c_str()]
                                            forKey:@"SecondPanelPath"];
}

- (bool)WindowShouldClose:(MainWindowController*)sender
{
    if (m_OperationsController.OperationsCount == 0)
        return true;
    
    MessageBox *dialog = [[MessageBox alloc] init];
    [dialog addButtonWithTitle:@"Stop And Close"];
    [dialog addButtonWithTitle:@"Cancel"];
    [dialog setMessageText:@"Window has running operations. Do you want to stop them and close the window?"];
    [dialog ShowSheetWithHandler:self.window handler:^(int result) {
        if (result == NSAlertFirstButtonReturn)
        {
            [m_OperationsController Stop];
            [dialog.window orderOut:nil];
            [self.window close];
        }
    }];
    
    return false;
}

- (void)RevealEntries:(chained_strings)_entries inPath:(const string&)_path
{
    assert(dispatch_is_main_queue());
    auto data = self.activePanelData;
    if(!data)
        return;
    
    PanelController *panel = self.activePanelController;
    if([panel GoToDir:_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok)
    {
        if(!_entries.empty()) {
            PanelControllerDelayedSelection req;
            req.filename = _entries.front().c_str();
            [panel ScheduleDelayedSelectionChangeFor:req
                                            checknow:true];
        }
        
        for(auto &i: _entries)
            data->CustomFlagsSelectSorted(data->SortedIndexForName(i.c_str()), true);
        
        [self.activePanelView setNeedsDisplay];
    }
}

- (void)OnApplicationWillTerminate
{
    [self SavePanelPaths];
}

- (IBAction)paste:(id)sender
{
    if([m_MainSplitView isViewCollapsedOrOverlayed:self.activePanelView])
        return;
    
    NSPasteboard *paste_board = [NSPasteboard generalPasteboard];

    // check what's inside pasteboard
    NSString *best_type = [paste_board availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]];
    if(!best_type)
        return;

    // check if we're on writeable VFS
    if(!self.isPanelActive ||
       !self.activePanelController.VFS->IsWriteable())
        return;
    
    // input should be an array of filepaths
    NSArray* ns_filenames = [paste_board propertyListForType:NSFilenamesPboardType];
    if(!ns_filenames)
        return;
    
    map<string, vector<string>> filenames; // root directory to containing filename maps
    for(NSString *ns_filename in ns_filenames)
    {
        // filenames are without trailing slashes for dirs here
        char dir[MAXPATHLEN], fn[MAXPATHLEN];
        if(!GetDirectoryContainingItemFromPath([ns_filename fileSystemRepresentation], dir))
            continue;
        if(!GetFilenameFromPath([ns_filename fileSystemRepresentation], fn))
           continue;
        filenames[dir].push_back(fn);
    }
    
    if(filenames.empty()) // invalid pasteboard?
        return;
    
    string destination = self.activePanelData->DirectoryPathWithTrailingSlash();
    
    for(auto i: filenames)
    {
        chained_strings files;
        for(auto j: i.second)
            files.push_back(j.c_str(), (int)j.length(), nullptr);
        
        FileCopyOperationOptions opts;
        opts.docopy = true;
        
        Operation *op;
        
        if(self.activePanelController.VFS->IsNativeFS())
            op = [[FileCopyOperation alloc] initWithFiles:move(files)
                                                     root:i.first.c_str()
                                                     dest:destination.c_str()
                                                  options:opts]; // native->native
        else
            op = [[FileCopyOperation alloc] initWithFiles:move(files)
                                                     root:i.first.c_str()
                                                   srcvfs:VFSNativeHost::SharedHost()
                                                     dest:destination.c_str()
                                                   dstvfs:self.activePanelController.VFS
                                                  options:opts]; // vfs(native)->vfs
        
        __weak PanelController *wpc = self.activePanelController;
        [op AddOnFinishHandler:^{
            dispatch_to_main_queue( ^{
                if(PanelController *pc = wpc) [pc RefreshDirectory];
            });
        }];
        
        [m_OperationsController AddOperation:op];
    }
}

- (IBAction)copy:(id)sender
{
    [self WriteFilesnamesPBoard:NSPasteboard.generalPasteboard];
    // check if we're on native fs now (all others vfs are not-accessible by system and so useless)
}

- (void)GetFilePanelsNativePaths:(vector<string> &)_paths
{
    _paths.clear();
    
    for(auto p: m_LeftPanelControllers)
        if(p.VFS->IsNativeFS())
            _paths.push_back(p.currentDirectoryPath);
    for(auto p: m_RightPanelControllers)
        if(p.VFS->IsNativeFS())
            _paths.push_back(p.currentDirectoryPath);
}

- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel
{
    QuickLookView *view = [[QuickLookView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    if([self isLeftController:_panel])
        m_MainSplitView.rightOverlay = view;
    else if([self isRightController:_panel])
        m_MainSplitView.leftOverlay = view;
    else
        return nil;
    return view;
}

- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel
{
    BriefSystemOverview *view = [[BriefSystemOverview alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    if([self isLeftController:_panel])
        m_MainSplitView.rightOverlay = view;
    else if([self isRightController:_panel])
        m_MainSplitView.leftOverlay = view;
    else
        return nil;
    return view;
}

- (void)CloseOverlay:(PanelController*)_panel
{
    if([self isLeftController:_panel])
        m_MainSplitView.rightOverlay = 0;
    else if([self isRightController:_panel])
        m_MainSplitView.leftOverlay = 0;
}

- (void) AddOperation:(Operation*)_operation
{
    [m_OperationsController AddOperation:_operation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Check if defaults changed.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (object == defaults) {
        // Check if the skin value was modified.
        if ([keyPath isEqualToString:g_DefsGeneralShowTabs]) {
            bool show = [defaults boolForKey:g_DefsGeneralShowTabs];
            dispatch_to_main_queue_after(1ms, ^{
                m_ShowTabs = show;
                [self updateTabBarsVisibility];
            });
        }
    }
}

@end
