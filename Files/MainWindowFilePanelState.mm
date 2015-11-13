//
//  MainWindowFilePanelState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#include "vfs/vfs_native.h"
#include "Operations/Copy/FileCopyOperation.h"
#include "Operations/OperationsController.h"
#include "Operations/OperationsSummaryViewController.h"
#include "MainWindowFilePanelState.h"
#include "PanelController.h"
#include "PanelController+DataAccess.h"
#include "Common.h"
#include "ApplicationSkins.h"
#include "AppDelegate.h"
#include "ClassicPanelViewPresentation.h"
#include "ModernPanelViewPresentation.h"
#include "MainWndGoToButton.h"
#include "QuickPreview.h"
#include "MainWindowController.h"
#include "FilePanelMainSplitView.h"
#include "BriefSystemOverview.h"
#include "sysinfo.h"
#include "LSUrls.h"
#include "ActionsShortcutsManager.h"
#include "SandboxManager.h"
#include "FilePanelOverlappedTerminal.h"

static auto g_DefsPanelsLeftOptions  = @"FilePanelsLeftPanelViewState";
static auto g_DefsPanelsRightOptions = @"FilePanelsRightPanelViewState";
static auto g_DefsGeneralShowTabs = @"GeneralShowTabs";
static auto g_DefsGoToActivation = @"FilePanelsGeneralGoToForceActivation";

static map<string, vector<string>> LayoutPathsByContainingDirectories( NSArray *_input ) // array of NSStrings
{
    if(!_input)
        return {};
    map<string, vector<string>> filenames; // root directory to containing filenames map
    for( NSString *ns_filename in _input ) {
        if( !objc_cast<NSString>(ns_filename) ) continue; // guard againts malformed input
        // filenames are without trailing slashes for dirs here
        char dir[MAXPATHLEN], fn[MAXPATHLEN];
        if(!GetDirectoryContainingItemFromPath([ns_filename fileSystemRepresentation], dir))
            continue;
        if(!GetFilenameFromPath([ns_filename fileSystemRepresentation], fn))
            continue;
        filenames[dir].push_back(fn);
    }
    return filenames;
}

static vector<VFSListingItem> FetchVFSListingsItemsFromDirectories( const map<string, vector<string>>& _input, VFSHost& _host)
{
    vector<VFSListingItem> source_items;
    for( auto &dir: _input ) {
        vector<VFSListingItem> items_for_dir;
        if( _host.FetchFlexibleListingItems(dir.first, dir.second, 0, items_for_dir, nullptr) == VFSError::Ok )
            move( begin(items_for_dir), end(items_for_dir), back_inserter(source_items) );
    }
    return source_items;
}

@implementation MainWindowFilePanelState

@synthesize OperationsController = m_OperationsController;

- (id) initWithFrame:(NSRect)frameRect Window:(NSWindow*)_wnd;
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        m_OverlappedTerminal.bottom_gap = 0;
        m_OverlappedTerminal.did_hide_panels_for_long_task = false;
        m_ShowTabs = [defaults boolForKey:g_DefsGeneralShowTabs];
        m_GoToForceActivation = [defaults boolForKey:g_DefsGoToActivation];
        
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
                [left_controller GoToDir:CommonPaths::Home()
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
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
    }
    return self;
}

- (void) dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:g_DefsGeneralShowTabs];
    [NSNotificationCenter.defaultCenter removeObserver:self];
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
    
    m_LeftPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 23)];
    m_LeftPanelGoToButton.target = self;
    m_LeftPanelGoToButton.action = @selector(LeftPanelGoToButtonAction:);
    m_LeftPanelGoToButton.owner = self;
    m_LeftPanelGoToButton.isRight = false;
    
    m_RightPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 23)];
    m_RightPanelGoToButton.target = self;
    m_RightPanelGoToButton.action = @selector(RightPanelGoToButtonAction:);
    m_RightPanelGoToButton.owner = self;
    m_RightPanelGoToButton.isRight = true;
    
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
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_SeparatorLine(<=1)]-(==0)-[m_MainSplitView]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_MainSplitView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SeparatorLine]-(==0)-|" options:0 metrics:nil views:views]];
    m_MainSplitViewBottomConstraint = [NSLayoutConstraint constraintWithItem:m_MainSplitView
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1
                                                                    constant:0];
    m_MainSplitViewBottomConstraint.priority = NSLayoutPriorityDragThatCannotResizeWindow;
    [self addConstraint:m_MainSplitViewBottomConstraint];
    
    if( configuration::has_terminal ) {
        m_OverlappedTerminal.terminal = [[FilePanelOverlappedTerminal alloc] initWithFrame:self.bounds];
        m_OverlappedTerminal.terminal.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_OverlappedTerminal.terminal positioned:NSWindowBelow relativeTo:nil];
        
        auto terminal = m_OverlappedTerminal.terminal;
        views = NSDictionaryOfVariableBindings(terminal);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==1)-[terminal]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[terminal]-(0)-|" options:0 metrics:nil views:views]];
    }
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
               @[ @"filepanels_left_goto_button",
                  @"filepanels_left_share_button",
                  @"filepanels_left_spinning_indicator",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_operations_box",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_right_spinning_indicator",
                  @"filepanels_right_share_button",
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
    if( !self.overlappedTerminalVisible && !self.isPanelActive)
        [self.window makeFirstResponder:m_MainSplitView.leftTabbedHolder.current];
    
    [self UpdateTitle];
}

- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{
    if(([sendType isEqualToString:NSFilenamesPboardType] ||
        [sendType isEqualToString:(__bridge NSString *)kUTTypeFileURL]) &&
       self.isPanelActive &&
       self.activePanelData->Listing().HasCommonHost() &&
       self.activePanelData->Listing().Host()->IsNativeFS() )
        return self;
    
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
    if([types containsObject:NSFilenamesPboardType])
        return [self writeFilesnamesPBoard:pboard];
        
    if([types containsObject:(__bridge NSString *)kUTTypeFileURL])
        return [self writeURLSPBoard:pboard];
    
    return NO;
}

- (bool)writeFilesnamesPBoard:(NSPasteboard *)pboard
{
    if( !self.isPanelActive )
        return false;
    
    NSMutableArray *filenames = [NSMutableArray new];
    for( auto &i: self.activePanelController.selectedEntriesOrFocusedEntry )
        if( i.Host()->IsNativeFS() )
            [filenames addObject:[NSString stringWithUTF8StdString:i.Path()]];
    
    if( filenames.count == 0 )
        return false;
    
    [pboard clearContents];
    [pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    return [pboard setPropertyList:filenames forType:NSFilenamesPboardType] == TRUE;
}

- (bool)writeURLSPBoard:(NSPasteboard *)pboard
{
    if(!self.isPanelActive ||
       !self.activePanelController.vfs->IsNativeFS())
        return false;
    
    NSMutableArray *fileurls = [NSMutableArray new];
    auto dir = self.activePanelController.currentDirectoryPath;
    for(auto &i: self.activePanelController.selectedEntriesOrFocusedEntryFilenames)
        [fileurls addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8StdString:dir + i]]];
    
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
    if(_wnd == nil) {
        m_LastResponder = nil;
        if( auto resp = objc_cast<NSView>(self.window.firstResponder) )
            if( [resp isDescendantOf:self] )
                m_LastResponder = resp;
    }
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender
{
    auto *selection = m_LeftPanelGoToButton.selection;
    if(!selection)
        return;
    
    m_MainSplitView.leftOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    
    if( !self.leftPanelController.isActive && m_GoToForceActivation )
        [self ActivatePanelByController:self.leftPanelController];
    
    if(auto vfspath = objc_cast<MainWndGoToButtonSelectionVFSPath>(selection)) {
        VFSHostPtr host = vfspath.vfs.lock();
        if(!host)
            return;
        
        if(host->IsNativeFS() && ![PanelController ensureCanGoToNativeFolderSync:vfspath.path])
            return;
        
        [self.leftPanelController GoToDir:vfspath.path vfs:host select_entry:"" async:true];
    }
    else if(auto info = objc_cast<MainWndGoToButtonSelectionSavedNetworkConnection>(selection)) {
        [self.leftPanelController GoToSavedConnection:info.connection];
    }
}

- (IBAction)RightPanelGoToButtonAction:(id)sender
{
    auto *selection = m_RightPanelGoToButton.selection;
    if(!selection)
        return;
    
    m_MainSplitView.rightOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    
    if( !self.rightPanelController.isActive && m_GoToForceActivation )
        [self ActivatePanelByController:self.rightPanelController];
    
    if(auto vfspath = objc_cast<MainWndGoToButtonSelectionVFSPath>(selection)) {
        VFSHostPtr host = vfspath.vfs.lock();
        if(!host)
            return;
        
        if(host->IsNativeFS() && ![PanelController ensureCanGoToNativeFolderSync:vfspath.path])
            return;
        
        [self.rightPanelController GoToDir:vfspath.path vfs:host select_entry:"" async:true];
    }
    else if(auto info = objc_cast<MainWndGoToButtonSelectionSavedNetworkConnection>(selection)) {
        [self.rightPanelController GoToSavedConnection:info.connection];
    }
}

