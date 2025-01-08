// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowFilePanelState.h"
#include "StateActionsDispatcher.h"
#include <Utility/ActionsShortcutsManager.h>
#include "MainWindowFilePanelsStateToolbarDelegate.h"
#include <Operations/PoolViewController.h>
#include "Actions/ExecuteExternalTool.h"
#include <NimbleCommander/Core/AnyHolder.h>
#include <Panel/ExternalTools.h>
#include <Base/dispatch_cpp.h>
#include <Base/WhereIs.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <deque>
#include <algorithm>
#include <fmt/format.h>

using nc::panel::ExternalTool;

// do not change these strings, they are used for persistency in NSUserDefaults
static auto g_ToolbarIdentifier = @"FilePanelsToolbar";
static std::string_view g_ExternalToolsIdentifiersPrefix = "external_tool_";

@implementation MainWindowFilePanelsStateToolbarDelegate {
    NSToolbar *m_Toolbar;
    NSButton *m_LeftPanelGoToButton;
    NSButton *m_RightPanelGoToButton;

    NCOpsPoolViewController *m_PoolViewController;
    NSToolbarItem *m_PoolViewToolbarItem;

    NSArray *m_AllowedToolbarItemsIdentifiers;
    nc::panel::ExternalToolsStorage *m_Storage;
    nc::panel::ExternalToolsStorage::ObservationTicket m_ToolsChangesTicket;
    const nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;

    id m_RepresentedObject;
}

@synthesize toolbar = m_Toolbar;
@synthesize leftPanelGoToButton = m_LeftPanelGoToButton;
@synthesize rightPanelGoToButton = m_RightPanelGoToButton;
@synthesize operationsPoolViewController = m_PoolViewController;

- (instancetype)initWithToolsStorage:(nc::panel::ExternalToolsStorage &)_storage
             actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager
                   andOperationsPool:(nc::ops::Pool &)_pool
{
    self = [super init];
    if( self ) {
        m_Storage = &_storage;
        m_ActionsShortcutsManager = &_actions_shortcuts_manager;

        [self buildBasicControls];
        [self buildToolbar];
        [self buildAllowedIdentifiers];

        __weak MainWindowFilePanelsStateToolbarDelegate *weak_self = self;
        m_ToolsChangesTicket = m_Storage->ObserveChanges([=] {
            dispatch_to_main_queue(
                [=] { [static_cast<MainWindowFilePanelsStateToolbarDelegate *>(weak_self) externalToolsChanged]; });
        });

        m_PoolViewController = [[NCOpsPoolViewController alloc] initWithPool:_pool];
        [m_PoolViewController loadView];
    }
    return self;
}

- (void)buildBasicControls
{
    m_LeftPanelGoToButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 42, 27)];
    m_LeftPanelGoToButton.bezelStyle = NSBezelStyleTexturedRounded;
    m_LeftPanelGoToButton.refusesFirstResponder = true;
    m_LeftPanelGoToButton.title = @"";
    m_LeftPanelGoToButton.image = [NSImage imageNamed:NSImageNamePathTemplate];
    m_LeftPanelGoToButton.target = nil;
    m_LeftPanelGoToButton.action = @selector(onLeftPanelGoToButtonAction:);

    m_RightPanelGoToButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 42, 27)];
    m_RightPanelGoToButton.bezelStyle = NSBezelStyleTexturedRounded;
    m_RightPanelGoToButton.refusesFirstResponder = true;
    m_RightPanelGoToButton.title = @"";
    m_RightPanelGoToButton.image = [NSImage imageNamed:NSImageNamePathTemplate];
    m_RightPanelGoToButton.target = nil;
    m_RightPanelGoToButton.action = @selector(onRightPanelGoToButtonAction:);
}

- (void)buildToolbar
{
    m_Toolbar = [[NSToolbar alloc] initWithIdentifier:g_ToolbarIdentifier];
    m_Toolbar.delegate = self;
    m_Toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    m_Toolbar.allowsUserCustomization = true;
    m_Toolbar.autosavesConfiguration = true;
    m_Toolbar.showsBaselineSeparator = false;
}

static NSImage *MakeBackupToolImage()
{
    const auto path = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/"
                      @"GenericQuestionMarkIcon.icns";
    auto image = [[NSImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path isDirectory:false]];
    if( !image )
        return nil;
    image.size = NSMakeSize(24, 24);
    return image;
}

static NSImage *ImageForTool(const nc::panel::ExternalTool &_et)
{
    std::filesystem::path tool_path = _et.m_ExecutablePath;
    if( !std::filesystem::exists(tool_path) ) {
        // presumably this is a short name of a CLI tool, i.e. 'zip'. let's resolve it
        const auto paths = nc::base::WhereIs(_et.m_ExecutablePath);
        if( paths.empty() )
            return MakeBackupToolImage(); // sorry, can't find, give up
        tool_path = paths.front();
    }

    NSURL *const exec_url = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8StdString:tool_path.native()]];
    if( !exec_url )
        return MakeBackupToolImage();

    NSImage *img;
    [exec_url getResourceValue:&img forKey:NSURLEffectiveIconKey error:nil];
    if( !img )
        return MakeBackupToolImage();

    img.size = NSMakeSize(24, 24);
    return img;
}

static NSString *EncodeToolIdentifier(const ExternalTool &_et)
{
    const std::string identifier = fmt::format("{}{}", g_ExternalToolsIdentifiersPrefix, _et.m_UUID.ToString());
    return [NSString stringWithUTF8StdString:identifier];
}

