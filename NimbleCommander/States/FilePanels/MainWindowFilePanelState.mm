#include <Habanero/CommonPaths.h>
#include <Utility/PathManip.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/ColoredSeparatorLine.h>
#include <VFS/Native.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/LSUrls.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/FeedbackManager.h>
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include <NimbleCommander/Operations/OperationsController.h>
#include <NimbleCommander/Operations/OperationsSummaryViewController.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "MainWindowFilePanelState.h"
#include "PanelController.h"
#include "PanelController+DataAccess.h"
#include "MainWindowFilePanelsStateToolbarDelegate.h"
#include "AskingForRatingOverlayView.h"
#include "Favorites.h"
#include "Views/MainWndGoToButton.h"
#include "Views/QuickPreview.h"
#include "Views/FilePanelMainSplitView.h"
#include "Views/BriefSystemOverview.h"
#include "Views/FilePanelOverlappedTerminal.h"

static const auto g_ConfigGoToActivation    = "filePanel.general.goToButtonForcesPanelActivation";
static const auto g_ConfigInitialLeftPath   = "filePanel.general.initialLeftPanelPath";
static const auto g_ConfigInitialRightPath  = "filePanel.general.initialRightPanelPath";
static const auto g_ConfigGeneralShowTabs   = "general.showTabs";
static const auto g_ResorationPanelsKey     = "panels_v1";
static const auto g_ResorationUIKey         = "uiState";
static const auto g_ResorationUISelectedLeftTab = "selectedLeftTab";
static const auto g_ResorationUISelectedRightTab = "selectedRightTab";
static const auto g_ResorationUIFocusedSide = "focusedSide";

static string ExpandPath(const string &_ref )
{
    if( _ref.empty() )
        return {};
    
    if( _ref.front() == '/' ) // absolute path
        return _ref;
    
    if( _ref.front() == '~' ) { // relative to home
        auto ref = _ref.substr(1);
        path p = path(CommonPaths::Home());
        if( !ref.empty() )
            p.remove_filename();
        p /= ref;
        return p.native();
    }
    
    return {};
}

static void SetupUnregisteredLabel(NSView *_background_view)
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,0,0)];
    tf.translatesAutoresizingMaskIntoConstraints = false;
    tf.stringValue = @"UNREGISTERED";
    tf.editable = false;
    tf.bordered = false;
    tf.drawsBackground = false;
    tf.alignment = NSTextAlignmentCenter;
    tf.textColor = NSColor.tertiaryLabelColor;
    tf.font = [NSFont labelFontOfSize:12];
    
    [_background_view addSubview:tf];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1.0
                                                                  constant:2]];
    [_background_view layoutSubtreeIfNeeded];
}

static void SetupRatingOverlay(NSView *_background_view)
{
    AskingForRatingOverlayView *v = [[AskingForRatingOverlayView alloc] initWithFrame:_background_view.bounds];
    [_background_view addSubview:v];
}

static bool GoToForcesPanelActivation()
{
    static const auto fetch = []{
        return GlobalConfig().GetBool(g_ConfigGoToActivation);
    };
    static bool force = []{
        static auto ticket = GlobalConfig().Observe(g_ConfigGoToActivation, []{
            force = fetch();
        });
        return fetch();
    }();
    return force;
}

@implementation MainWindowFilePanelState

@synthesize OperationsController = m_OperationsController;
@synthesize operationsSummaryView = m_OpSummaryController;

