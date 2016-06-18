//
//  ActionsShortcutsManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "ActionsShortcutsManager.h"
#include "AppDelegate.h"

static const auto g_OverridesConfigFile = "HotkeysOverrides.plist";

static const vector<pair<const char*, const char*>> g_DefaultShortcuts = {
        {"menu.nimble_commander.about",                        u8""     },
        {"menu.nimble_commander.preferences",                  u8"⌘,"   },  // cmd+,
        {"menu.nimble_commander.toggle_admin_mode",            u8""     },
        {"menu.nimble_commander.hide",                         u8"⌘h"   },  // cmd+h
        {"menu.nimble_commander.hide_others",                  u8"⌥⌘h"  },  // cmd+alt+h
        {"menu.nimble_commander.show_all",                     u8""     },
        {"menu.nimble_commander.quit",                         u8"⌘q"   },  // cmd+q
        {"menu.nimble_commander.active_license_file",          u8""     },
        {"menu.nimble_commander.purchase_license",             u8""     },
        {"menu.nimble_commander.purchase_pro_features",        u8""     },
        {"menu.nimble_commander.restore_purchases",            u8""     },

        {"menu.file.newwindow",                     u8"⌘n"      },  // cmd+n
        {"menu.file.new_folder",                    u8"⇧⌘n"     },  // cmd+shift+n
        {"menu.file.new_folder_with_selection",     u8"^⌘n"     },  // cmd+ctrl+n
        {"menu.file.new_file",                      u8"⌥⌘n"     },  // cmd+alt+n
        {"menu.file.new_tab",                       u8"⌘t"      },  // cmd+t
        {"menu.file.open",                          u8"\\r"     },  // ↵
        {"menu.file.open_native",                   u8"⇧\\r"    },  // shift+↵
        {"menu.file.open_in_opposite_panel",        u8"⌥\\r"    },  // alt+↵
        {"menu.file.open_in_opposite_panel_tab",    u8"⌥⌘\\r"   },  // alt+cmd+↵
        {"menu.file.calculate_sizes",               u8"⇧⌥\\r"   },  // shift+alt+↵
        {"menu.file.calculate_all_sizes",           u8"⇧^\\r"   },  // shift+ctrl+↵
        {"menu.file.feed_filename_to_terminal",     u8"^⌥\\r"   },  // ctrl+alt+↵
        {"menu.file.feed_filenames_to_terminal",    u8"^⌥⌘\\r"  },  // ctrl+alt+cmd+↵
        {"menu.file.calculate_checksum",            u8"⇧⌘k"     },  // shift+cmd+k
        {"menu.file.close_window",                  u8"⇧⌘w"     },  // shift+cmd+w
        {"menu.file.close",                         u8"⌘w"      },  // cmd+w
        {"menu.file.find",                          u8"⌘f"      },  // cmd+f
        {"menu.file.find_with_spotlight",           u8"⌥⌘f"     },  // alt+cmd+f
        {"menu.file.page_setup",                    u8"⇧⌘p"     },  // shift+cmd+p
        {"menu.file.print",                         u8"⌘p"      },  // cmd+p

        {"menu.edit.copy",                          u8"⌘c"      },  // cmd+c
        {"menu.edit.paste",                         u8"⌘v"      },  // cmd+v
        {"menu.edit.move_here",                     u8"⌥⌘v"     },  // alt+cmd+v
        {"menu.edit.select_all",                    u8"⌘a"      },  // cmd+a
        {"menu.edit.deselect_all",                  u8"⌥⌘a"     },  // alt+cmd+a
        {"menu.edit.invert_selection",              u8"^⌘a"     },  // ctrl+cmd+a

        {"menu.view.left_panel_change_folder",      u8"\uF704"  },  // F1
        {"menu.view.right_panel_change_folder",     u8"\uF705"  },  // F2
        {"menu.view.swap_panels",                   u8"⌘u"      },  // cmd+u
        {"menu.view.sync_panels",                   u8"⌥⌘u"     },  // alt+cmd+u
        {"menu.view.refresh",                       u8"⌘r"      },  // cmd+r
        {"menu.view.toggle_short_mode",             u8"^1"      },  // ctrl+1
        {"menu.view.toggle_medium_mode",            u8"^2"      },  // ctrl+2
        {"menu.view.toggle_full_mode",              u8"^3"      },  // ctrl+3
        {"menu.view.toggle_wide_mode",              u8"^4"      },  // ctrl+4
        {"menu.view.sorting_by_name",               u8"^⌘1"     },  // ctrl+cmd+1
        {"menu.view.sorting_by_extension",          u8"^⌘2"     },  // ctrl+cmd+2
        {"menu.view.sorting_by_modify_time",        u8"^⌘3"     },  // ctrl+cmd+3
        {"menu.view.sorting_by_size",               u8"^⌘4"     },  // ctrl+cmd+4
        {"menu.view.sorting_by_creation_time",      u8"^⌘5"     },  // ctrl+cmd+5
        {"menu.view.sorting_view_hidden",           u8"⇧⌥⌘i"    },  // shift+alt+cmd+i
        {"menu.view.sorting_separate_folders",      u8""        },
        {"menu.view.sorting_case_sensitive",        u8""        },
        {"menu.view.sorting_numeric_comparison",    u8""        },
        {"menu.view.panels_position.move_up",       u8"^⌥\uF700"},  // ctrl+alt+↑
        {"menu.view.panels_position.move_down",     u8"^⌥\uF701"},  // ctrl+alt+↓
        {"menu.view.panels_position.move_left",     u8"^⌥\uF702"},  // ctrl+alt+←
        {"menu.view.panels_position.move_right",    u8"^⌥\uF703"},  // ctrl+alt+→
        {"menu.view.panels_position.showpanels",    u8"^⌥o"     },  // ctrl+alt+o
        {"menu.view.panels_position.focusterminal", u8"^⌥\t"    },  // ctrl+alt+⇥
        {"menu.view.show_tabs",                     u8"⇧⌘t"     },  // shift+cmd+t
        {"menu.view.show_toolbar",                  u8"⌥⌘t"     },  // alt+cmd+t
        {"menu.view.show_terminal",                 u8"⌥⌘o"     },  // alt+cmd+o
    
        {"menu.go.back",                            u8"⌘["      },  // cmd+[
        {"menu.go.forward",                         u8"⌘]"      },  // cmd+]
        {"menu.go.enclosing_folder",                u8"⌘\uF700" },  // cmd+↑
        {"menu.go.into_folder",                     u8"⌘\uF701" },  // cmd+↓
        {"menu.go.documents",                       u8"⇧⌘o"     },  // shift+cmd+o
        {"menu.go.desktop",                         u8"⇧⌘d"     },  // shift+cmd+d
        {"menu.go.downloads",                       u8"⌥⌘l"     },  // alt+cmd+l
        {"menu.go.home",                            u8"⇧⌘h"     },  // shift+cmd+h
        {"menu.go.library",                         u8""        },
        {"menu.go.applications",                    u8"⇧⌘a"     }, // shift+cmd+a
        {"menu.go.utilities",                       u8"⇧⌘u"     }, // shift+cmd+u
        {"menu.go.processes_list",                  u8"⌥⌘p"     }, // alt+cmd+p
        {"menu.go.to_folder",                       u8"⇧⌘g"     }, // shift+cmd+g
        {"menu.go.connect.ftp",                     u8""        },
        {"menu.go.connect.sftp",                    u8""        },
        {"menu.go.root",                            u8""        },
        {"menu.go.quick_lists.parent_folders",      u8"⌘1"      }, // cmd+1
        {"menu.go.quick_lists.history",             u8"⌘2"      }, // cmd+2
        {"menu.go.quick_lists.favorites",           u8"⌘3"      }, // cmd+3
        {"menu.go.quick_lists.volumes",             u8"⌘4"      }, // cmd+4
        {"menu.go.quick_lists.connections",         u8"⌘5"      }, // cmd+5

        {"menu.command.system_overview",            u8"⌘l"      }, // cmd+l
        {"menu.command.volume_information",         u8""        },
        {"menu.command.file_attributes",            u8"^a"      }, // ctrl+a
        {"menu.command.copy_file_name",             u8"⇧⌘c"     }, // shift+cmd+c
        {"menu.command.copy_file_path",             u8"⌥⌘c"     }, // alt+cmd+c
        {"menu.command.select_with_mask",           u8"⌘="      }, // cmd+=
        {"menu.command.select_with_extension",      u8"⌥⌘="     }, // alt+cmd+=
        {"menu.command.deselect_with_mask",         u8"⌘-"      }, // cmd+-
        {"menu.command.deselect_with_extension",    u8"⌥⌘-"     }, // alt+cmd+-
        {"menu.command.quick_look",                 u8"⌘y"      }, // cmd+y
        {"menu.command.internal_viewer",            u8"⌥\uF706" }, // alt+F3
        {"menu.command.external_editor",            u8"\uF707"  }, // F4
        {"menu.command.eject_volume",               u8"⌘e"      }, // cmd+e
        {"menu.command.compress",                   u8""        },
        {"menu.command.batch_rename",               u8"^m"      }, // ctrl+m
        {"menu.command.copy_to",                    u8"\uF708"  }, // F5
        {"menu.command.copy_as",                    u8"⇧\uF708" }, // shift+F5
        {"menu.command.move_to",                    u8"\uF709"  }, // F6
        {"menu.command.move_as",                    u8"⇧\uF709" }, // shift+F6
        {"menu.command.rename_in_place",            u8"^\uF709" }, // ctrl+F6
        {"menu.command.create_directory",           u8"\uF70a"  }, // F7
        {"menu.command.move_to_trash",              u8"⌘\u007f" }, // cmd+backspace
        {"menu.command.delete",                     u8"\uF70b"  }, // F8
        {"menu.command.delete_permanently",         u8"⇧\uF70b" }, // shift+F8
        {"menu.command.link_create_soft",           u8""        },
        {"menu.command.link_create_hard",           u8""        },
        {"menu.command.link_edit",                  u8""        },
        {"menu.command.open_xattr",                 u8"⌥⌘x"     }, // // alt+cmd+x

        {"menu.window.minimize",                    u8"⌘m"      }, // cmd+m
        {"menu.window.fullscreen",                  u8"^⌘f"     }, // ctrl+cmd+f
        {"menu.window.zoom",                        u8""        },
        {"menu.window.show_previous_tab",           u8"⇧^\t"    }, // shift+ctrl+tab
        {"menu.window.show_next_tab",               u8"^\t"     }, // ctrl+tab
        {"menu.window.bring_all_to_front",          u8""        },

        {"panel.move_up",                           u8"\uF700"  }, // up
        {"panel.move_down",                         u8"\uF701"  }, // down
        {"panel.move_left",                         u8"\uF702"  }, // left
        {"panel.move_right",                        u8"\uF703"  }, // right
        {"panel.move_first",                        u8"\uF729"  }, // home
        {"panel.move_last",                         u8"\uF72B"  }, // end
        {"panel.move_next_page",                    u8"\uF72D"  }, // page up
        {"panel.move_prev_page",                    u8"\uF72C"  }, // page down
        {"panel.move_next_and_invert_selection",    u8"\u0003"  }, // insert
        {"panel.go_root",                           u8"/"       }, // slash
        {"panel.go_home",                           u8"~"       }, // tilde
        {"panel.show_preview",                      u8" "       }, // space
};

