// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/FunctionKeysPass.h>
#import <3rd_Party/GTMHotKeyTextField/GTMHotKeyTextField.h>
#include "../Core/ActionsShortcutsManager.h"
#include "../States/FilePanels/ExternalToolsSupport.h"
#include "../Bootstrap/ActivationManager.h"
#include "PreferencesWindowHotkeysTab.h"

static NSString *ComposeVerboseMenuItemTitle(NSMenuItem *_item);
static NSString *ComposeVerboseNonMenuActionTitle(const string &_action);
static NSString *ComposeExternalToolTitle( const ExternalTool& _et, unsigned _index);
static NSString *LabelTitleForAction( const string &_action, NSMenuItem *_item_for_tag );

namespace {

struct ActionShortcutNode
{
    pair<string,int> tag;
    ActionShortcut  current_shortcut;
    ActionShortcut  default_shortcut;
    NSString *label;
    bool is_menu_action;
    bool is_customized;
    bool is_conflicted;
};

struct ToolShortcutNode
{
    shared_ptr<const ExternalTool> tool;
    NSString *label;
    int tool_index;
    bool is_customized;
    bool is_conflicted;
};

enum class SourceType
{
    All,
    Customized,
    Conflicts
};

}

@interface PreferencesWindowHotkeysTab()

@property (nonatomic) IBOutlet NSTableView *Table;
@property (nonatomic) IBOutlet GTMHotKeyTextField *HotKeyEditFieldTempl;
@property (nonatomic) IBOutlet NSButton *forceFnButton;
@property (nonatomic) IBOutlet NSTextField *filterTextField;
@property (nonatomic) IBOutlet NSButton *sourceAllButton;
@property (nonatomic) IBOutlet NSButton *sourceCustomizedButton;
@property (nonatomic) IBOutlet NSButton *sourceConflictsButton;

@property (nonatomic) SourceType sourceType;

@end

@implementation PreferencesWindowHotkeysTab
{
    vector<pair<string,int>>                m_Shortcuts;
    function<ExternalToolsStorage&()>       m_ToolsStorage;
    ExternalToolsStorage::ObservationTicket m_ToolsObserver;
    vector<shared_ptr<const ExternalTool>>  m_Tools;
    vector<any>                             m_AllNodes;
    vector<any>                             m_SourceNodes;
    vector<any>                             m_FilteredNodes;
    SourceType                              m_SourceType;
}