- (instancetype) initBaseWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect] ) {        
        m_OverlappedTerminal = make_unique<MainWindowFilePanelState_OverlappedTerminalSupport>();
        m_ShowTabs = GlobalConfig().GetBool(g_ConfigGeneralShowTabs);
        
        m_OperationsController = [[OperationsController alloc] init];
        m_OpSummaryController = [[OperationsSummaryViewController alloc] initWithController:m_OperationsController];
        // setup background view if any show be shown
        if( FeedbackManager::Instance().ShouldShowRatingOverlayView() )
            SetupRatingOverlay( m_OpSummaryController.backgroundView );
        else if( ActivationManager::Type() == ActivationManager::Distribution::Trial && !ActivationManager::Instance().UserHadRegistered() )
            SetupUnregisteredLabel(m_OpSummaryController.backgroundView);
        
        m_LeftPanelControllers.emplace_back([PanelController new]);
        m_RightPanelControllers.emplace_back([PanelController new]);
        
        [self CreateControls];
        
        // panel creation and preparation
        m_LeftPanelControllers.front().state = self;
        [m_LeftPanelControllers.front() AttachToControls:m_ToolbarDelegate.leftPanelSpinningIndicator
                                                   share:m_ToolbarDelegate.leftPanelShareButton];
        m_RightPanelControllers.front().state = self;
        [m_RightPanelControllers.front() AttachToControls:m_ToolbarDelegate.rightPanelSpinningIndicator
                                                    share:m_ToolbarDelegate.rightPanelShareButton];
        
        [self updateTabBarsVisibility];
        [self loadOverlappedTerminalSettingsAndRunIfNecessary];
     
        [self setupNotificationsCallbacks];
    }
    return self;
}

- (instancetype) initWithFrame:(NSRect)frameRect
{
    if( self = [self initBaseWithFrame:frameRect] ) {
        [self loadDefaultPanelContent];
    }
    return self;
}

- (instancetype) initEmptyFileStateWithFrame:(NSRect)frameRect
{
    if( self = [self initBaseWithFrame:frameRect] ) {
    }
    return self;
}

- (void) setupNotificationsCallbacks
{
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(frameDidChange)
                                               name:NSViewFrameDidChangeNotification
                                             object:self];
    
    m_ConfigTickets.emplace_back( GlobalConfig().Observe(
        g_ConfigGeneralShowTabs, objc_callback(self, @selector(onShowTabsSettingChanged))));
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)acceptsFirstResponder { return true; }
- (NSToolbar*)toolbar { return m_ToolbarDelegate.toolbar; }
- (NSView*) windowContentView { return self; }
- (BOOL) isOpaque { return true; }
- (BOOL) wantsUpdateLayer { return true; }

- (void) updateLayer
{
    self.layer.backgroundColor = CurrentTheme().FilePanelsGeneralOverlayColor().CGColor;
}