ActionsShortcutsManager::ShortCutsUpdater::ShortCutsUpdater( initializer_list<ShortCut*> _hotkeys, initializer_list<const char*> _actions ):
    m_LastUpdated(0)
{
    if( _hotkeys.size() != _actions.size() )
        throw logic_error("_hotkeys.size() != _actions.size()");
    
    auto &am = ActionsShortcutsManager::Instance();
    for( int i = 0; i < _hotkeys.size(); ++i )
        m_Pets.emplace_back( _hotkeys.begin()[i], am.TagFromAction(_actions.begin()[i]) );
    CheckAndUpdate();
}

void ActionsShortcutsManager::ShortCutsUpdater::CheckAndUpdate()
{
    auto &am = ActionsShortcutsManager::Instance();
    if( m_LastUpdated < am.LastChanged() ) {
        for( auto &i: m_Pets )
            *i.first = am.ShortCutFromTag(i.second);
        m_LastUpdated = am.LastChanged();
    }
}

ActionsShortcutsManager::ActionsShortcutsManager()
{
    for(auto &i: m_ActionsTags) {
        m_TagToAction[i.second] = i.first;
        m_ActionToTag[i.first]  = i.second;
    }
        
    for(auto &d: g_DefaultShortcuts) {
        auto i = m_ActionToTag.find( get<0>(d) );
        if( i == end(m_ActionToTag) )
            continue;
        
        if( ShortCut sc{[NSString stringWithUTF8StringNoCopy:get<1>(d)]} )
            m_ShortCutsDefaults[i->second] = sc;
    }
    
    if(auto a = [NSArray arrayWithContentsOfFile:[NSString stringWithUTF8StdString:AppDelegate.me.configDirectory + g_OverridesConfigFile]])
        ReadOverrides(a);
    
    m_LastChanged = machtime();
}