@synthesize sourceType = m_SourceType;

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage
{
    self = [super init];
    if (self) {
        m_SourceType = SourceType::All;
        m_ToolsStorage = _tool_storage;
        const auto &all_shortcuts = ActionsShortcutsManager::Instance().AllShortcuts();
        m_Shortcuts.assign( begin(all_shortcuts), end(all_shortcuts) );
        
        // remove shortcuts whichs are absent in main menu
        const auto absent = [](auto &_t) {
            if( _t.first.find_first_of("menu.") != 0 )
                return false;
            const auto menu_item = [NSApp.mainMenu itemWithTagHierarchical:_t.second];
            return menu_item == nil || menu_item.isHidden == true;
        };
        m_Shortcuts.erase(remove_if(begin(m_Shortcuts), end(m_Shortcuts), absent),
                          end(m_Shortcuts));
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

- (void) buildData
{
    const auto &sm = ActionsShortcutsManager::Instance();
    m_AllNodes.clear();
    unordered_map<ActionShortcut, int> counts;
    for( auto &v: m_Shortcuts ) {
        const auto menu_item = [NSApp.mainMenu itemWithTagHierarchical:v.second];
        ActionShortcutNode shortcut;
        shortcut.tag = v;
        shortcut.label = LabelTitleForAction(v.first, menu_item);
        shortcut.current_shortcut = sm.ShortCutFromTag(v.second);
        shortcut.default_shortcut = sm.DefaultShortCutFromTag(v.second);
        shortcut.is_menu_action = v.first.find_first_of("menu.") == 0;
        shortcut.is_customized = shortcut.current_shortcut != shortcut.default_shortcut;
        m_AllNodes.emplace_back( move(shortcut) );
        counts[shortcut.current_shortcut]++;
    }
    for( int i = 0, e = (int)m_Tools.size(); i != e; ++i ) {
        const auto &v = m_Tools[i];
        ToolShortcutNode shortcut;
        shortcut.tool = v;
        shortcut.tool_index = i;
        shortcut.label = ComposeExternalToolTitle(*v, i);
        shortcut.is_customized = bool(v->m_Shorcut);
        m_AllNodes.emplace_back( move(shortcut) );
        counts[v->m_Shorcut]++;
    }
    
    int conflicts_amount = 0;
    for( auto &v: m_AllNodes ) {
        if( auto node = any_cast<ActionShortcutNode>(&v) ) {
            node->is_conflicted = node->current_shortcut &&
                                    counts[node->current_shortcut] > 1;
            if( node->is_conflicted )
                conflicts_amount++;
        }
        if( auto node = any_cast<ToolShortcutNode>(&v) ) {
            node->is_conflicted = node->tool->m_Shorcut &&
                                    counts[node->tool->m_Shorcut] > 1;
            if( node->is_conflicted )
                conflicts_amount++;
        }
    }
    
    if( conflicts_amount ) {
        auto fmt = NSLocalizedString(@"Conflicts (%@)", "");
        self.sourceConflictsButton.title = [NSString stringWithFormat:fmt,
                                            [NSNumber numberWithInt:conflicts_amount]];
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
        for( auto &v: m_AllNodes ) {
            if( auto node = any_cast<ActionShortcutNode>(&v) )
                if( node->is_customized )
                    m_SourceNodes.emplace_back(v);
            if( auto node = any_cast<ToolShortcutNode>(&v) )
                if( node->is_customized )
                    m_SourceNodes.emplace_back(v);
        }
    }
    if( m_SourceType == SourceType::Conflicts ) {
        m_SourceNodes.clear();
        for( auto &v: m_AllNodes ) {
            if( auto node = any_cast<ActionShortcutNode>(&v) )
                if( node->is_conflicted )
                    m_SourceNodes.emplace_back(v);
            if( auto node = any_cast<ToolShortcutNode>(&v) )
                if( node->is_conflicted )
                    m_SourceNodes.emplace_back(v);
        }
    }
}

- (void)loadView
{
    [super loadView];
    m_Tools = m_ToolsStorage().GetAllTools();
    
    if( ActivationManager::Instance().Sandboxed() )
        self.forceFnButton.hidden = true;
    
    m_ToolsObserver = m_ToolsStorage().ObserveChanges([=]{
        dispatch_to_main_queue([=]{
            m_Tools = m_ToolsStorage().GetAllTools();
            [self rebuildAll];
        });
    });
    
    [self buildData];
    m_SourceNodes = m_FilteredNodes = m_AllNodes;
}

-(NSString*)identifier
{
    return NSStringFromClass(self.class);
}

-(NSImage*)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesIcons_Hotkeys"];
}

-(NSString*)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Hotkeys",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_FilteredNodes.size();
}