- (std::shared_ptr<const ExternalTool>)findToolWithIdentifier:(NSString *)_identifier
{
    std::string_view identifier = _identifier.UTF8String;
    if( identifier.starts_with(g_ExternalToolsIdentifiersPrefix) ) {
        identifier.remove_prefix(g_ExternalToolsIdentifiersPrefix.length());
        if( const auto uuid = nc::base::UUID::FromString(identifier) ) {
            return m_Storage->GetTool(uuid.value());
        }
    }
    return nullptr;
}

- (void)setupExternalToolItem:(NSToolbarItem *)_item forTool:(const nc::panel::ExternalTool &)_et
{
    const auto title = [NSString stringWithUTF8StdString:_et.m_Title];
    _item.image = ImageForTool(_et);
    _item.label = title;
    _item.paletteLabel = title;
    _item.target = self;
    _item.action = @selector(onExternalToolAction:);
    _item.toolTip = [&] {
        const auto hotkey = _et.m_Shorcut.PrettyString();
        if( hotkey.length == 0 )
            return title;
        else
            return [NSString stringWithFormat:@"%@ (%@)", title, hotkey];
    }();
}

- (NSToolbarItem *)toolbar:(NSToolbar *) [[maybe_unused]] _toolbar
        itemForItemIdentifier:(NSString *)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL) [[maybe_unused]] _flag
{
    if( [itemIdentifier isEqualToString:@"filepanels_left_goto_button"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_LeftPanelGoToButton;
        item.paletteLabel = item.label = NSLocalizedString(@"Left GoTo", "Toolbar palette");
        auto shortcuts = m_ActionsShortcutsManager->ShortcutsFromAction("menu.go.left_panel").value();
        item.toolTip = shortcuts.empty() ? @"" : shortcuts.front().PrettyString();
        return item;
    }
    if( [itemIdentifier isEqualToString:@"filepanels_right_goto_button"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelGoToButton;
        item.paletteLabel = item.label = NSLocalizedString(@"Right GoTo", "Toolbar palette");
        auto shortcuts = m_ActionsShortcutsManager->ShortcutsFromAction("menu.go.right_panel").value();
        item.toolTip = shortcuts.empty() ? @"" : shortcuts.front().PrettyString();
        return item;
    }
    if( [itemIdentifier isEqualToString:@"operations_pool"] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_PoolViewController.view;
        item.paletteLabel = item.label = NSLocalizedString(@"Operations", "Toolbar palette");
        m_PoolViewToolbarItem = item;
        return item;
    }
    if( const auto tool = [self findToolWithIdentifier:itemIdentifier] ) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        [self setupExternalToolItem:item forTool:*tool];
        return item;
    }

    return nil;
}

- (id)representedObject
{
    return m_RepresentedObject;
}

- (IBAction)onExternalToolAction:(id)sender
{
    if( auto i = nc::objc_cast<NSToolbarItem>(sender) )
        if( auto tool = [self findToolWithIdentifier:i.itemIdentifier] ) {
            m_RepresentedObject = [[AnyHolder alloc] initWithAny:std::any{tool}];
            [NSApp sendAction:@selector(onExecuteExternalTool:) to:nil from:self];
            m_RepresentedObject = nil;
        }
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *) [[maybe_unused]] _toolbar
{
    static NSArray *allowed_items = @[
        @"filepanels_left_goto_button",
        NSToolbarFlexibleSpaceItemIdentifier,
        @"operations_pool",
        NSToolbarFlexibleSpaceItemIdentifier,
        @"filepanels_right_goto_button"
    ];

    return allowed_items;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *) [[maybe_unused]] _toolbar
{
    return m_AllowedToolbarItemsIdentifiers;
}

- (void)buildAllowedIdentifiers
{
    // this is a bit redundant, since we're building this list for _every_ window, and this list is
    // the same for them
    NSMutableArray *a = [[NSMutableArray alloc] init];
    [a addObject:@"filepanels_left_goto_button"];
    [a addObject:@"filepanels_right_goto_button"];
    [a addObject:@"operations_pool"];

    const std::vector<std::shared_ptr<const ExternalTool>> tools = m_Storage->GetAllTools();
    for( const auto &tool : tools ) {
        [a addObject:EncodeToolIdentifier(*tool)];
    }

    [a addObject:NSToolbarFlexibleSpaceItemIdentifier];
    [a addObject:NSToolbarSpaceItemIdentifier];

    m_AllowedToolbarItemsIdentifiers = a;
}

- (void)externalToolsChanged
{
    dispatch_assert_main_queue();
    std::vector<int> to_remove;
    for( NSToolbarItem *i in m_Toolbar.items ) {
        //        if( [i.itemIdentifier hasPrefix:g_ExternalToolsIdentifiersPrefix] ) {
        if( std::string_view(i.itemIdentifier.UTF8String).starts_with(g_ExternalToolsIdentifiersPrefix) ) {
            //            const int n = atoi(i.itemIdentifier.UTF8String + g_ExternalToolsIdentifiersPrefix.length);
            if( const auto tool = [self findToolWithIdentifier:i.itemIdentifier] ) {
                [self setupExternalToolItem:i forTool:*tool];
            }
            else
                to_remove.push_back(static_cast<int>([m_Toolbar.items indexOfObject:i]));
        }
    }

    // this will immediately trigger removing of same elements from other windows' toolbars.
    // this is intended and should work fine.
    std::ranges::reverse(to_remove);
    for( auto i : to_remove )
        [m_Toolbar removeItemAtIndex:i];

    [self buildAllowedIdentifiers];
}

@end