ActionsShortcutsManager &ActionsShortcutsManager::Instance()
{
    static ActionsShortcutsManager *manager = new ActionsShortcutsManager;
    return *manager;
}

int ActionsShortcutsManager::TagFromAction(const string &_action) const
{
    auto it = m_ActionToTag.find(_action);
    if( it != end(m_ActionToTag) )
        return it->second;
    return -1;
}

string ActionsShortcutsManager::ActionFromTag(int _tag) const
{
    auto it = m_TagToAction.find(_tag);
    if( it != end(m_TagToAction) )
        return it->second;
    return "";
}

void ActionsShortcutsManager::SetMenuShortCuts(NSMenu *_menu) const
{
    NSArray *array = _menu.itemArray;
    for(NSMenuItem *i: array)
    {
        if(i.submenu != nil)
        {
            SetMenuShortCuts(i.submenu);
        }
        else
        {
            int tag = (int)i.tag;

            auto scover = m_ShortCutsOverrides.find(tag);
            if(scover != m_ShortCutsOverrides.end())
            {
                i.keyEquivalent = scover->second.Key();
                i.keyEquivalentModifierMask = scover->second.modifiers;
            }
            else
            {
                auto sc = m_ShortCutsDefaults.find(tag);
                if(sc != m_ShortCutsDefaults.end())
                {
                    i.keyEquivalent = sc->second.Key();
                    i.keyEquivalentModifierMask = sc->second.modifiers;
                }
                else if(m_TagToAction.find(tag) != m_TagToAction.end())
                {
                    i.keyEquivalent = @"";
                    i.keyEquivalentModifierMask = 0;
                }
            }
        }
    }
}