- (GTMHotKeyTextField*) makeDefaultGTMHotKeyTextField
{
    const auto data = [NSKeyedArchiver archivedDataWithRootObject:self.HotKeyEditFieldTempl];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

static NSTextField *SpawnLabelForAction( const ActionShortcutNode &_action )
{
    const auto tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.toolTip = [NSString stringWithUTF8StdString:_action.tag.first];
    tf.stringValue = _action.label;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    return tf;
}

static NSTextField *SpawnLabelForTool( const ToolShortcutNode &_node )
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

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if( row >= 0 && row < (int)m_FilteredNodes.size() ) {
        if( auto node = any_cast<ActionShortcutNode>(&m_FilteredNodes[row]) ) {
            if( [tableColumn.identifier isEqualToString:@"action"] ) {
                return SpawnLabelForAction(*node);
            }
            if( [tableColumn.identifier isEqualToString:@"hotkey"] ) {
                const auto key_text_field = [self makeDefaultGTMHotKeyTextField];
                key_text_field.action = @selector(onHKChanged:);
                key_text_field.target = self;
                key_text_field.tag = node->tag.second;
                
                const auto field_cell = objc_cast<GTMHotKeyTextFieldCell>(key_text_field.cell);
                field_cell.objectValue = [GTMHotKey hotKeyWithKey:node->current_shortcut.Key()
                                                        modifiers:node->current_shortcut.modifiers];
                field_cell.defaultHotKey = [GTMHotKey hotKeyWithKey:node->default_shortcut.Key()
                                                          modifiers:node->default_shortcut.modifiers];
                field_cell.strictModifierRequirement = node->is_menu_action;
            
                if( node->is_customized )
                    field_cell.font = [NSFont boldSystemFontOfSize:field_cell.font.pointSize];
                
                return key_text_field;
            }
            if( [tableColumn.identifier isEqualToString:@"flag"] ) {
                return node->is_conflicted ? SpawnCautionSign() : nil;
            }
        }
        if( auto node = any_cast<ToolShortcutNode>(&m_FilteredNodes[row]) ) {
            if( [tableColumn.identifier isEqualToString:@"action"] ) {
                return SpawnLabelForTool(*node);
            }
            if( [tableColumn.identifier isEqualToString:@"hotkey"] ) {
                const auto &tool = *node->tool;
                const auto key_text_field = [self makeDefaultGTMHotKeyTextField];
                key_text_field.action = @selector(onToolHKChanged:);
                key_text_field.target = self;
                key_text_field.tag = node->tool_index;
                
                const auto field_cell = objc_cast<GTMHotKeyTextFieldCell>(key_text_field.cell);
                field_cell.objectValue = [GTMHotKey hotKeyWithKey:tool.m_Shorcut.Key()
                                                        modifiers:tool.m_Shorcut.modifiers];
                field_cell.defaultHotKey = [GTMHotKey hotKeyWithKey:tool.m_Shorcut.Key()
                                                          modifiers:tool.m_Shorcut.modifiers];
                if( node->is_customized )
                    field_cell.font = [NSFont boldSystemFontOfSize:field_cell.font.pointSize];
                
                return key_text_field;
            }
            if( [tableColumn.identifier isEqualToString:@"flag"] ) {
                return node->is_conflicted ? SpawnCautionSign() : nil;
            }
        }
    }
    return nil;
}

- (ActionShortcut) shortcutFromGTMHotKey:(GTMHotKey *)_key
{
    const auto key = _key.key.length > 0 ? [_key.key characterAtIndex:0] : (uint16_t)0;
    const auto hk = ActionsShortcutsManager::ShortCut(key, _key.modifiers);
    return hk;
}

