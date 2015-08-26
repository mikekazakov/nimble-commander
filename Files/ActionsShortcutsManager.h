//
//  ActionsShortcutsManager.h
//  Files
//
//  Created by Michael G. Kazakov on 26.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

class ActionsShortcutsManager
{
public:
    static ActionsShortcutsManager &Instance();
    
    /**
     * Return -1 on if tag corresponing _action wasn't found.
     */
    int TagFromAction(const string &_action) const;

    /**
     * return "" on if action corresponing _tag wasn't found.
     */
    string ActionFromTag(int _tag) const;
    
    struct ShortCut
    {
        unsigned long modifiers = 0;
        NSString *key           = @"";
        uint16_t  unic          = 0; // same as [key characterAtIndex:0], for perfomance purposes

        bool operator==(const ShortCut&_r) const;
        bool operator!=(const ShortCut&_r) const;
        
        NSString *ToPersString() const;
        bool FromPersString(NSString *_from);
        bool FromStringAndModif(NSString *_from, unsigned long _modif);
        bool IsKeyDown(unichar _unicode, unsigned short _keycode, unsigned long _modifiers) const;
    };
    
    /**
     * Return nullptr if can't found.
     * Overrides has priority over defaults.
     */
    const ShortCut *ShortCutFromAction(const string &_action) const;

    /**
     * Return nullptr if can't found.
     * Overrides has priority over defaults.
     */
    const ShortCut *ShortCutFromTag(int _tag) const;
    
    
    void RevertToDefaults();
    void SetShortCutOverride(const string &_action, const ShortCut& _sc);
    
    
    void SetMenuShortCuts(NSMenu *_menu) const;
    
    inline const vector<pair<string,int>>& AllShortcuts() const { return m_ActionsTags; }
    
private:
    ActionsShortcutsManager();
    ActionsShortcutsManager(const ActionsShortcutsManager&) = delete;
    
    void ReadOverrides(NSArray *_dict);
    void WriteOverrides(NSMutableArray *_dict) const;
    bool WriteOverridesToConfigFile() const;
    
