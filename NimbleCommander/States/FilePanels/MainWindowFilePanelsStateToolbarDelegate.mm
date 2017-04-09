#include "MainWindowFilePanelState.h"
#include <NimbleCommander/Operations/OperationsSummaryViewController.h>
#include "Views/MainWndGoToButton.h"
#include "../../Core/ActionsShortcutsManager.h"
#include "MainWindowFilePanelsStateToolbarDelegate.h"

// do not change these strings, they are used for persistency in NSUserDefaults
static auto g_ToolbarIdentifier = @"FilePanelsToolbar";
static auto g_ExternalToolsIdentifiersPrefix = @"external_tool_";

@interface MainWindowFilePanelsStateToolbarDelegate()

@property (nonatomic, readonly) MainWindowFilePanelState* state;

@end

@implementation MainWindowFilePanelsStateToolbarDelegate
{
    __weak MainWindowFilePanelState *m_State;
    NSToolbar                       *m_Toolbar;
    
    MainWndGoToButton               *m_LeftPanelGoToButton;
    NSProgressIndicator             *m_LeftPanelSpinningIndicator;
    
    MainWndGoToButton               *m_RightPanelGoToButton;
    NSProgressIndicator             *m_RightPanelSpinningIndicator;
    
    NSArray                         *m_AllowedToolbarItemsIdentifiers;
    
    ExternalToolsStorage::ObservationTicket m_ToolsChangesTicket;
}

@synthesize toolbar = m_Toolbar;
@synthesize leftPanelGoToButton = m_LeftPanelGoToButton;
@synthesize leftPanelSpinningIndicator = m_LeftPanelSpinningIndicator;
@synthesize rightPanelGoToButton = m_RightPanelGoToButton;
@synthesize rightPanelSpinningIndicator = m_RightPanelSpinningIndicator;

- (instancetype) initWithFilePanelsState:(MainWindowFilePanelState*)_state
{
    assert(_state != nil);
    self = [super init];
    if( self ) {
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
    }
    return self;
}

- (MainWindowFilePanelState*) state
{
    return (MainWindowFilePanelState*)m_State;
}

- (void) buildBasicControls
{
    MainWindowFilePanelState* state = m_State;
    m_LeftPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 42, 27)];
    m_LeftPanelGoToButton.target = state;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
    m_LeftPanelGoToButton.action = @selector(onLeftPanelGoToButtonAction:);
#pragma clang diagnostic pop
    m_LeftPanelGoToButton.owner = state;
    m_LeftPanelGoToButton.isRight = false;

    m_RightPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 42, 27)];
    m_RightPanelGoToButton.target = state;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
    m_RightPanelGoToButton.action = @selector(onRightPanelGoToButtonAction:);
#pragma clang diagnostic pop    
    m_RightPanelGoToButton.owner = state;
    m_RightPanelGoToButton.isRight = true;

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
        item.paletteLabel = item.label = @"Left GoTo";
        item.toolTip = ActionsShortcutsManager::Instance().ShortCutFromAction("menu.view.left_panel_change_folder").PrettyString();
        return item;
    }
    if( [itemIdentifier isEqualToString:@"filepanels_right_goto_button"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelGoToButton;
        item.paletteLabel = item.label = @"Right GoTo";
        item.toolTip = ActionsShortcutsManager::Instance().ShortCutFromAction("menu.view.right_panel_change_folder").PrettyString();
        return item;
    }
    if( [itemIdentifier isEqualToString:@"filepanels_left_spinning_indicator"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_LeftPanelSpinningIndicator;
        item.paletteLabel = item.label = @"Left Activity";
        return item;
    }
    if( [itemIdentifier isEqualToString:@"filepanels_right_spinning_indicator"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelSpinningIndicator;
        item.paletteLabel = item.label = @"Right Activity";
        return item;
    }
    if( [itemIdentifier isEqualToString:@"filepanels_operations_box"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = self.state.operationsSummaryView.view;
        item.paletteLabel = item.label = @"Operations";
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

- (IBAction)onExternalToolAction:(id)sender
{
    if( auto i = objc_cast<NSToolbarItem>(sender) )
        if( auto tool = self.state.externalToolsStorage.GetTool(i.tag) )
            [self.state runExtTool:tool];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    static NSArray *allowed_items =
    @[ @"filepanels_left_goto_button",
       @"filepanels_left_spinning_indicator",
       NSToolbarFlexibleSpaceItemIdentifier,
       @"filepanels_operations_box",
       NSToolbarFlexibleSpaceItemIdentifier,
       @"filepanels_right_spinning_indicator",
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
    [a addObject:@"filepanels_left_spinning_indicator"];
    [a addObject:@"filepanels_right_spinning_indicator"];
    [a addObject:@"filepanels_operations_box"];
    
    auto tools = m_State.externalToolsStorage.GetAllTools();
    for( int i = 0; i < tools.size(); ++i )
        [a addObject:[NSString stringWithFormat:@"%@%d", g_ExternalToolsIdentifiersPrefix, i] ];
    
    [a addObject:NSToolbarFlexibleSpaceItemIdentifier];
    [a addObject:NSToolbarSpaceItemIdentifier];
    
    m_AllowedToolbarItemsIdentifiers = a;
}

- (void) externalToolsChanged
{
    dispatch_assert_main_queue();
    deque<int> to_remove;
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