- (IBAction)onToolHKChanged:(id)sender
{
    if( auto tf = objc_cast<GTMHotKeyTextField>(sender) ) {
        if( auto gtm_hk = objc_cast<GTMHotKey>(tf.cell.objectValue) ) {
            const auto tool_index = tf.tag;
            const auto hk = [self shortcutFromGTMHotKey:gtm_hk];
            if( tool_index < (long)m_Tools.size() ) {
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
    auto &am = ActionsShortcutsManager::Instance();
    if( auto tf = objc_cast<GTMHotKeyTextField>(sender) )
        if( auto gtm_hk = objc_cast<GTMHotKey>(tf.cell.objectValue) ) {
            auto tag = int(tf.tag);
            auto hk = [self shortcutFromGTMHotKey:gtm_hk];
            auto action = am.ActionFromTag(tag);
            if( am.SetShortCutOverride(action, hk) ) {
                am.SetMenuShortCuts( NSApp.mainMenu );
                [self rebuildAll];
            }
        }
}

- (IBAction)OnDefaults:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringFromTable(@"Are you sure you want to reset hotkeys to defaults?",
                                                   @"Preferences",
                                                   "Message text asking if user really wants to reset hotkeys to defaults");
    alert.informativeText = NSLocalizedStringFromTable(@"This will clear any custom hotkeys.",
                                                       @"Preferences",
                                                       "Informative text when user wants to reset hotkeys to defaults");
    [alert addButtonWithTitle:NSLocalizedString(@"OK","")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel","")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn) {
        ActionsShortcutsManager::Instance().RevertToDefaults();
        ActionsShortcutsManager::Instance().SetMenuShortCuts(NSApp.mainMenu);
        [self rebuildAll];
    }
}

- (IBAction)onForceFnChanged:(id)sender
{
    if( self.forceFnButton.state == NSOnState )
        FunctionalKeysPass::Instance().Enable();
    else
        FunctionalKeysPass::Instance().Disable();
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self buildFilteredNodes];
    [self.Table reloadData];    
}

static bool ValidateNodeForFilter( const any& _node, NSString *_filter )
{
    if( auto node = any_cast<ActionShortcutNode>(&_node) ) {
        const auto label = node->label;
        if( [label rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;
        
        const auto scid = [NSString stringWithUTF8StdString:node->tag.first];
        if( [scid rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;

        const auto prettry_hotkey = node->current_shortcut.PrettyString();
        if( [prettry_hotkey rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;

        return false;
    }
    if( auto node = any_cast<ToolShortcutNode>(&_node) ) {
        const auto label = node->label;
        if( [label rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;
    
        const auto prettry_hotkey = node->tool->m_Shorcut.PrettyString();
        if( [prettry_hotkey rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;
        
        const auto app_path = [NSString stringWithUTF8StdString:node->tool->m_ExecutablePath];
        if( [app_path rangeOfString:_filter options:NSCaseInsensitiveSearch].length != 0 )
            return true;
    
        return false;
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
        for( auto &v: m_SourceNodes )
            if( ValidateNodeForFilter(v, filter) )
                m_FilteredNodes.emplace_back(v);
    }
}

- (IBAction)onSourceButtonClicked:(id)sender
{
    SourceType required = SourceType::All;
    if( sender == self.sourceAllButton ) {
        required = SourceType::All;
        self.sourceCustomizedButton.state = NSOffState;
        self.sourceConflictsButton.state = NSOffState;
    }
    if( sender == self.sourceCustomizedButton ) {
        required = SourceType::Customized;
        self.sourceAllButton.state = NSOffState;
        self.sourceConflictsButton.state = NSOffState;
    }
    if( sender == self.sourceConflictsButton ) {
        required = SourceType::Conflicts;
        self.sourceAllButton.state = NSOffState;
        self.sourceCustomizedButton.state = NSOffState;
    }
    self.sourceType = required;
}

- (void) setSourceType:(SourceType)sourceType
{
    if( m_SourceType == sourceType )
        return;

    m_SourceType = sourceType;
    [self buildSourceNodes];
    [self buildFilteredNodes];
    [self.Table reloadData];
}

@end

static NSString *LabelTitleForAction( const string &_action, NSMenuItem *_item_for_tag )
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
    if(!_item)
        return nil;

    NSString *title = _item.title;
    
    NSMenuItem *current = _item.parentItem;
    while( current ) {
        title = [NSString stringWithFormat:@"%@ ▶ %@", current.title, title];
        current = current.parentItem;
    }
    
    return title;
}

static NSString *ComposeVerboseNonMenuActionTitle(const string &_action)
{
    static const vector< pair<const char *, NSString *> > titles = {
        {"panel.move_up",                       NSLocalizedString(@"File Panels ▶ Move Up", "")},
        {"panel.move_down",                     NSLocalizedString(@"File Panels ▶ Move Down", "")},
        {"panel.move_left",                     NSLocalizedString(@"File Panels ▶ Move Left", "")},
        {"panel.move_right",                    NSLocalizedString(@"File Panels ▶ Move Right", "")},
        {"panel.move_first",                    NSLocalizedString(@"File Panels ▶ Move to the First Element", "")},
        {"panel.scroll_first",                  NSLocalizedString(@"File Panels ▶ Scroll to the First Element", "")},
        {"panel.move_last",                     NSLocalizedString(@"File Panels ▶ Move to the Last Element", "")},
        {"panel.scroll_last",                   NSLocalizedString(@"File Panels ▶ Scroll to the Last Element", "")},
        {"panel.move_next_page",                NSLocalizedString(@"File Panels ▶ Move to the Next Page", "")},
        {"panel.scroll_next_page",              NSLocalizedString(@"File Panels ▶ Scroll to the Next Page", "")},
        {"panel.move_prev_page",                NSLocalizedString(@"File Panels ▶ Move to the Previous Page", "")},
        {"panel.scroll_prev_page",              NSLocalizedString(@"File Panels ▶ Scroll to the Previous Page", "")},
        {"panel.move_next_and_invert_selection",NSLocalizedString(@"File Panels ▶ Toggle Selection and Move Down", "")},
        {"panel.invert_item_selection",         NSLocalizedString(@"File Panels ▶ Toggle Selection", "")},
        {"panel.go_root",                       NSLocalizedString(@"File Panels ▶ Go to Root / Directory", "")},
        {"panel.go_home",                       NSLocalizedString(@"File Panels ▶ Go to Home ~ Directory", "")},
        {"panel.show_preview",                  NSLocalizedString(@"File Panels ▶ Show Preview", "")},
        {"panel.go_into_enclosing_folder",      NSLocalizedString(@"File Panels ▶ Go to Enclosing Folder", "")},
        {"panel.go_into_folder",                NSLocalizedString(@"File Panels ▶ Go Into Folder", "")},
        {"panel.show_previous_tab",             NSLocalizedString(@"File Panels ▶ Show Previous Tab", "")},
        {"panel.show_next_tab",                 NSLocalizedString(@"File Panels ▶ Show Next Tab", "")},
        {"panel.show_tab_no_1",                 NSLocalizedString(@"File Panels ▶ Show Tab №1", "")},
        {"panel.show_tab_no_2",                 NSLocalizedString(@"File Panels ▶ Show Tab №2", "")},
        {"panel.show_tab_no_3",                 NSLocalizedString(@"File Panels ▶ Show Tab №3", "")},
        {"panel.show_tab_no_4",                 NSLocalizedString(@"File Panels ▶ Show Tab №4", "")},
        {"panel.show_tab_no_5",                 NSLocalizedString(@"File Panels ▶ Show Tab №5", "")},
        {"panel.show_tab_no_6",                 NSLocalizedString(@"File Panels ▶ Show Tab №6", "")},
        {"panel.show_tab_no_7",                 NSLocalizedString(@"File Panels ▶ Show Tab №7", "")},
        {"panel.show_tab_no_8",                 NSLocalizedString(@"File Panels ▶ Show Tab №8", "")},
        {"panel.show_tab_no_9",                 NSLocalizedString(@"File Panels ▶ Show Tab №9", "")},
        {"panel.show_tab_no_10",                NSLocalizedString(@"File Panels ▶ Show Tab №10", "")},
    };
    
    for( auto &i: titles )
        if( i.first == _action )
            return i.second;
    
    return nil;
}

static NSString *ComposeExternalToolTitle( const ExternalTool& _et, unsigned _index)
{
    return [NSString stringWithFormat:NSLocalizedString(@"Tools ▶ %@", ""),
            (_et.m_Title.empty() ?
             [NSString stringWithFormat:NSLocalizedString(@"Tool #%u", ""), _index] :
             [NSString stringWithUTF8StdString:_et.m_Title]) ];
}