    // persistance holy grail is below, change id's only in emergency case:
    const vector<pair<string,int>> m_ActionsTags = {
        {"menu.files.about",                    10000},
        {"menu.files.preferences",              10010},
        {"menu.files.hide",                     10020},
        {"menu.files.hide_others",              10030},
        {"menu.files.show_all",                 10040},
        {"menu.files.quit",                     10050},
        {"menu.files.toggle_admin_mode",        10070},
        
        {"menu.file.newwindow",                 11000},
        {"menu.file.new_folder",                11090},
        {"menu.file.new_folder_with_selection", 11100},
        {"menu.file.new_file",                  11120},
        {"menu.file.new_tab",                   11110},
        {"menu.file.open",                      11010},
        {"menu.file.open_native",               11020},
        {"menu.file.open_in_opposite_panel",    11021},
        {"menu.file.feed_filename_to_terminal", 11022},
        {"menu.file.feed_filenames_to_terminal",11023},
        {"menu.file.calculate_sizes",           11030},
        {"menu.file.calculate_all_sizes",       11031},
        {"menu.file.calculate_checksum",        11080},
        {"menu.file.close_window",              11041},
        {"menu.file.close",                     11040},
        {"menu.file.find",                      11050},
        {"menu.file.page_setup",                11060},
        {"menu.file.print",                     11070},
        
        {"menu.edit.copy",                      12000},
        {"menu.edit.paste",                     12010},
        {"menu.edit.select_all",                12020},
        {"menu.edit.deselect_all",              12030},
        {"menu.edit.invert_selection",          12040},

        {"menu.view.left_panel_change_folder",  13000},
        {"menu.view.right_panel_change_folder", 13010},
        {"menu.view.swap_panels",               13020},
        {"menu.view.sync_panels",               13030},
        {"menu.view.refresh",                   13040},
        {"menu.view.toggle_short_mode",         13050},
        {"menu.view.toggle_medium_mode",        13060},
        {"menu.view.toggle_full_mode",          13070},
        {"menu.view.toggle_wide_mode",          13080},
        {"menu.view.sorting_by_name",           13090},
        {"menu.view.sorting_by_extension",      13100},
        {"menu.view.sorting_by_modify_time",    13110},
        {"menu.view.sorting_by_size",           13120},
        {"menu.view.sorting_by_creation_time",  13130},
        {"menu.view.sorting_view_hidden",       13140},
        {"menu.view.sorting_separate_folders",  13150},
        {"menu.view.sorting_case_sensitive",    13160},
        {"menu.view.sorting_numeric_comparison",13170},
        {"menu.view.show_tabs",                 13179},
        {"menu.view.show_toolbar",              13180},
        {"menu.view.show_terminal",             13190},
        {"menu.view.panels_position.move_up",   13200},
        {"menu.view.panels_position.move_down", 13210},
        {"menu.view.panels_position.move_left", 13220},
        {"menu.view.panels_position.move_right",13230},
        {"menu.view.panels_position.showpanels",13240},
        {"menu.view.panels_position.focusterminal",13250},        
        
        {"menu.go.back",                        14000},
        {"menu.go.forward",                     14010},
        {"menu.go.enclosing_folder",            14020},
        {"menu.go.into_folder",                 14030},
        {"menu.go.documents",                   14040},
        {"menu.go.desktop",                     14050},
        {"menu.go.downloads",                   14060},
        {"menu.go.home",                        14070},
        {"menu.go.library",                     14080},
        {"menu.go.applications",                14090},
        {"menu.go.utilities",                   14100},
        {"menu.go.root",                        14150},
        {"menu.go.processes_list",              14120},
        {"menu.go.to_folder",                   14110},
        {"menu.go.connect.ftp",                 14130},
        {"menu.go.connect.sftp",                14140},
        {"menu.go.quick_lists.parent_folders",  14160},
        {"menu.go.quick_lists.history",         14170},
        {"menu.go.quick_lists.favorites",       14180},
        {"menu.go.quick_lists.volumes",         14190},
        {"menu.go.quick_lists.connections",     14200},
        
        {"menu.command.system_overview",        15000},
        {"menu.command.volume_information",     15010},
        {"menu.command.file_attributes",        15020},
        {"menu.command.copy_file_name",         15030},
        {"menu.command.copy_file_path",         15040},
        {"menu.command.select_with_mask",       15050},
        {"menu.command.deselect_with_mask",     15060},
        {"menu.command.quick_look",             15070},
        {"menu.command.internal_viewer",        15080},
        {"menu.command.external_editor",        15081},
        {"menu.command.eject_volume",           15090},
        {"menu.command.compress",               15100},
        {"menu.command.batch_rename",           15220},
        {"menu.command.copy_to",                15110},
        {"menu.command.copy_as",                15120},
        {"menu.command.move_to",                15130},
        {"menu.command.move_as",                15140},
        {"menu.command.create_directory",       15150},
        {"menu.command.move_to_trash",          15160},
        {"menu.command.delete",                 15170},
        {"menu.command.delete_alternative",     15180},
        {"menu.command.link_create_soft",       15190},
        {"menu.command.link_create_hard",       15200},
        {"menu.command.link_edit",              15210},
        
        {"menu.window.minimize",                16000},
        {"menu.window.fullscreen",              16010},
        {"menu.window.zoom",                    16020},
        {"menu.window.show_previous_tab",       16040},
        {"menu.window.show_next_tab",           16050},
        {"menu.window.bring_all_to_front",      16030}
    };
    
    map<int, string>        m_TagToAction;
    map<string, int>        m_ActionToTag;
    
    map<int, ShortCut>      m_ShortCutsDefaults;
    map<int, ShortCut>      m_ShortCutsOverrides;
};

#define IF_MENU_TAG_TOKENPASTE(x, y) x ## y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str) static const long IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) = ActionsShortcutsManager::Instance().TagFromAction(str); \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
