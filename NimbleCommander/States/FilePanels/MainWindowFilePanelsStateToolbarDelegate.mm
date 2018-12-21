// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowFilePanelState.h"
#include "StateActionsDispatcher.h"
#include "../../Core/ActionsShortcutsManager.h"
#include "MainWindowFilePanelsStateToolbarDelegate.h"
#include "StateActionsDispatcher.h"
#include <Operations/PoolViewController.h>
#include "Actions/ExecuteExternalTool.h"
#include <NimbleCommander/Core/AnyHolder.h>
#include "ExternalToolsSupport.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

// do not change these strings, they are used for persistency in NSUserDefaults
static auto g_ToolbarIdentifier = @"FilePanelsToolbar";
static auto g_ExternalToolsIdentifiersPrefix = @"external_tool_";
static const auto g_MaxPoolViewWith = 540.;

@interface MainWindowFilePanelsStateToolbarDelegate()

@property (nonatomic, readonly) MainWindowFilePanelState* state;

@end

@implementation MainWindowFilePanelsStateToolbarDelegate
{
    __weak MainWindowFilePanelState *m_State;
    NSToolbar                       *m_Toolbar;
    NSButton                        *m_LeftPanelGoToButton;
    NSButton                        *m_RightPanelGoToButton;

    NCOpsPoolViewController         *m_PoolViewController;
    NSToolbarItem                   *m_PoolViewToolbarItem;
    
    NSArray                         *m_AllowedToolbarItemsIdentifiers;
    ExternalToolsStorage::ObservationTicket m_ToolsChangesTicket;
    
    bool m_SetUpWindowSizeObservation;
    
    id                              m_RepresentedObject;
}

@synthesize toolbar = m_Toolbar;
@synthesize leftPanelGoToButton = m_LeftPanelGoToButton;
@synthesize rightPanelGoToButton = m_RightPanelGoToButton;
@synthesize operationsPoolViewController = m_PoolViewController;

- (instancetype) initWithFilePanelsState:(MainWindowFilePanelState*)_state
{
    assert(_state != nil);
    self = [super init];
    if( self ) {
        m_SetUpWindowSizeObservation = false;
        m_State = _state;
        
        [self buildBasicControls];
        [self buildToolbar];
        [self buildAllowedIdentifiers];
        
        __weak MainWindowFilePanelsStateToolbarDelegate* weak_self = self;
        m_ToolsChangesTicket = _state.externalToolsStorage.ObserveChanges([=]{
            dispatch_to_main_queue([=]{
                [(MainWindowFilePanelsStateToolbarDelegate*)weak_self externalToolsChanged];
            });
        });
        
        m_PoolViewController = [[NCOpsPoolViewController alloc] initWithPool:
                                self.state.operationsPool];
        [m_PoolViewController loadView];
    }
    return self;
}

- (MainWindowFilePanelState*) state
{
    return (MainWindowFilePanelState*)m_State;
}

- (void) buildBasicControls
{
    m_LeftPanelGoToButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 42, 27)];
    m_LeftPanelGoToButton.bezelStyle = NSTexturedRoundedBezelStyle;
    m_LeftPanelGoToButton.refusesFirstResponder = true;
    m_LeftPanelGoToButton.title = @"";
    m_LeftPanelGoToButton.image = [NSImage imageNamed:NSImageNamePathTemplate];
    m_LeftPanelGoToButton.target = nil;
    m_LeftPanelGoToButton.action = @selector(onLeftPanelGoToButtonAction:);
    
    m_RightPanelGoToButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 42, 27)];
    m_RightPanelGoToButton.bezelStyle = NSTexturedRoundedBezelStyle;
    m_RightPanelGoToButton.refusesFirstResponder = true;
    m_RightPanelGoToButton.title = @"";
    m_RightPanelGoToButton.image = [NSImage imageNamed:NSImageNamePathTemplate];    
    m_RightPanelGoToButton.target = nil;
    m_RightPanelGoToButton.action = @selector(onRightPanelGoToButtonAction:);
}

- (void) buildToolbar
{
    m_Toolbar = [[NSToolbar alloc] initWithIdentifier:g_ToolbarIdentifier];
    m_Toolbar.delegate = self;
    m_Toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    m_Toolbar.allowsUserCustomization = true;
    m_Toolbar.autosavesConfiguration = true;
    m_Toolbar.showsBaselineSeparator = false;
}

static NSImage *ImageForTool( const ExternalTool &_et)
{
    NSURL *exec_url = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8StdString:_et.m_ExecutablePath]];
    if( !exec_url )
        return nil;
    
    NSImage *img;
    [exec_url getResourceValue:&img forKey:NSURLEffectiveIconKey error:nil];
    if( !img )
        return nil;
        
    img.size = NSMakeSize(24, 24);
    return img;
}

