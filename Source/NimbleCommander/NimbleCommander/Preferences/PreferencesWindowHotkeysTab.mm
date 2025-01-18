// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowHotkeysTab.h"
#include <Utility/ActionsShortcutsManager.h>
#include <Base/debug.h>
#include <Base/dispatch_cpp.h>
#import <GTMHotKeyTextField/GTMHotKeyTextField.h>
#include <Panel/ExternalTools.h>
#include <Utility/FunctionKeysPass.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/NSMenu+ActionsShortcutsManager.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <algorithm>
#include <numeric>
#include <ranges>
#include <any>

using nc::panel::ExternalTool;
using nc::utility::ActionShortcut;
using nc::utility::ActionsShortcutsManager;

static NSString *ComposeVerboseMenuItemTitle(NSMenuItem *_item);
static NSString *ComposeVerboseNonMenuActionTitle(const std::string &_action);
static NSString *ComposeExternalToolTitle(const ExternalTool &_et, unsigned _index);
static NSString *LabelTitleForAction(const std::string &_action, NSMenuItem *_item_for_tag);

namespace {

struct ActionShortcutNode {
    std::pair<std::string, int> tag;
    ActionsShortcutsManager::Shortcuts current_shortcuts;
    ActionsShortcutsManager::Shortcuts default_shortcuts;
    NSString *label = @"";
    bool is_menu_action = false;
    bool has_submenu = false;
    bool is_customized = false;
    bool participates_in_conflicts = true;
    bool is_conflicted = false;
};

struct ToolShortcutNode {
    std::shared_ptr<const ExternalTool> tool;
    NSString *label;
    int tool_index;
    bool is_customized;
    bool is_conflicted;
};

enum class SourceType : uint8_t {
    All,
    Customized,
    Conflicts
};

} // namespace

@interface PreferencesWindowHotkeysTab ()

@property(nonatomic) IBOutlet NSTableView *Table;
@property(nonatomic) IBOutlet NSButton *forceFnButton;
@property(nonatomic) IBOutlet NSTextField *filterTextField;
@property(nonatomic) IBOutlet NSButton *sourceAllButton;
@property(nonatomic) IBOutlet NSButton *sourceCustomizedButton;
@property(nonatomic) IBOutlet NSButton *sourceConflictsButton;
@property(nonatomic) IBOutlet NSTableColumn *firstShortcutColumn;
@property(nonatomic) IBOutlet NSTableColumn *secondShortcutColumn;
@property(nonatomic) IBOutlet NSTableColumn *thirdShortcutColumn;
@property(nonatomic) IBOutlet NSTableColumn *fourthShortcutColumn;

@property(nonatomic) SourceType sourceType;

@end

@implementation PreferencesWindowHotkeysTab {
    std::vector<std::pair<std::string, int>> m_Shortcuts;
    std::function<nc::panel::ExternalToolsStorage &()> m_ToolsStorage;
    nc::panel::ExternalToolsStorage::ObservationTicket m_ToolsObserver;
    std::vector<std::shared_ptr<const ExternalTool>> m_Tools;
    std::vector<std::any> m_AllNodes;
    std::vector<std::any> m_SourceNodes;
    std::vector<std::any> m_FilteredNodes;
    SourceType m_SourceType;
    nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;
}

@synthesize sourceType = m_SourceType;
@synthesize Table;
@synthesize forceFnButton;
@synthesize filterTextField;
@synthesize sourceAllButton;
@synthesize sourceCustomizedButton;
@synthesize sourceConflictsButton;
@synthesize firstShortcutColumn;
@synthesize secondShortcutColumn;
@synthesize thirdShortcutColumn;
@synthesize fourthShortcutColumn;

