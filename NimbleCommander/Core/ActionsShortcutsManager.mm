// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/Config.h>
#include <Config/RapidJSON.h>
#include "ActionsShortcutsManager.h"

// this key should not exist in config defaults
static const auto g_OverridesConfigPath = "hotkeyOverrides_v1";

 // the persistance holy grail is below, change ids only in emergency case:
static const std::vector<std::pair<const char*,int>> g_ActionsTags = {
    {"menu.nimble_commander.about",                     10'000},
    {"menu.nimble_commander.preferences",               10'010},
    {"menu.nimble_commander.hide",                      10'020},
    {"menu.nimble_commander.hide_others",               10'030},
    {"menu.nimble_commander.show_all",                  10'040},
    {"menu.nimble_commander.quit",                      10'050},
    {"menu.nimble_commander.toggle_admin_mode",         10'070},
    {"menu.nimble_commander.active_license_file",       10'080},
    {"menu.nimble_commander.purchase_license",          10'090},
    {"menu.nimble_commander.purchase_pro_features",     10'100},
    {"menu.nimble_commander.restore_purchases",         10'110},
    {"menu.nimble_commander.registration_info",         10'120},
    
    {"menu.file.newwindow",                             11'000},
    {"menu.file.new_folder",                            11'090},
    {"menu.file.new_folder_with_selection",             11'100},
    {"menu.file.new_file",                              11'120},
    {"menu.file.new_tab",                               11'110},
    {"menu.file.enter",                                 11'010},
    {"menu.file.open_with_submenu",                     11'160},
    {"menu.file.always_open_with_submenu",              11'170},
    {"menu.file.open",                                  11'020},
    {"menu.file.reveal_in_opposite_panel",              11'021},
    {"menu.file.reveal_in_opposite_panel_tab",          11'024},
    {"menu.file.feed_filename_to_terminal",             11'022},
    {"menu.file.feed_filenames_to_terminal",            11'023},
    {"menu.file.calculate_sizes",                       11'030},
    {"menu.file.calculate_all_sizes",                   11'031},
    {"menu.file.calculate_checksum",                    11'080},
    {"menu.file.duplicate",                             11'150},
    {"menu.file.add_to_favorites",                      11'140},
    {"menu.file.close_window",                          11'041},
    {"menu.file.close",                                 11'040},
    {"menu.file.close_other_tabs",                      11'180},        
    {"menu.file.find",                                  11'050},
    {"menu.file.find_next",                             11'051},
    {"menu.file.find_with_spotlight",                   11'130},
    {"menu.file.page_setup",                            11'060},
    {"menu.file.print",                                 11'070},
    
    {"menu.edit.copy",                                  12'000},
    {"menu.edit.paste",                                 12'010},
    {"menu.edit.move_here",                             12'050},
    {"menu.edit.select_all",                            12'020},
    {"menu.edit.deselect_all",                          12'030},
    {"menu.edit.invert_selection",                      12'040},

    {"menu.view.switch_dual_single_mode",               13'260},
    {"menu.view.swap_panels",                           13'020},
    {"menu.view.sync_panels",                           13'030},
    {"menu.view.refresh",                               13'040},
    {"menu.view.toggle_layout_1",                       13'050},
    {"menu.view.toggle_layout_2",                       13'051},
    {"menu.view.toggle_layout_3",                       13'052},
    {"menu.view.toggle_layout_4",                       13'053},
    {"menu.view.toggle_layout_5",                       13'054},
    {"menu.view.toggle_layout_6",                       13'055},
    {"menu.view.toggle_layout_7",                       13'056},
    {"menu.view.toggle_layout_8",                       13'057},
    {"menu.view.toggle_layout_9",                       13'058},
    {"menu.view.toggle_layout_10",                      13'059},
    {"menu.view.sorting_by_name",                       13'090},
    {"menu.view.sorting_by_extension",                  13'100},
    {"menu.view.sorting_by_modify_time",                13'110},
    {"menu.view.sorting_by_size",                       13'120},
    {"menu.view.sorting_by_creation_time",              13'130},
    {"menu.view.sorting_by_added_time",                 13'131},
    {"menu.view.sorting_view_hidden",                   13'140},
    {"menu.view.sorting_separate_folders",              13'150},
    {"menu.view.sorting_extensionless_folders",         13'270},
    {"menu.view.sorting_case_sensitive",                13'160},
    {"menu.view.sorting_numeric_comparison",            13'170},
    {"menu.view.show_tabs",                             13'179},
    {"menu.view.show_toolbar",                          13'180},
    {"menu.view.show_terminal",                         13'190},
    {"menu.view.panels_position.move_up",               13'200},
    {"menu.view.panels_position.move_down",             13'210},
    {"menu.view.panels_position.move_left",             13'220},
    {"menu.view.panels_position.move_right",            13'230},
    {"menu.view.panels_position.showpanels",            13'240},
    {"menu.view.panels_position.focusterminal",         13'250},
    
    {"menu.go.back",                                    14'000},
    {"menu.go.forward",                                 14'010},
    {"menu.go.enclosing_folder",                        14'020},
    {"menu.go.into_folder",                             14'030},
    {"menu.go.left_panel",                              14'260},
    {"menu.go.right_panel",                             14'270},
    {"menu.go.documents",                               14'040},
    {"menu.go.desktop",                                 14'050},
    {"menu.go.downloads",                               14'060},
    {"menu.go.home",                                    14'070},
    {"menu.go.library",                                 14'080},
    {"menu.go.applications",                            14'090},
    {"menu.go.utilities",                               14'100},
    {"menu.go.root",                                    14'150},
    {"menu.go.processes_list",                          14'120},
    {"menu.go.favorites.manage",                        14'210},
  /*{"menu.go.frequent.clear", NOT WIRED AT THE MOMENT  14'220},*/
    {"menu.go.restore_last_closed",                     14'290},
    {"menu.go.to_folder",                               14'110},
    {"menu.go.connect.ftp",                             14'130},
    {"menu.go.connect.sftp",                            14'140},
    {"menu.go.connect.webdav",                          14'280},
    {"menu.go.connect.lanshare",                        14'230},
    {"menu.go.connect.dropbox",                         14'250},
    {"menu.go.connect.network_server",                  14'240},
    {"menu.go.quick_lists.parent_folders",              14'160},
    {"menu.go.quick_lists.history",                     14'170},
    {"menu.go.quick_lists.favorites",                   14'180},
    {"menu.go.quick_lists.volumes",                     14'190},
    {"menu.go.quick_lists.connections",                 14'200},
    
    {"menu.command.system_overview",                    15'000},
    {"menu.command.volume_information",                 15'010},
    {"menu.command.file_attributes",                    15'020},
    {"menu.command.open_xattr",                         15'230},
    {"menu.command.copy_file_name",                     15'030},
    {"menu.command.copy_file_path",                     15'040},
    {"menu.command.select_with_mask",                   15'050},
    {"menu.command.select_with_extension",              15'051},
    {"menu.command.deselect_with_mask",                 15'060},
    {"menu.command.deselect_with_extension",            15'061},
    {"menu.command.quick_look",                         15'070},
    {"menu.command.internal_viewer",                    15'080},
    {"menu.command.external_editor",                    15'081},
    {"menu.command.eject_volume",                       15'090},
    {"menu.command.batch_rename",                       15'220},
    {"menu.command.copy_to",                            15'110},
    {"menu.command.copy_as",                            15'120},
    {"menu.command.move_to",                            15'130},
    {"menu.command.move_as",                            15'140},
    {"menu.command.rename_in_place",                    15'141},
    {"menu.command.create_directory",                   15'150},
    {"menu.command.move_to_trash",                      15'160},
    {"menu.command.delete",                             15'170},
    {"menu.command.delete_permanently",                 15'180},
    {"menu.command.compress_here",                      15'100},
    {"menu.command.compress_to_opposite",               15'101},
    {"menu.command.link_create_soft",                   15'190},
    {"menu.command.link_create_hard",                   15'200},
    {"menu.command.link_edit",                          15'210},
        
    {"menu.window.minimize",                            16'000},
    {"menu.window.fullscreen",                          16'010},
    {"menu.window.zoom",                                16'020},
    {"menu.window.show_previous_tab",                   16'040},
    {"menu.window.show_next_tab",                       16'050},
    {"menu.window.show_vfs_list",                       16'060},
    {"menu.window.bring_all_to_front",                  16'030},
    
    /**
    17'xxx block is used for Menu->Help tags, but is not wired into Shortcuts now
    17'000 - Nimble Commander Help
    17'010 - Visit Forum
    **/

    {"panel.move_up",                                   100'000},
    {"panel.move_down",                                 100'010},
    {"panel.move_left",                                 100'020},
    {"panel.move_right",                                100'030},
    {"panel.move_first",                                100'040},
    {"panel.scroll_first",                              100'041},
    {"panel.move_last",                                 100'050},
    {"panel.scroll_last",                               100'051},
    {"panel.move_next_page",                            100'060},
    {"panel.scroll_next_page",                          100'061},
    {"panel.move_prev_page",                            100'070},
    {"panel.scroll_prev_page",                          100'071},
    {"panel.move_next_and_invert_selection",            100'080},
    {"panel.invert_item_selection",                     100'081},
    {"panel.go_into_enclosing_folder",                  100'120},
    {"panel.go_into_folder",                            100'130},
    {"panel.go_root",                                   100'090},
    {"panel.go_home",                                   100'100},
    {"panel.show_preview",                              100'110},
    {"panel.show_previous_tab",                         100'140},
    {"panel.show_next_tab",                             100'150},
    {"panel.show_tab_no_1",                             100'160},
    {"panel.show_tab_no_2",                             100'161},
    {"panel.show_tab_no_3",                             100'162},
    {"panel.show_tab_no_4",                             100'163},
    {"panel.show_tab_no_5",                             100'164},
    {"panel.show_tab_no_6",                             100'165},
    {"panel.show_tab_no_7",                             100'166},
    {"panel.show_tab_no_8",                             100'167},
    {"panel.show_tab_no_9",                             100'168},
    {"panel.show_tab_no_10",                            100'169},
};


static const std::vector<std::pair<const char*, const char*>> g_DefaultShortcuts = {
    {"menu.nimble_commander.about",                         u8""        },
    {"menu.nimble_commander.preferences",                   u8"⌘,"      }, // cmd+,
    {"menu.nimble_commander.toggle_admin_mode",             u8""        },
    {"menu.nimble_commander.hide",                          u8"⌘h"      }, // cmd+h
    {"menu.nimble_commander.hide_others",                   u8"⌥⌘h"     }, // cmd+alt+h
    {"menu.nimble_commander.show_all",                      u8""        },
    {"menu.nimble_commander.quit",                          u8"⌘q"      }, // cmd+q
    {"menu.nimble_commander.active_license_file",           u8""        },
    {"menu.nimble_commander.purchase_license",              u8""        },
    {"menu.nimble_commander.purchase_pro_features",         u8""        },
    {"menu.nimble_commander.restore_purchases",             u8""        },
    {"menu.nimble_commander.registration_info",             u8""        },

    {"menu.file.newwindow",                                 u8"⌘n"      }, // cmd+n
    {"menu.file.new_folder",                                u8"⇧⌘n"     }, // cmd+shift+n
    {"menu.file.new_folder_with_selection",                 u8"^⌘n"     }, // cmd+ctrl+n
    {"menu.file.new_file",                                  u8"⌥⌘n"     }, // cmd+alt+n
    {"menu.file.new_tab",                                   u8"⌘t"      }, // cmd+t
    {"menu.file.enter",                                     u8"\\r"     }, // ↵
    {"menu.file.open_with_submenu",                         u8""        }, //
    {"menu.file.always_open_with_submenu",                  u8"⌥"       }, // alt
    {"menu.file.open",                                      u8"⇧\\r"    }, // shift+↵
    {"menu.file.reveal_in_opposite_panel",                  u8"⌥\\r"    }, // alt+↵
    {"menu.file.reveal_in_opposite_panel_tab",              u8"⌥⌘\\r"   }, // alt+cmd+↵
    {"menu.file.calculate_sizes",                           u8"⇧⌥\\r"   }, // shift+alt+↵
    {"menu.file.calculate_all_sizes",                       u8"⇧^\\r"   }, // shift+ctrl+↵
    {"menu.file.feed_filename_to_terminal",                 u8"^⌥\\r"   }, // ctrl+alt+↵
    {"menu.file.feed_filenames_to_terminal",                u8"^⌥⌘\\r"  }, // ctrl+alt+cmd+↵
    {"menu.file.calculate_checksum",                        u8"⇧⌘k"     }, // shift+cmd+k
    {"menu.file.duplicate",                                 u8"⌘d"      }, // cmd+d
    {"menu.file.add_to_favorites",                          u8"⌘b"      }, // cmd+b
    {"menu.file.close_window",                              u8"⇧⌘w"     }, // shift+cmd+w
    {"menu.file.close",                                     u8"⌘w"      }, // cmd+w
    {"menu.file.close_other_tabs",                          u8"⌥⌘w"     }, // alt+cmd+w   
    {"menu.file.find",                                      u8"⌘f"      }, // cmd+f
    {"menu.file.find_next",                                 u8"⌘g"      }, // cmd+g
    {"menu.file.find_with_spotlight",                       u8"⌥⌘f"     }, // alt+cmd+f
    {"menu.file.page_setup",                                u8"⇧⌘p"     }, // shift+cmd+p
    {"menu.file.print",                                     u8"⌘p"      }, // cmd+p

    {"menu.edit.copy",                                      u8"⌘c"      }, // cmd+c
    {"menu.edit.paste",                                     u8"⌘v"      }, // cmd+v
    {"menu.edit.move_here",                                 u8"⌥⌘v"     }, // alt+cmd+v
    {"menu.edit.select_all",                                u8"⌘a"      }, // cmd+a
    {"menu.edit.deselect_all",                              u8"⌥⌘a"     }, // alt+cmd+a
    {"menu.edit.invert_selection",                          u8"^⌘a"     }, // ctrl+cmd+a

    {"menu.view.switch_dual_single_mode",                   u8"⇧⌘p"     }, // shift+cmd+p
    {"menu.view.swap_panels",                               u8"⌘u"      }, // cmd+u
    {"menu.view.sync_panels",                               u8"⌥⌘u"     }, // alt+cmd+u
    {"menu.view.refresh",                                   u8"⌘r"      }, // cmd+r
    {"menu.view.toggle_layout_1",                       	u8"^1"      }, // ctrl+1
    {"menu.view.toggle_layout_2",                           u8"^2"      }, // ctrl+2
    {"menu.view.toggle_layout_3",                           u8"^3"      }, // ctrl+3
    {"menu.view.toggle_layout_4",                           u8"^4"      }, // ctrl+4
    {"menu.view.toggle_layout_5",                           u8"^5"      }, // ctrl+5
    {"menu.view.toggle_layout_6",                           u8"^6"      }, // ctrl+6
    {"menu.view.toggle_layout_7",                           u8"^7"      }, // ctrl+7
    {"menu.view.toggle_layout_8",                           u8"^8"      }, // ctrl+8
    {"menu.view.toggle_layout_9",                           u8"^9"      }, // ctrl+9
    {"menu.view.toggle_layout_10",                          u8"^0"      }, // ctrl+0
    {"menu.view.sorting_by_name",                           u8"^⌘1"     }, // ctrl+cmd+1
    {"menu.view.sorting_by_extension",                      u8"^⌘2"     }, // ctrl+cmd+2
    {"menu.view.sorting_by_modify_time",                    u8"^⌘3"     }, // ctrl+cmd+3
    {"menu.view.sorting_by_size",                           u8"^⌘4"     }, // ctrl+cmd+4
    {"menu.view.sorting_by_creation_time",                  u8"^⌘5"     }, // ctrl+cmd+5
    {"menu.view.sorting_by_added_time",                     u8"^⌘6"     }, // ctrl+cmd+6
    {"menu.view.sorting_view_hidden",                       u8"⇧⌘."     }, // shift+cmd+.
    {"menu.view.sorting_separate_folders",                  u8""        },
    {"menu.view.sorting_extensionless_folders",             u8""        },
    {"menu.view.sorting_case_sensitive",                    u8""        },
    {"menu.view.sorting_numeric_comparison",                u8""        },
    {"menu.view.panels_position.move_up",                   u8"^⌥\uF700"}, // ctrl+alt+↑
    {"menu.view.panels_position.move_down",                 u8"^⌥\uF701"}, // ctrl+alt+↓
    {"menu.view.panels_position.move_left",                 u8"^⌥\uF702"}, // ctrl+alt+←
    {"menu.view.panels_position.move_right",                u8"^⌥\uF703"}, // ctrl+alt+→
    {"menu.view.panels_position.showpanels",                u8"^⌥o"     }, // ctrl+alt+o
    {"menu.view.panels_position.focusterminal",             u8"^⌥\t"    }, // ctrl+alt+⇥
    {"menu.view.show_tabs",                                 u8"⇧⌘t"     }, // shift+cmd+t
    {"menu.view.show_toolbar",                              u8"⌥⌘t"     }, // alt+cmd+t
    {"menu.view.show_terminal",                             u8"⌥⌘o"     }, // alt+cmd+o
    
    {"menu.go.back",                                        u8"⌘["      }, // cmd+[
    {"menu.go.forward",                                     u8"⌘]"      }, // cmd+]
    {"menu.go.enclosing_folder",                            u8"⌘\uF700" }, // cmd+↑
    {"menu.go.into_folder",                                 u8"⌘\uF701" }, // cmd+↓
    {"menu.go.left_panel",                                  u8"\uF704"  }, // F1
    {"menu.go.right_panel",                                 u8"\uF705"  }, // F2
    {"menu.go.documents",                                   u8"⇧⌘o"     }, // shift+cmd+o
    {"menu.go.desktop",                                     u8"⇧⌘d"     }, // shift+cmd+d
    {"menu.go.downloads",                                   u8"⌥⌘l"     }, // alt+cmd+l
    {"menu.go.home",                                        u8"⇧⌘h"     }, // shift+cmd+h
    {"menu.go.library",                                     u8""        },
    {"menu.go.applications",                                u8"⇧⌘a"     }, // shift+cmd+a
    {"menu.go.utilities",                                   u8"⇧⌘u"     }, // shift+cmd+u
    {"menu.go.processes_list",                              u8"⌥⌘p"     }, // alt+cmd+p
    {"menu.go.favorites.manage",                            u8"^⌘b"     }, // ctrl+cmd+b
    {"menu.go.to_folder",                                   u8"⇧⌘g"     }, // shift+cmd+g
    {"menu.go.restore_last_closed",                         u8"⇧⌘r"     }, // shift+cmd+R
    {"menu.go.connect.ftp",                                 u8""        },
    {"menu.go.connect.sftp",                                u8""        },
    {"menu.go.connect.webdav",                              u8""        },
    {"menu.go.connect.lanshare",                            u8""        },
    {"menu.go.connect.dropbox",                             u8""        },
    {"menu.go.connect.network_server",                      u8"⌘k"      }, // cmd+k
    {"menu.go.root",                                        u8""        },
    {"menu.go.quick_lists.parent_folders",                  u8"⌘1"      }, // cmd+1
    {"menu.go.quick_lists.history",                         u8"⌘2"      }, // cmd+2
    {"menu.go.quick_lists.favorites",                       u8"⌘3"      }, // cmd+3
    {"menu.go.quick_lists.volumes",                         u8"⌘4"      }, // cmd+4
    {"menu.go.quick_lists.connections",                     u8"⌘5"      }, // cmd+5

    {"menu.command.system_overview",                        u8"⌘l"      }, // cmd+l
    {"menu.command.volume_information",                     u8""        },
    {"menu.command.file_attributes",                        u8"^a"      }, // ctrl+a
    {"menu.command.copy_file_name",                         u8"⇧⌘c"     }, // shift+cmd+c
    {"menu.command.copy_file_path",                         u8"⌥⌘c"     }, // alt+cmd+c
    {"menu.command.select_with_mask",                       u8"⌘="      }, // cmd+=
    {"menu.command.select_with_extension",                  u8"⌥⌘="     }, // alt+cmd+=
    {"menu.command.deselect_with_mask",                     u8"⌘-"      }, // cmd+-
    {"menu.command.deselect_with_extension",                u8"⌥⌘-"     }, // alt+cmd+-
    {"menu.command.quick_look",                             u8"⌘y"      }, // cmd+y
    {"menu.command.internal_viewer",                        u8"⌥\uF706" }, // alt+F3
    {"menu.command.external_editor",                        u8"\uF707"  }, // F4
    {"menu.command.eject_volume",                           u8"⌘e"      }, // cmd+e
    {"menu.command.batch_rename",                           u8"^m"      }, // ctrl+m
    {"menu.command.copy_to",                                u8"\uF708"  }, // F5
    {"menu.command.copy_as",                                u8"⇧\uF708" }, // shift+F5
    {"menu.command.move_to",                                u8"\uF709"  }, // F6
    {"menu.command.move_as",                                u8"⇧\uF709" }, // shift+F6
    {"menu.command.rename_in_place",                        u8"^\uF709" }, // ctrl+F6
    {"menu.command.create_directory",                       u8"\uF70a"  }, // F7
    {"menu.command.move_to_trash",                          u8"⌘\u007f" }, // cmd+backspace
    {"menu.command.delete",                                 u8"\uF70b"  }, // F8
    {"menu.command.delete_permanently",                     u8"⇧\uF70b" }, // shift+F8
    {"menu.command.compress_here",                          u8"\uF70c"  }, // F9
    {"menu.command.compress_to_opposite",                   u8"⇧\uF70c" }, // shift+F9
    {"menu.command.link_create_soft",                       u8""        },
    {"menu.command.link_create_hard",                       u8""        },
    {"menu.command.link_edit",                              u8""        },
    {"menu.command.open_xattr",                             u8"⌥⌘x"     }, // alt+cmd+x

    {"menu.window.minimize",                                u8"⌘m"      }, // cmd+m
    {"menu.window.fullscreen",                              u8"^⌘f"     }, // ctrl+cmd+f
    {"menu.window.zoom",                                    u8""        },
    {"menu.window.show_previous_tab",                       u8"⇧^\t"    }, // shift+ctrl+tab
    {"menu.window.show_next_tab",                           u8"^\t"     }, // ctrl+tab
    {"menu.window.show_vfs_list",                           u8""        },
    {"menu.window.bring_all_to_front",                      u8""        },

    {"panel.move_up",                                       u8"\uF700"  }, // up
    {"panel.move_down",                                     u8"\uF701"  }, // down
    {"panel.move_left",                                     u8"\uF702"  }, // left
    {"panel.move_right",                                    u8"\uF703"  }, // right
    {"panel.move_first",                                    u8"\uF729"  }, // home
    {"panel.scroll_first",                                  u8"⌥\uF729" }, // alt+home
    {"panel.move_last",                                     u8"\uF72B"  }, // end
    {"panel.scroll_last",                                   u8"⌥\uF72B" }, // alt+end
    {"panel.move_next_page",                                u8"\uF72D"  }, // page down
    {"panel.scroll_next_page",                              u8"⌥\uF72D" }, // alt+page down
    {"panel.move_prev_page",                                u8"\uF72C"  }, // page up
    {"panel.scroll_prev_page",                              u8"⌥\uF72C" }, // alt+page up
    {"panel.move_next_and_invert_selection",                u8"\u0003"  }, // insert
    {"panel.invert_item_selection",                         u8""        },
    {"panel.go_into_enclosing_folder",                      u8""        },
    {"panel.go_into_folder",                                u8""        },
    {"panel.go_root",                                       u8"/"       }, // slash
    {"panel.go_home",                                       u8"~"       }, // tilde
    {"panel.show_preview",                                  u8" "       }, // space
    {"panel.show_previous_tab",                             u8"⇧⌘["     }, // shift+cmd+[
    {"panel.show_next_tab",                                 u8"⇧⌘]"     }, // shift+cmd+]
    {"panel.show_tab_no_1",                                 u8""        },
    {"panel.show_tab_no_2",                                 u8""        },
    {"panel.show_tab_no_3",                                 u8""        },
    {"panel.show_tab_no_4",                                 u8""        },
    {"panel.show_tab_no_5",                                 u8""        },
    {"panel.show_tab_no_6",                                 u8""        },
    {"panel.show_tab_no_7",                                 u8""        },
    {"panel.show_tab_no_8",                                 u8""        },
    {"panel.show_tab_no_9",                                 u8""        },
    {"panel.show_tab_no_10",                                u8""        },
    
};

ActionsShortcutsManager::ShortCutsUpdater::
        ShortCutsUpdater(std::initializer_list<ShortCut*> _hotkeys,
                         std::initializer_list<const char*> _actions )
{
    if( _hotkeys.size() != _actions.size() )
        throw std::logic_error("_hotkeys.size() != _actions.size()");
    
    auto &am = ActionsShortcutsManager::Instance();
    for( int i = 0, e = (int)_hotkeys.size(); i != e; ++i )
        m_Pets.emplace_back( _hotkeys.begin()[i], am.TagFromAction(_actions.begin()[i]) );
    m_Ticket = am.ObserveChanges( [this]{ CheckAndUpdate(); } );
    
    CheckAndUpdate();
}

void ActionsShortcutsManager::ShortCutsUpdater::CheckAndUpdate() const
{
    auto &am = ActionsShortcutsManager::Instance();
    for( auto &i: m_Pets )
        *i.first = am.ShortCutFromTag(i.second);
}

ActionsShortcutsManager::ActionsShortcutsManager()
{
    for( auto &p: g_ActionsTags) {
        m_TagToAction[p.second] = p.first;
        m_ActionToTag[p.first] = p.second;
    }

    for( auto &d: g_DefaultShortcuts) {
        auto i = m_ActionToTag.find( d.first );
        if( i != end(m_ActionToTag) )
            m_ShortCutsDefaults[i->second] = d.second;
    }
    
    ReadOverrideFromConfig();
}

ActionsShortcutsManager &ActionsShortcutsManager::Instance()
{
    static ActionsShortcutsManager *manager = new ActionsShortcutsManager;
    return *manager;
}

int ActionsShortcutsManager::TagFromAction(const std::string &_action) const
{
    auto it = m_ActionToTag.find(_action);
    if( it != end(m_ActionToTag) )
        return it->second;
    return -1;
}

int ActionsShortcutsManager::TagFromAction(const char *_action) const
{
    auto it = m_ActionToTag.find(_action);
    if( it != end(m_ActionToTag) )
        return it->second;
    return -1;
}

std::string ActionsShortcutsManager::ActionFromTag(int _tag) const
{
    auto it = m_TagToAction.find(_tag);
    if( it != end(m_TagToAction) )
        return it->second;
    return "";
}

void ActionsShortcutsManager::SetMenuShortCuts(NSMenu *_menu) const
{
    NSArray *array = _menu.itemArray;
    for( NSMenuItem *i: array ) {
        if( i.submenu != nil ) {
            SetMenuShortCuts(i.submenu);
        }
        else {
            int tag = (int)i.tag;

            auto scover = m_ShortCutsOverrides.find(tag);
            if( scover != m_ShortCutsOverrides.end() ) {
                i.keyEquivalent = scover->second.Key();
                i.keyEquivalentModifierMask = scover->second.modifiers;
            }
            else {
                auto sc = m_ShortCutsDefaults.find(tag);
                if( sc != m_ShortCutsDefaults.end() ) {
                    i.keyEquivalent = sc->second.Key();
                    i.keyEquivalentModifierMask = sc->second.modifiers;
                }
                else if( m_TagToAction.find(tag) != m_TagToAction.end() ) {
                    i.keyEquivalent = @"";
                    i.keyEquivalentModifierMask = 0;
                }
            }
        }
    }
}

void ActionsShortcutsManager::ReadOverrideFromConfig()
{
    using namespace rapidjson;

    auto v = GlobalConfig().Get( g_OverridesConfigPath );
    if( v.GetType() != kObjectType )
        return;
    
    m_ShortCutsOverrides.clear();
    for( auto i = v.MemberBegin(), e = v.MemberEnd(); i != e; ++i )
        if( i->name.GetType() == kStringType && i->value.GetType() == kStringType ) {
            auto att = m_ActionToTag.find( i->name.GetString() );
            if( att != m_ActionToTag.end() )
                m_ShortCutsOverrides[att->second] = i->value.GetString();
        }
}

ActionsShortcutsManager::ShortCut ActionsShortcutsManager::ShortCutFromAction
        (const std::string &_action) const
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

bool ActionsShortcutsManager::SetShortCutOverride(const std::string &_action, const ShortCut& _sc)
{
    const auto tag = TagFromAction(_action);
    if( tag <= 0 )
        return false;
    
    if( m_ShortCutsDefaults[tag] == _sc ) {
        // hotkey is same as the default one
        if( m_ShortCutsOverrides.count(tag) ) {
            // if something was written as override - erase it
            m_ShortCutsOverrides.erase( tag );
            
            // immediately write to config file
            WriteOverridesToConfig();
            FireObservers();
            return true;
        }
        return false;
    }
    
    const auto current_override = m_ShortCutsOverrides.find(tag);
    if( current_override != end(m_ShortCutsOverrides) )
        if( current_override->second == _sc )
            return false; // nothing new, it's the same as currently in overrides

    m_ShortCutsOverrides[tag] = _sc;
    
    // immediately write to config file
    WriteOverridesToConfig();
    FireObservers();
    return true;
}

void ActionsShortcutsManager::RevertToDefaults()
{
    m_ShortCutsOverrides.clear();
    WriteOverridesToConfig();
    FireObservers();
}

void ActionsShortcutsManager::WriteOverridesToConfig() const
{
    using namespace rapidjson;
    nc::config::Value overrides{ kObjectType };
    
    for( auto &i: g_ActionsTags ) {
        auto scover = m_ShortCutsOverrides.find(i.second);
        if( scover != end(m_ShortCutsOverrides) )
            overrides.AddMember(
                                nc::config::MakeStandaloneString(i.first),
                                nc::config::MakeStandaloneString(scover->second.ToPersString()),
                                nc::config::g_CrtAllocator);
    }
    
    GlobalConfig().Set( g_OverridesConfigPath, overrides );
}

const std::vector<std::pair<const char*,int>>& ActionsShortcutsManager::AllShortcuts() const
{
    return g_ActionsTags;
}

ActionsShortcutsManager::ObservationTicket ActionsShortcutsManager::
    ObserveChanges(std::function<void()> _callback)
{
    return ObservableBase::AddObserver(_callback);
}