- (void) loadDefaultPanelContent
{
    auto &am = ActivationManager::Instance();
    auto left_controller = m_LeftPanelControllers.front();
    auto right_controller = m_RightPanelControllers.front();
    
    vector<string> left_panel_desired_paths, right_panel_desired_paths;
    
    // 1st attempt - load editable default path from config
    if( auto v = GlobalConfig().GetString(g_ConfigInitialLeftPath) )
        left_panel_desired_paths.emplace_back( ExpandPath(*v) );
    if( auto v = GlobalConfig().GetString(g_ConfigInitialRightPath) )
        right_panel_desired_paths.emplace_back( ExpandPath(*v) );
    
    // 2nd attempt - load home path
    left_panel_desired_paths.emplace_back( CommonPaths::Home() );
    right_panel_desired_paths.emplace_back( CommonPaths::Home() );
    
    // 3rd attempt - load first reachable folder in case of sandboxed environment
    if( am.Sandboxed() ) {
        left_panel_desired_paths.emplace_back( SandboxManager::Instance().FirstFolderWithAccess() );
        right_panel_desired_paths.emplace_back( SandboxManager::Instance().FirstFolderWithAccess() );
    }
    
    // 4rth attempt - load dir at startup cwd
    left_panel_desired_paths.emplace_back( CommonPaths::StartupCWD() );
    right_panel_desired_paths.emplace_back( CommonPaths::StartupCWD() );
    
    for( auto &p: left_panel_desired_paths ) {
        if( am.Sandboxed() && !SandboxManager::Instance().CanAccessFolder(p) )
            continue;
        if( [left_controller GoToDir:p vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok )
            break;
    }

    for( auto &p: right_panel_desired_paths ) {
        if( am.Sandboxed() && !SandboxManager::Instance().CanAccessFolder(p) )
            continue;
        if( [right_controller GoToDir:p vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok )
            break;
    }
}

- (void) CreateControls
{
    m_MainSplitView = [[FilePanelMainSplitView alloc] initWithFrame:NSRect()];
    m_MainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [m_MainSplitView.leftTabbedHolder addPanel:m_LeftPanelControllers.front().view];
    [m_MainSplitView.rightTabbedHolder addPanel:m_RightPanelControllers.front().view];
    m_MainSplitView.leftTabbedHolder.tabBar.delegate = self;
    m_MainSplitView.rightTabbedHolder.tabBar.delegate = self;
    [self addSubview:m_MainSplitView];
    
    m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    m_SeparatorLine.boxType = NSBoxSeparator;
    m_SeparatorLine.borderColor = CurrentTheme().FilePanelsGeneralTopSeparatorColor();
    [self addSubview:m_SeparatorLine];
    
    m_ToolbarDelegate = [[MainWindowFilePanelsStateToolbarDelegate alloc] initWithFilePanelsState:self];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_MainSplitView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0@250)-[m_SeparatorLine(<=1)]-(==0)-[m_MainSplitView]" options:0 metrics:nil views:views]];
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
    
    if( ActivationManager::Instance().HasTerminal() ) {
        m_OverlappedTerminal->terminal = [[FilePanelOverlappedTerminal alloc] initWithFrame:self.bounds];
        m_OverlappedTerminal->terminal.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_OverlappedTerminal->terminal positioned:NSWindowBelow relativeTo:nil];
        
        auto terminal = m_OverlappedTerminal->terminal;
        views = NSDictionaryOfVariableBindings(terminal, m_SeparatorLine);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(0)-[terminal]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[terminal]-(0)-|" options:0 metrics:nil views:views]];
    }
    else {
        /* Fixing bugs in NSISEngine, kinda */
        NSView *dummy = [[NSView alloc] initWithFrame:self.bounds];
        dummy.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:dummy positioned:NSWindowBelow relativeTo:nil];
        views = NSDictionaryOfVariableBindings(dummy);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==1)-[dummy(>=100)]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[dummy(>=100)]-(0)-|" options:0 metrics:nil views:views]];
    }
}

- (void) Assigned
{
    NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem:m_SeparatorLine
                                                         attribute:NSLayoutAttributeTop
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self.window.contentLayoutGuide
                                                         attribute:NSLayoutAttributeTop
                                                        multiplier:1
                                                          constant:0];
    c.active = true;
//    [self layoutSubtreeIfNeeded];

    if( m_LastResponder ) {
        // if we already were active and have some focused view - restore it
        [self.window makeFirstResponder:m_LastResponder];
        m_LastResponder = nil;
    }
    else {
        // if we don't know which view should be active - make left panel a first responder
        [self.window makeFirstResponder:m_MainSplitView.leftTabbedHolder.current];
    }
    
    [self UpdateTitle];
    
    // think it's a bad idea to post messages on every new window created
    GA().PostScreenView("File Panels State");
}

- (void) Resigned
{
}