- (id)initWithToolsStorage:(std::function<nc::panel::ExternalToolsStorage &()>)_tool_storage
    actionsShortcutsManager:(nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager
{
    self = [super init];
    if( self ) {
        m_SourceType = SourceType::All;
        m_ToolsStorage = _tool_storage;
        m_ActionsShortcutsManager = &_actions_shortcuts_manager;
        m_Shortcuts = m_ActionsShortcutsManager->AllShortcuts();

        // remove shortcuts whichs are absent in main menu
        const auto absent = [](auto &_t) {
            if( _t.first.find_first_of("menu.") != 0 )
                return false;
            const auto menu_item = [NSApp.mainMenu itemWithTagHierarchical:_t.second];
            return menu_item == nil || menu_item.isHidden;
        };
        std::erase_if(m_Shortcuts, absent);
    }
    return self;
}

- (void)rebuildAll
{
    [self buildData];
    [self buildSourceNodes];
    [self buildFilteredNodes];
    [self.Table reloadData];
}

// At this moment Viewer's hotkey mechanism completely bypasses the normal Cocoa menu-driven
// hotkeys system and does manual hotkeys processing. This allows having the same hotkeys as
// used for many Panel actions, but legally speaking these actions are unaccessible (grayed) and
// should beep instead.
static bool ParticipatesInConflicts(const std::string &_action_name)
{
    // Only actions starting with "viewer." should not participate in conflicts resolution.
    return _action_name.find_first_of("viewer.") != 0;
}

- (void)buildData
{
    m_AllNodes.clear();
    ankerl::unordered_dense::map<nc::utility::ActionShortcut, int> counts;
    for( auto &v : m_Shortcuts ) {
        if( v.first == "menu.file.open_with_submenu" || v.first == "menu.file.always_open_with_submenu" ) {
            // Skip the menu items that are actually placeholders for submenus as shortcuts don't work for them.
            // At least for now.
            continue;
        }

        const auto menu_item = [NSApp.mainMenu itemWithTagHierarchical:v.second];

        ActionShortcutNode shortcut;
        shortcut.tag = v;
        shortcut.label = LabelTitleForAction(v.first, menu_item);
        shortcut.current_shortcuts = m_ActionsShortcutsManager->ShortcutsFromTag(v.second).value();
        shortcut.default_shortcuts = m_ActionsShortcutsManager->DefaultShortcutsFromTag(v.second).value();
        shortcut.is_menu_action = v.first.find_first_of("menu.") == 0;
        shortcut.is_customized = shortcut.current_shortcuts != shortcut.default_shortcuts;
        shortcut.has_submenu = menu_item != nil && menu_item.hasSubmenu;
        shortcut.participates_in_conflicts = ParticipatesInConflicts(v.first);
        if( shortcut.participates_in_conflicts ) {
            for( auto &sc : shortcut.current_shortcuts )
                counts[sc]++;
        }

        m_AllNodes.emplace_back(std::move(shortcut));
    }
    for( int i = 0, e = static_cast<int>(m_Tools.size()); i != e; ++i ) {
        const auto &v = m_Tools[i];
        ToolShortcutNode shortcut;
        shortcut.tool = v;
        shortcut.tool_index = i;
        shortcut.label = ComposeExternalToolTitle(*v, i);
        shortcut.is_customized = bool(v->m_Shorcut);
        m_AllNodes.emplace_back(std::move(shortcut));
        counts[v->m_Shorcut]++;
    }

    int conflicts_amount = 0;
    for( auto &v : m_AllNodes ) {
        if( auto node = std::any_cast<ActionShortcutNode>(&v) ) {
            if( !node->participates_in_conflicts )
                continue;
            node->is_conflicted =
                std::ranges::any_of(node->current_shortcuts, [&](auto &_sc) { return counts[_sc] > 1; });
            if( node->is_conflicted )
                conflicts_amount++;
        }
        if( auto node = std::any_cast<ToolShortcutNode>(&v) ) {
            node->is_conflicted = node->tool->m_Shorcut && counts[node->tool->m_Shorcut] > 1;
            if( node->is_conflicted )
                conflicts_amount++;
        }
    }

    if( conflicts_amount ) {
        auto fmt = NSLocalizedString(@"Conflicts (%@)", "");
        self.sourceConflictsButton.title = [NSString stringWithFormat:fmt, [NSNumber numberWithInt:conflicts_amount]];
    }
    else {
        self.sourceConflictsButton.title = self.sourceConflictsButton.alternateTitle;
    }
}

- (void)buildSourceNodes
{
    if( m_SourceType == SourceType::All ) {
        m_SourceNodes = m_AllNodes;
    }
    if( m_SourceType == SourceType::Customized ) {
        m_SourceNodes.clear();
        for( auto &v : m_AllNodes ) {
            if( auto node = std::any_cast<ActionShortcutNode>(&v) )
                if( node->is_customized )
                    m_SourceNodes.emplace_back(v);
            if( auto node = std::any_cast<ToolShortcutNode>(&v) )
                if( node->is_customized )
                    m_SourceNodes.emplace_back(v);
        }
    }
    if( m_SourceType == SourceType::Conflicts ) {
        m_SourceNodes.clear();
        for( auto &v : m_AllNodes ) {
            if( auto node = std::any_cast<ActionShortcutNode>(&v) )
                if( node->is_conflicted )
                    m_SourceNodes.emplace_back(v);
            if( auto node = std::any_cast<ToolShortcutNode>(&v) )
                if( node->is_conflicted )
                    m_SourceNodes.emplace_back(v);
        }
    }
}

- (void)loadView
{
    [super loadView];
    m_Tools = m_ToolsStorage().GetAllTools();

    if( nc::base::AmISandboxed() )
        self.forceFnButton.hidden = true;

    m_ToolsObserver = m_ToolsStorage().ObserveChanges([=] {
        dispatch_to_main_queue([=] {
            m_Tools = m_ToolsStorage().GetAllTools();
            [self rebuildAll];
        });
    });

    [self buildData];
    m_SourceNodes = m_FilteredNodes = m_AllNodes;
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"preferences.toolbar.hotkeys"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Hotkeys", @"Preferences", "General preferences tab title");
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *) [[maybe_unused]] tableView
{
    return m_FilteredNodes.size();
}

- (GTMHotKeyTextField *)makeDefaultGTMHotKeyTextField
{
    auto text_field = [[GTMHotKeyTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    text_field.drawsBackground = false;
    text_field.bordered = false;
    text_field.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeRegular]];
    [text_field.cell setSendsActionOnEndEditing:true];
    text_field.editable = true;
    text_field.allowsEditingTextAttributes = false;
    text_field.alignment = NSTextAlignmentNatural;
    text_field.lineBreakMode = NSLineBreakByClipping;
    text_field.enabled = true;
    return text_field;
}

static NSTextField *SpawnLabelForAction(const ActionShortcutNode &_action)
{
    const auto tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.toolTip = [NSString stringWithUTF8StdString:_action.tag.first];
    tf.stringValue = _action.label;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    return tf;
}

static NSTextField *SpawnLabelForTool(const ToolShortcutNode &_node)
{
    const auto text_field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    text_field.toolTip = [NSString stringWithUTF8StdString:_node.tool->m_ExecutablePath];
    text_field.stringValue = _node.label;
    text_field.bordered = false;
    text_field.editable = false;
    text_field.drawsBackground = false;
    return text_field;
}

static NSImageView *SpawnCautionSign()
{
    auto iv = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    iv.image = [NSImage imageNamed:@"AlertCaution"];
    return iv;
}

- (NSView *)tableView:(NSTableView *) [[maybe_unused]] _table_view
    viewForTableColumn:(NSTableColumn *)_table_column
                   row:(NSInteger)_row
{
    if( _row >= 0 && _row < static_cast<int>(m_FilteredNodes.size()) ) {
        if( auto node = std::any_cast<ActionShortcutNode>(&m_FilteredNodes[_row]) ) {
            if( [_table_column.identifier isEqualToString:@"action"] ) {
                return SpawnLabelForAction(*node);
            }

            const std::array columns{self.firstShortcutColumn,
                                     self.secondShortcutColumn,
                                     self.thirdShortcutColumn,
                                     self.fourthShortcutColumn};
            if( auto it = std::ranges::find(columns, _table_column); it != columns.end() ) {
                const size_t shortcut_idx = std::distance(columns.begin(), it);

                const auto key_text_field = [self makeDefaultGTMHotKeyTextField];
                assert(key_text_field);
                key_text_field.action = @selector(onHKChanged:);
                key_text_field.target = self;
                key_text_field.tag = node->tag.second;

                const ActionShortcut default_shortcut = node->default_shortcuts.size() > shortcut_idx
                                                            ? node->default_shortcuts[shortcut_idx]
                                                            : ActionShortcut{};
                const ActionShortcut current_shortcut = node->current_shortcuts.size() > shortcut_idx
                                                            ? node->current_shortcuts[shortcut_idx]
                                                            : ActionShortcut{};
                const auto field_cell = nc::objc_cast<GTMHotKeyTextFieldCell>(key_text_field.cell);
                field_cell.hotKey = [GTMHotKey hotKeyWithKey:current_shortcut.Key()
                                                   modifiers:current_shortcut.modifiers];
                field_cell.defaultHotKey = [GTMHotKey hotKeyWithKey:default_shortcut.Key()
                                                          modifiers:default_shortcut.modifiers];
                field_cell.menuHotKey = node->is_menu_action && shortcut_idx == 0;

                if( node->is_customized )
                    field_cell.font = [NSFont boldSystemFontOfSize:field_cell.font.pointSize];
                if( node->has_submenu )
                    key_text_field.enabled = false;

                return key_text_field;
            }

            if( [_table_column.identifier isEqualToString:@"flag"] ) {
                return node->is_conflicted ? SpawnCautionSign() : nil;
            }
        }
        if( auto node = std::any_cast<ToolShortcutNode>(&m_FilteredNodes[_row]) ) {
            if( [_table_column.identifier isEqualToString:@"action"] ) {
                return SpawnLabelForTool(*node);
            }
            if( [_table_column.identifier isEqualToString:@"first"] ) {
                const auto &tool = *node->tool;
                const auto key_text_field = [self makeDefaultGTMHotKeyTextField];
                assert(key_text_field);
                key_text_field.action = @selector(onToolHKChanged:);
                key_text_field.target = self;
                key_text_field.tag = node->tool_index;

                const auto field_cell = nc::objc_cast<GTMHotKeyTextFieldCell>(key_text_field.cell);
                field_cell.hotKey = [GTMHotKey hotKeyWithKey:tool.m_Shorcut.Key() modifiers:tool.m_Shorcut.modifiers];
                field_cell.defaultHotKey = [GTMHotKey hotKeyWithKey:tool.m_Shorcut.Key()
                                                          modifiers:tool.m_Shorcut.modifiers];
                if( node->is_customized )
                    field_cell.font = [NSFont boldSystemFontOfSize:field_cell.font.pointSize];

                return key_text_field;
            }
            if( [_table_column.identifier isEqualToString:@"flag"] ) {
                return node->is_conflicted ? SpawnCautionSign() : nil;
            }
        }
    }
    return nil;
}

- (nc::utility::ActionShortcut)shortcutFromGTMHotKey:(GTMHotKey *)_key
{
    const auto key = _key.key.length > 0 ? [_key.key characterAtIndex:0] : static_cast<uint16_t>(0);
    const auto hk = ActionsShortcutsManager::Shortcut(key, _key.modifiers);
    return hk;
}

- (IBAction)onToolHKChanged:(id)sender
{
    if( auto tf = nc::objc_cast<GTMHotKeyTextField>(sender) ) {
        if( auto gtm_hk = nc::objc_cast<GTMHotKeyTextFieldCell>(tf.cell).hotKey ) {
            const auto tool_index = tf.tag;
            const auto hk = [self shortcutFromGTMHotKey:gtm_hk];
            if( tool_index < static_cast<long>(m_Tools.size()) ) {
                auto &tool = m_Tools[tool_index];
                if( hk != tool->m_Shorcut ) {
                    ExternalTool changed_tool = *tool;
                    changed_tool.m_Shorcut = hk;
                    m_ToolsStorage().ReplaceTool(changed_tool, tool_index);
                }
            }
        }
    }
}

- (IBAction)onHKChanged:(id)sender
{
    GTMHotKeyTextField *tf = nc::objc_cast<GTMHotKeyTextField>(sender);
    if( !tf )
        return;

    GTMHotKey *hk = nc::objc_cast<GTMHotKeyTextFieldCell>(tf.cell).hotKey;
    if( !hk )
        return;

    const ActionShortcut updated_shortcut = [self shortcutFromGTMHotKey:hk];

    const long column = [self.Table columnForView:tf];
    if( column < 1 )
        return;

    const size_t shortcut_idx = column - 1; // primary shortcut is the column #1

    const int tag = static_cast<int>(tf.tag);

    const std::optional<std::string_view> action = m_ActionsShortcutsManager->ActionFromTag(tag);
    if( !action )
        return;

    const std::optional<ActionsShortcutsManager::Shortcuts> current_shortcuts =
        m_ActionsShortcutsManager->ShortcutsFromTag(tag);
    if( !current_shortcuts )
        return;

    std::vector<ActionShortcut> updated_shortcuts(current_shortcuts->begin(), current_shortcuts->end());

    if( shortcut_idx < updated_shortcuts.size() )
        updated_shortcuts[shortcut_idx] = updated_shortcut;
    else
        updated_shortcuts.push_back(updated_shortcut);

    if( m_ActionsShortcutsManager->SetShortcutsOverride(*action, updated_shortcuts) ) {
        [NSApp.mainMenu nc_setMenuItemShortcutsWithActionsShortcutsManager:*m_ActionsShortcutsManager];
    }

    // Rebuild everything just in case the shortcut was a duplicate that ASM filtered out
    [self rebuildAll];
}

- (IBAction)OnDefaults:(id) [[maybe_unused]] sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText =
        NSLocalizedStringFromTable(@"Are you sure you want to reset hotkeys to defaults?",
                                   @"Preferences",
                                   "Message text asking if user really wants to reset hotkeys to defaults");
    alert.informativeText = NSLocalizedStringFromTable(@"This will clear any custom hotkeys.",
                                                       @"Preferences",
                                                       "Informative text when user wants to reset hotkeys to defaults");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if( [alert runModal] == NSAlertFirstButtonReturn ) {
        m_ActionsShortcutsManager->RevertToDefaults();
        [NSApp.mainMenu nc_setMenuItemShortcutsWithActionsShortcutsManager:*m_ActionsShortcutsManager];
        [self rebuildAll];
    }
}