void ActionsShortcutsManager::ReadOverrides(NSArray *_dict)
{
    m_ShortCutsOverrides.clear();
    
    if(_dict.count % 2 != 0)
        return;

    for(int ind = 0; ind < _dict.count; ind += 2)
    {
        NSString *key = [_dict objectAtIndex:ind];
        NSString *obj = [_dict objectAtIndex:ind+1];

        auto i = m_ActionToTag.find(key.UTF8String);
        if(i == m_ActionToTag.end())
            continue;
        
        if([obj isEqualToString:@"default"])
            continue;
        
        if( ShortCut sc{obj} )
            m_ShortCutsOverrides[i->second] = sc;
    }
}

void ActionsShortcutsManager::WriteOverrides(NSMutableArray *_dict) const
{
    for(auto &i: m_ActionsTags) {
        int tag = i.second;
        auto scover = m_ShortCutsOverrides.find(tag);
        if(scover != end(m_ShortCutsOverrides)) {
            [_dict addObject:[NSString stringWithUTF8StdString:i.first]];
            [_dict addObject:[NSString stringWithUTF8StdString:scover->second.ToPersString()]];
        }
    }
}

ActionsShortcutsManager::ShortCut ActionsShortcutsManager::ShortCutFromAction(const string &_action) const
{
    int tag = TagFromAction(_action);
    if(tag <= 0)
        return {};
    return ShortCutFromTag(tag);
}

ActionsShortcutsManager::ShortCut ActionsShortcutsManager::ShortCutFromTag(int _tag) const
{
    auto sc_override = m_ShortCutsOverrides.find(_tag);
    if(sc_override != m_ShortCutsOverrides.end())
        return sc_override->second;
    
    auto sc_default = m_ShortCutsDefaults.find(_tag);
    if(sc_default != m_ShortCutsDefaults.end())
        return sc_default->second;
    
    return {};
}

ActionsShortcutsManager::ShortCut ActionsShortcutsManager::DefaultShortCutFromTag(int _tag) const
{
    auto sc_default = m_ShortCutsDefaults.find(_tag);
    if(sc_default != m_ShortCutsDefaults.end())
        return sc_default->second;
    
    return {};
}

bool ActionsShortcutsManager::SetShortCutOverride(const string &_action, const ShortCut& _sc)
{
    int tag = TagFromAction(_action);
    if( tag <= 0 )
        return false;
    
    if( m_ShortCutsDefaults[tag] == _sc ) {
        // hotkey is same as the default one
        if( m_ShortCutsOverrides.find(tag) != end(m_ShortCutsOverrides) ) {
            // if something was written as override - erase it
            m_ShortCutsOverrides.erase(tag);
            WriteOverridesToConfigFile(); // immediately write to config file
            m_LastChanged = machtime();
            return true;
        }
        return false;
    }
    
    auto now = m_ShortCutsOverrides.find(tag);
    if( now != end(m_ShortCutsOverrides) && now->second == _sc )
        return false; // nothing new, it's the same as currently in overrides
    
    m_ShortCutsOverrides[tag] = _sc;
    
    // immediately write to config file
    WriteOverridesToConfigFile();
    m_LastChanged = machtime();
    return true;
}

void ActionsShortcutsManager::RevertToDefaults()
{
    m_ShortCutsOverrides.clear();
    WriteOverridesToConfigFile();
    m_LastChanged = machtime();      
}

bool ActionsShortcutsManager::WriteOverridesToConfigFile() const
{
    NSMutableArray *overrides = [NSMutableArray new];
    WriteOverrides(overrides);

    return [overrides writeToFile:[NSString stringWithUTF8StdString:AppDelegate.me.configDirectory + g_OverridesConfigFile]
                       atomically:true];
}

const vector<pair<string,int>>& ActionsShortcutsManager::AllShortcuts() const
{
    return m_ActionsTags;
}

nanoseconds ActionsShortcutsManager::LastChanged() const
{
    return m_LastChanged;
}