- (void) layout
{
//    cout << self.bounds.size.width << " " << self.bounds.size.height << endl;
    [super layout];
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

- (IBAction)onLeftPanelGoToButtonAction:(id)sender
{
    auto *selection = m_ToolbarDelegate.leftPanelGoToButton.selection;
    if(!selection)
        return;
    if( m_MainSplitView.isLeftCollapsed )
        [m_MainSplitView expandLeftView];
    
    m_MainSplitView.leftOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    
    if( !self.leftPanelController.isActive && GoToForcesPanelActivation() )
        [self ActivatePanelByController:self.leftPanelController];
    
    if(auto vfspath = objc_cast<MainWndGoToButtonSelectionVFSPath>(selection)) {
        VFSHostPtr host = vfspath.vfs.lock();
        if(!host)
            return;
        
        if(host->IsNativeFS() && ![PanelController ensureCanGoToNativeFolderSync:vfspath.path])
            return;
        
        [self.leftPanelController GoToDir:vfspath.path vfs:host select_entry:"" async:true];
    }
    else if(auto info = objc_cast<MainWndGoToButtonSelectionSavedNetworkConnection>(selection))
        [self.leftPanelController GoToSavedConnection:info.connection];
    else if( auto f = objc_cast<MainWndGoToButtonSelectionFavorite>(selection))
        [self.leftPanelController goToPersistentLocation:f.favorite.location->hosts_stack];
}

- (IBAction)onRightPanelGoToButtonAction:(id)sender
{
    auto *selection = m_ToolbarDelegate.rightPanelGoToButton.selection;
    if(!selection)
        return;
    if( m_MainSplitView.isRightCollapsed )
        [m_MainSplitView expandRightView];
    
    m_MainSplitView.rightOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    
    if( !self.rightPanelController.isActive && GoToForcesPanelActivation() )
        [self ActivatePanelByController:self.rightPanelController];
    
    if(auto vfspath = objc_cast<MainWndGoToButtonSelectionVFSPath>(selection)) {
        VFSHostPtr host = vfspath.vfs.lock();
        if(!host)
            return;
        
        if(host->IsNativeFS() && ![PanelController ensureCanGoToNativeFolderSync:vfspath.path])
            return;
        
        [self.rightPanelController GoToDir:vfspath.path vfs:host select_entry:"" async:true];
    }
    else if(auto info = objc_cast<MainWndGoToButtonSelectionSavedNetworkConnection>(selection))
        [self.rightPanelController GoToSavedConnection:info.connection];
    else if( auto f = objc_cast<MainWndGoToButtonSelectionFavorite>(selection))
        [self.rightPanelController goToPersistentLocation:f.favorite.location->hosts_stack];
    
}

- (IBAction)LeftPanelGoto:(id)sender {
    [m_ToolbarDelegate.leftPanelGoToButton popUp];
}

- (IBAction)RightPanelGoto:(id)sender {
    [m_ToolbarDelegate.rightPanelGoToButton popUp];
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
    if( NSResponder *r = self.window.firstResponder ) {
        for(auto &pc: m_LeftPanelControllers)  if(r == pc.view) return pc;
        for(auto &pc: m_RightPanelControllers) if(r == pc.view) return pc;
    }
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

- (void) changeFocusedSide
{
    if( m_MainSplitView.anyCollapsedOrOverlayed )
        return;
    if( auto cur = self.activePanelController ) {
        if( [self isLeftController:cur] )
            [self.window makeFirstResponder:m_MainSplitView.rightTabbedHolder.current];
        else
            [self.window makeFirstResponder:m_MainSplitView.leftTabbedHolder.current];
    }
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
                [self.window makeFirstResponder:controller.view];
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
                [self.window makeFirstResponder:controller.view];
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
    [self markRestorableStateAsInvalid];
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

static rapidjson::StandaloneValue EncodePanelsStates(
    const vector<PanelController*> &_left,
    const vector<PanelController*> &_right)
{
    using namespace rapidjson;
    StandaloneValue json{kArrayType};
    StandaloneValue left{kArrayType};
    StandaloneValue right{kArrayType};
    
    for( auto pc: _left )
        if( auto v = [pc encodeRestorableState] )
            left.PushBack( move(*v), g_CrtAllocator );
    
    for( auto pc: _right )
        if( auto v = [pc encodeRestorableState] )
            right.PushBack( move(*v), g_CrtAllocator );
    
    json.PushBack( move(left), g_CrtAllocator );
    json.PushBack( move(right), g_CrtAllocator );
    
    return json;
}

static rapidjson::StandaloneValue EncodeUIState(MainWindowFilePanelState *_state)
{
    using namespace rapidjson;
    StandaloneValue ui{kObjectType};
    
    ui.AddMember(MakeStandaloneString( g_ResorationUISelectedLeftTab ),
                 StandaloneValue( _state.leftTabbedHolder.selectedIndex ),
                 g_CrtAllocator);
    
    ui.AddMember(MakeStandaloneString( g_ResorationUISelectedRightTab ),
                 StandaloneValue( _state.rightTabbedHolder.selectedIndex ),
                 g_CrtAllocator);

    const auto right_side_selected = [_state isRightController:_state.activePanelController];
    ui.AddMember(MakeStandaloneString( g_ResorationUIFocusedSide ),
                 MakeStandaloneString( right_side_selected ? "right" : "left" ),
                 g_CrtAllocator);
    
    return ui;
}

- (optional<rapidjson::StandaloneValue>) encodeRestorableState
{
    using namespace rapidjson;
    StandaloneValue json{kObjectType};
    
    json.AddMember(MakeStandaloneString(g_ResorationPanelsKey),
                   EncodePanelsStates( m_LeftPanelControllers, m_RightPanelControllers ),
                   g_CrtAllocator);
    json.AddMember(MakeStandaloneString(g_ResorationUIKey),
                   EncodeUIState(self),
                   g_CrtAllocator);
    
    return move(json);
}

- (void) decodeRestorableState:(const rapidjson::StandaloneValue&)_state
{
    if( !_state.IsObject() )
        return;
    
    if( _state.HasMember(g_ResorationPanelsKey) ) {
        const auto &json_panels = _state[g_ResorationPanelsKey];
        if( json_panels.IsArray() && json_panels.Size() == 2 ) {
            const auto &left = json_panels[0];
            if( left.IsArray() )
                for( auto i = left.Begin(), e = left.End(); i != e; ++i ) {
                    if( i != left.Begin() ) {
                        auto pc = [PanelController new];
                        pc.state = self;
                        [self addNewControllerOnLeftPane:pc];
                        [pc loadRestorableState:*i];
                    }
                    else
                        [m_LeftPanelControllers.front() loadRestorableState:*i];
                }
            
            const auto &right = json_panels[1];
            if( right.IsArray() )
                for( auto i = right.Begin(), e = right.End(); i != e; ++i ) {
                    if( i != right.Begin() ) {
                        auto pc = [PanelController new];
                        pc.state = self;
                        [self addNewControllerOnRightPane:pc];
                        [pc loadRestorableState:*i];
                    }
                    else
                        [m_RightPanelControllers.front() loadRestorableState:*i];
                }
        }
    }
    if( _state.HasMember(g_ResorationUIKey) ) {
        const auto &json_ui = _state[g_ResorationUIKey];
        if( json_ui.IsObject() ) {
            // invalid indeces are ok here, they will be discarded by FilePanelsTabbedHolder
            if( auto sel_left = GetOptionalIntFromObject(json_ui, g_ResorationUISelectedLeftTab) )
                [self.leftTabbedHolder selectTabAtIndex:*sel_left];
            if( auto sel_right = GetOptionalIntFromObject(json_ui, g_ResorationUISelectedRightTab) )
                [self.rightTabbedHolder selectTabAtIndex:*sel_right];
            if( auto side = GetOptionalStringFromObject(json_ui, g_ResorationUIFocusedSide) ) {
                const auto focus = [&]()->PanelController*{
                    if( *side == "right"s  )
                        return self.rightPanelController;
                    else if( *side == "left"s )
                        return self.leftPanelController;
                    return nil;
                }();
                if( focus ) {
                    // if we're already assigned to window - set first responder
                    if( self.window )
                        [self ActivatePanelByController:focus];
                    // if not - memorize it, will set on Assigned
                    else
                        m_LastResponder = focus.view;
                }
            }
        }
    }
}

- (void) markRestorableStateAsInvalid
{
    if( auto wc = objc_cast<MainWindowController>(self.window.delegate) )
        [wc invalidateRestorableState];
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if( _panel == nil )
        return;

    if( _panel == self.activePanelController ) {
        [self UpdateTitle];
        [self synchronizeOverlappedTerminalWithPanel:_panel];
    }
    
    [self updateTabNameForController:_panel];
    
    
    if( _panel.isUniform ) {
        auto &locations = AppDelegate.me.favoriteLocationsStorage;
        locations.ReportLocationVisit( *_panel.vfs, _panel.currentDirectoryPath );
    }
}

//- (void) didBecomeKeyWindow
//{
/*    // update key modifiers state for views
    unsigned long flags = [NSEvent modifierFlags];
    for(auto p: m_LeftPanelControllers) [p ModifierFlagsChanged:flags];
    for(auto p: m_RightPanelControllers) [p ModifierFlagsChanged:flags];*/
//}

- (void)WindowDidResize
{
    [self UpdateTitle];
}

- (void)WindowWillClose
{
    [self saveOverlappedTerminalSettings];
}

- (bool)WindowShouldClose:(MainWindowController*)sender
{
    if (m_OperationsController.OperationsCount == 0 &&
        !self.isAnythingRunningInOverlappedTerminal )
        return true;
    
    Alert *dialog = [[Alert alloc] init];
    [dialog addButtonWithTitle:NSLocalizedString(@"Stop and Close", "User action to stop running actions and close window")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    dialog.messageText = NSLocalizedString(@"The window has running operations. Do you want to stop them and close the window?", "Asking user to close window with some operations running");
    [dialog beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSAlertFirstButtonReturn) {
            [m_OperationsController Stop];
            [self.window close];
        }
    }];
    
    return false;
}

- (void)revealEntries:(const vector<string>&)_filenames inDirectory:(const string&)_path
{
    assert( dispatch_is_main_queue() );
    auto data = self.activePanelData;
    if(!data)
        return;
    
    auto panel = self.activePanelController;
    if(!panel)
        return;
    
    if( [panel GoToDir:_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok ) {
        if( !_filenames.empty() ) {
            PanelControllerDelayedSelection req;
            req.filename = _filenames.front();
            [panel ScheduleDelayedSelectionChangeFor:req];
        }
        
        if( _filenames.size() > 1 )
            for(auto &i: _filenames)
                data->CustomFlagsSelectSorted( data->SortedIndexForName(i.c_str()), true );
        
        [self.activePanelView setNeedsDisplay];
    }
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
    if( m_MainSplitView.anyCollapsed )
        return nil;

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
    if( m_MainSplitView.anyCollapsed )
        return nil;
        
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

- (void)onShowTabsSettingChanged
{
    bool show = GlobalConfig().GetBool(g_ConfigGeneralShowTabs);
    if( show != m_ShowTabs )
        dispatch_to_main_queue_after(1ms, [=]{
            m_ShowTabs = show;
            [self updateTabBarsVisibility];
        });
}

- (void)updateBottomConstraint
{
    auto gap = [m_OverlappedTerminal->terminal bottomGapForLines:m_OverlappedTerminal->bottom_gap];
    m_MainSplitViewBottomConstraint.constant = -gap;
}

- (void)frameDidChange
{
//    [self layoutSubtreeIfNeeded];
    [self updateBottomConstraint];
}

- (bool)isPanelsSplitViewHidden
{
    return m_MainSplitView.hidden;
}

- (bool) anyPanelCollapsed
{
    return m_MainSplitView.anyCollapsed;
}

- (void)requestTerminalExecution:(const string&)_filename at:(const string&)_cwd
{
    if( ![self executeInOverlappedTerminalIfPossible:_filename at:_cwd] ) {
        const auto ctrl = (MainWindowController*)self.window.delegate;
        [ctrl requestTerminalExecution:_filename.c_str()
                                    at:_cwd.c_str()];
    }
}

- (void)addNewControllerOnLeftPane:(PanelController*)_pc
{
    m_LeftPanelControllers.emplace_back(_pc);
    [m_MainSplitView.leftTabbedHolder addPanel:_pc.view];
}

- (void)addNewControllerOnRightPane:(PanelController*)_pc
{
    m_RightPanelControllers.emplace_back(_pc);
    [m_MainSplitView.rightTabbedHolder addPanel:_pc.view];
}

- (ExternalToolsStorage&)externalToolsStorage
{
    return AppDelegate.me.externalTools;
}

@end