- (IBAction)onForceFnChanged:(id) [[maybe_unused]] sender
{
    if( self.forceFnButton.state == NSControlStateValueOn )
        nc::utility::FunctionalKeysPass::Instance().Enable();
    else
        nc::utility::FunctionalKeysPass::Instance().Disable();
}

- (void)controlTextDidChange:(NSNotification *) [[maybe_unused]] obj
{
    [self buildFilteredNodes];
    [self.Table reloadData];
}

static bool ValidateNodeForFilter(const std::any &_node, NSString *_filter)
{
    if( auto node = std::any_cast<ActionShortcutNode>(&_node) ) {
        const auto label = node->label;
        if( [label rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;

        const auto scid = [NSString stringWithUTF8StdString:node->tag.first];
        if( [scid rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;

        return std::ranges::any_of(node->current_shortcuts, [&](const ActionShortcut &_sc) {
            const auto prettry_hotkey = _sc.PrettyString();
            return [prettry_hotkey rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0;
        });
    }
    if( auto node = std::any_cast<ToolShortcutNode>(&_node) ) {
        const auto label = node->label;
        if( [label rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;

        const auto prettry_hotkey = node->tool->m_Shorcut.PrettyString();
        if( [prettry_hotkey rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;

        const auto app_path = [NSString stringWithUTF8StdString:node->tool->m_ExecutablePath];
        return [app_path rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0;
    }

    return false;
}

- (void)buildFilteredNodes
{
    const auto filter = self.filterTextField.stringValue;
    if( !filter || filter.length == 0 ) {
        m_FilteredNodes = m_SourceNodes;
    }
    else {
        m_FilteredNodes.clear();
        for( auto &v : m_SourceNodes )
            if( ValidateNodeForFilter(v, filter) )
                m_FilteredNodes.emplace_back(v);
    }
}

- (IBAction)onSourceButtonClicked:(id)sender
{
    SourceType required = SourceType::All;
    if( sender == self.sourceAllButton ) {
        required = SourceType::All;
        self.sourceCustomizedButton.state = NSControlStateValueOff;
        self.sourceConflictsButton.state = NSControlStateValueOff;
    }
    if( sender == self.sourceCustomizedButton ) {
        required = SourceType::Customized;
        self.sourceAllButton.state = NSControlStateValueOff;
        self.sourceConflictsButton.state = NSControlStateValueOff;
    }
    if( sender == self.sourceConflictsButton ) {
        required = SourceType::Conflicts;
        self.sourceAllButton.state = NSControlStateValueOff;
        self.sourceCustomizedButton.state = NSControlStateValueOff;
    }
    self.sourceType = required;
}

- (void)setSourceType:(SourceType)sourceType
{
    if( m_SourceType == sourceType )
        return;

    m_SourceType = sourceType;
    [self buildSourceNodes];
    [self buildFilteredNodes];
    [self.Table reloadData];
}

@end

static NSString *LabelTitleForAction(const std::string &_action, NSMenuItem *_item_for_tag)
{
    if( auto menu_item_title = ComposeVerboseMenuItemTitle(_item_for_tag) )
        return menu_item_title;
    else if( auto action_title = ComposeVerboseNonMenuActionTitle(_action) )
        return action_title;
    else
        return [NSString stringWithUTF8StdString:_action];
}

static NSString *ComposeVerboseMenuItemTitle(NSMenuItem *_item)
{
    if( !_item )
        return nil;

    NSString *title = _item.title;

    NSMenuItem *current = _item.parentItem;
    while( current ) {
        title = [NSString stringWithFormat:@"%@ ▶ %@", current.title, title];
        current = current.parentItem;
    }

    return title;
}

static NSString *ComposeVerboseNonMenuActionTitle(const std::string &_action)
{
    [[clang::no_destroy]] static const ankerl::unordered_dense::map<std::string, NSString *> titles = {
        {"panel.move_up", NSLocalizedString(@"File Panels ▶ Move Up", "")},
        {"panel.move_down", NSLocalizedString(@"File Panels ▶ Move Down", "")},
        {"panel.move_left", NSLocalizedString(@"File Panels ▶ Move Left", "")},
        {"panel.move_right", NSLocalizedString(@"File Panels ▶ Move Right", "")},
        {"panel.move_first", NSLocalizedString(@"File Panels ▶ Move to the First Element", "")},
        {"panel.scroll_first", NSLocalizedString(@"File Panels ▶ Scroll to the First Element", "")},
        {"panel.move_last", NSLocalizedString(@"File Panels ▶ Move to the Last Element", "")},
        {"panel.scroll_last", NSLocalizedString(@"File Panels ▶ Scroll to the Last Element", "")},
        {"panel.move_next_page", NSLocalizedString(@"File Panels ▶ Move to the Next Page", "")},
        {"panel.scroll_next_page", NSLocalizedString(@"File Panels ▶ Scroll to the Next Page", "")},
        {"panel.move_prev_page", NSLocalizedString(@"File Panels ▶ Move to the Previous Page", "")},
        {"panel.scroll_prev_page", NSLocalizedString(@"File Panels ▶ Scroll to the Previous Page", "")},
        {"panel.move_next_and_invert_selection",
         NSLocalizedString(@"File Panels ▶ Toggle Selection and Move Down", "")},
        {"panel.invert_item_selection", NSLocalizedString(@"File Panels ▶ Toggle Selection", "")},
        {"panel.go_root", NSLocalizedString(@"File Panels ▶ Go to Root / Directory", "")},
        {"panel.go_home", NSLocalizedString(@"File Panels ▶ Go to Home ~ Directory", "")},
        {"panel.show_preview", NSLocalizedString(@"File Panels ▶ Show Preview", "")},
        {"panel.go_into_enclosing_folder", NSLocalizedString(@"File Panels ▶ Go to Enclosing Folder", "")},
        {"panel.go_into_folder", NSLocalizedString(@"File Panels ▶ Go Into Folder", "")},
        {"panel.show_previous_tab", NSLocalizedString(@"File Panels ▶ Show Previous Tab", "")},
        {"panel.show_next_tab", NSLocalizedString(@"File Panels ▶ Show Next Tab", "")},
        {"panel.show_tab_no_1", NSLocalizedString(@"File Panels ▶ Show Tab №1", "")},
        {"panel.show_tab_no_2", NSLocalizedString(@"File Panels ▶ Show Tab №2", "")},
        {"panel.show_tab_no_3", NSLocalizedString(@"File Panels ▶ Show Tab №3", "")},
        {"panel.show_tab_no_4", NSLocalizedString(@"File Panels ▶ Show Tab №4", "")},
        {"panel.show_tab_no_5", NSLocalizedString(@"File Panels ▶ Show Tab №5", "")},
        {"panel.show_tab_no_6", NSLocalizedString(@"File Panels ▶ Show Tab №6", "")},
        {"panel.show_tab_no_7", NSLocalizedString(@"File Panels ▶ Show Tab №7", "")},
        {"panel.show_tab_no_8", NSLocalizedString(@"File Panels ▶ Show Tab №8", "")},
        {"panel.show_tab_no_9", NSLocalizedString(@"File Panels ▶ Show Tab №9", "")},
        {"panel.show_tab_no_10", NSLocalizedString(@"File Panels ▶ Show Tab №10", "")},
        {"panel.focus_left_panel", NSLocalizedString(@"File Panels ▶ Focus Left Panel", "")},
        {"panel.focus_right_panel", NSLocalizedString(@"File Panels ▶ Focus Right Panel", "")},
        {"panel.show_context_menu", NSLocalizedString(@"File Panels ▶ Show Context Menu", "")},
        {"viewer.toggle_text", NSLocalizedString(@"Viewer ▶ Toggle Text", "")},
        {"viewer.toggle_hex", NSLocalizedString(@"Viewer ▶ Toggle Hex", "")},
        {"viewer.toggle_preview", NSLocalizedString(@"Viewer ▶ Toggle Preview", "")},
        {"viewer.show_settings", NSLocalizedString(@"Viewer ▶ Show Settings", "")},
        {"viewer.show_goto", NSLocalizedString(@"Viewer ▶ Show GoTo", "")},
        {"viewer.refresh", NSLocalizedString(@"Viewer ▶ Refresh", "")},
    };

    if( const auto it = titles.find(_action); it != titles.end() )
        return it->second;

    return nil;
}

static NSString *ComposeExternalToolTitle(const ExternalTool &_et, unsigned _index)
{
    return [NSString
        stringWithFormat:NSLocalizedString(@"Tools ▶ %@", ""),
                         (_et.m_Title.empty() ? [NSString stringWithFormat:NSLocalizedString(@"Tool #%u", ""), _index]
                                              : [NSString stringWithUTF8StdString:_et.m_Title])];
}