- (void)setupExternalToolItem:(NSToolbarItem*)_item forTool:(const ExternalTool&)_et no:(int)_no
{
    _item.image = ImageForTool(_et);
    _item.label = [NSString stringWithUTF8StdString:_et.m_Title];
    _item.paletteLabel = _item.label;
    _item.target = self;
    _item.action = @selector(onExternalToolAction:);
    _item.tag = _no;
    _item.toolTip = _et.m_Shorcut.PrettyString();
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    if( [itemIdentifier isEqualToString:@"filepanels_left_goto_button"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_LeftPanelGoToButton;
        item.paletteLabel = item.label = NSLocalizedString(@"Left GoTo", "Toolbar palette");
        item.toolTip = ActionsShortcutsManager::Instance().ShortCutFromAction("menu.go.left_panel").PrettyString();
        return item;
    }
    if( [itemIdentifier isEqualToString:@"filepanels_right_goto_button"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelGoToButton;
        item.paletteLabel = item.label = NSLocalizedString(@"Right GoTo", "Toolbar palette");
        item.toolTip = ActionsShortcutsManager::Instance().ShortCutFromAction("menu.go.right_panel").PrettyString();
        return item;
    }
    if( [itemIdentifier isEqualToString:@"operations_pool"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_PoolViewController.view;
        item.minSize = m_PoolViewController.view.bounds.size;
        item.maxSize = NSMakeSize(g_MaxPoolViewWith, item.minSize.height);
        item.paletteLabel = item.label = NSLocalizedString(@"Operations", "Toolbar palette");
        m_PoolViewToolbarItem = item;
        return item;
    }
    if( [itemIdentifier hasPrefix:g_ExternalToolsIdentifiersPrefix] ) {
        const int n = atoi( itemIdentifier.UTF8String + g_ExternalToolsIdentifiersPrefix.length );
        if( const auto tool = self.state.externalToolsStorage.GetTool(n) ) {
            NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
            [self setupExternalToolItem:item forTool:*tool no:n];
            return item;
        }
    }
    
    
    
    return nil;
}

- (void) notifyStateWasAssigned
{
    if( !m_SetUpWindowSizeObservation ) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowDidResize)
                                                   name:NSWindowDidResizeNotification
                                                 object:m_State.window];
        m_SetUpWindowSizeObservation = true;
        [self windowDidResize];
    }
}

- (void)windowDidResize
{
    if( !m_PoolViewToolbarItem )
        return;
    
    if( const auto wnd = m_PoolViewController.view.window ) {
        const auto sz = m_PoolViewController.view.window.frame.size;
        const auto max_width = std::min(sz.width / 2.4, g_MaxPoolViewWith);
        const auto clipped_max_wdith = std::max(m_PoolViewToolbarItem.minSize.width, max_width);
        m_PoolViewToolbarItem.maxSize = NSMakeSize(clipped_max_wdith,
                                                   m_PoolViewToolbarItem.maxSize.height );
    }
}

- (id)representedObject
{
    return m_RepresentedObject;
}

- (IBAction)onExternalToolAction:(id)sender
{
    if( auto i = objc_cast<NSToolbarItem>(sender) )
        if( auto tool = self.state.externalToolsStorage.GetTool(i.tag) ) {
            m_RepresentedObject = [[AnyHolder alloc] initWithAny:std::any{tool}];
            [NSApp sendAction:@selector(onExecuteExternalTool:) to:nil from:self];
            m_RepresentedObject = nil;
        }
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    static NSArray *allowed_items =
    @[ @"filepanels_left_goto_button",
       NSToolbarFlexibleSpaceItemIdentifier,
       @"operations_pool",
       NSToolbarFlexibleSpaceItemIdentifier,
       @"filepanels_right_goto_button"];
    
    return allowed_items;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return m_AllowedToolbarItemsIdentifiers;
}

-(void) buildAllowedIdentifiers
{
    // this is a bit redundant, since we're building this list for _every_ window, and this list is the same for them
    NSMutableArray *a = [[NSMutableArray alloc] init];
    [a addObject:@"filepanels_left_goto_button"];
    [a addObject:@"filepanels_right_goto_button"];
    [a addObject:@"operations_pool"];
    
    auto tools = m_State.externalToolsStorage.GetAllTools();
    for( int i = 0, e = (int)tools.size(); i != e; ++i )
        [a addObject:[NSString stringWithFormat:@"%@%d", g_ExternalToolsIdentifiersPrefix, i] ];
    
    [a addObject:NSToolbarFlexibleSpaceItemIdentifier];
    [a addObject:NSToolbarSpaceItemIdentifier];
    
    m_AllowedToolbarItemsIdentifiers = a;
}

- (void) externalToolsChanged
{
    dispatch_assert_main_queue();
    std::deque<int> to_remove;
    for( NSToolbarItem *i in m_Toolbar.items ) {
        if( [i.itemIdentifier hasPrefix:g_ExternalToolsIdentifiersPrefix] ) {
            const int n = atoi( i.itemIdentifier.UTF8String + g_ExternalToolsIdentifiersPrefix.length );
            if( const auto tool = self.state.externalToolsStorage.GetTool(n) ) {
                [self setupExternalToolItem:i forTool:*tool no:n];
            }
            else
                to_remove.push_front( (int)[m_Toolbar.items indexOfObject:i] );
        }
    }

    // this will immediately trigger removing of same elements from other windows' toolbars.
    // this is intended and should work fine.
    for( auto i: to_remove )
        [m_Toolbar removeItemAtIndex:i];
    
    [self buildAllowedIdentifiers];
}

@end