- (IBAction)LeftPanelGoto:(id)sender {
    [m_LeftPanelGoToButton popUp];
}

- (IBAction)RightPanelGoto:(id)sender {
    [m_RightPanelGoToButton popUp];
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
    return objc_cast<PanelController>(m_MainSplitView.leftTabbedHolder.current.delegate);
}

- (PanelController*) rightPanelController
{
    return objc_cast<PanelController>(m_MainSplitView.rightTabbedHolder.current.delegate);
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
    m_LastFocusedPanelController = controller;
    [self synchronizeOverlappedTerminalWithPanel:controller];
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

    if(_panel == self.activePanelController) {
        [self UpdateTitle];
        [self synchronizeOverlappedTerminalWithPanel:_panel];
    }
    
    [self updateTabNameForController:_panel];    
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

- (void)WindowWillClose
{
   [self SavePanelPaths];
}

- (void)SavePanelPaths
{
    if(PanelController *pc = self.leftPanelController)
        [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithUTF8String:pc.lastNativeDirectoryPath.c_str()] forKey:@"FirstPanelPath"];
    if(PanelController *pc = self.rightPanelController)
        [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithUTF8String:pc.lastNativeDirectoryPath.c_str()] forKey:@"SecondPanelPath"];
}

- (bool)WindowShouldClose:(MainWindowController*)sender
{
    if (m_OperationsController.OperationsCount == 0 &&
        !self.isAnythingRunningInOverlappedTerminal )
        return true;
    
    NSAlert *dialog = [[NSAlert alloc] init];
    [dialog addButtonWithTitle:NSLocalizedString(@"Stop And Close", "User action to stop running actions and close window")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    dialog.messageText = NSLocalizedString(@"Window has running operations. Do you want to stop them and close the window?", "Asking user to close window with some operations running");
    [dialog beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSAlertFirstButtonReturn) {
            [m_OperationsController Stop];
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
            [panel ScheduleDelayedSelectionChangeFor:req];
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

    // check if we're on uniform panel with a writeable VFS
    if(!self.isPanelActive ||
       !self.activePanelController.isUniform ||
       !self.activePanelController.vfs->IsWriteable())
        return;

    // check what's inside pasteboard
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    if( [pasteboard availableTypeFromArray:@[NSFilenamesPboardType]] ) {
        // input should be an array of filepaths as NSStrings
        auto filepaths = objc_cast<NSArray>([pasteboard propertyListForType:NSFilenamesPboardType]);

        // currently fetching listings synchronously, which is BAAAD
        auto source_items = FetchVFSListingsItemsFromDirectories(LayoutPathsByContainingDirectories(filepaths),
                                                                 *VFSNativeHost::SharedHost());
        if( source_items.empty() )
            return; // errors on fetching listings?
        
        FileCopyOperationOptions opts;
        opts.docopy = true;
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(source_items)
                                           destinationPath:self.activePanelController.currentDirectoryPath
                                           destinationHost:self.activePanelController.vfs
                                                   options:opts];

        __weak PanelController *wpc = self.activePanelController;
        [op AddOnFinishHandler:^{
            dispatch_to_main_queue( [=]{
                if(PanelController *pc = wpc) [pc RefreshDirectory];
            });
        }];
        
        [m_OperationsController AddOperation:op];
    }
}

- (IBAction)copy:(id)sender
{
    [self writeFilesnamesPBoard:NSPasteboard.generalPasteboard];
    // check if we're on native fs now (all others vfs are not-accessible by system and so useless)
}

- (vector<tuple<string, VFSHostPtr> >)filePanelsCurrentPaths
{
    vector<tuple<string, VFSHostPtr> > r;
    for( auto c: {&m_LeftPanelControllers, &m_RightPanelControllers} )
        for( auto p: *c )
            if( p.isUniform )
                r.emplace_back( p.currentDirectoryPath, p.vfs);
    return r;
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
            dispatch_to_main_queue_after(1ms, [=]{
                m_ShowTabs = show;
                [self updateTabBarsVisibility];
            });
        }
    }
}

- (void)frameDidChange
{
    auto gap = [m_OverlappedTerminal.terminal bottomGapForLines:m_OverlappedTerminal.bottom_gap];
    m_MainSplitViewBottomConstraint.constant = -gap;
}

- (bool)isPanelsSplitViewHidden
{
    return m_MainSplitView.hidden;
}

- (void)requestTerminalExecution:(const string&)_filename at:(const string&)_cwd
{
    if( ![self executeInOverlappedTerminalIfPossible:_filename at:_cwd] )
        [(MainWindowController*)self.window.delegate RequestTerminalExecution:_filename.c_str() at:_cwd.c_str()];
}

@end
