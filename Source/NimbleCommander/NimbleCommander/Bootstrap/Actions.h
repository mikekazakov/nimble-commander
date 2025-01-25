// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <utility>

namespace nc::bootstrap {

// clang-format off
// the persistance holy grail is below, change ids only in emergency case:
static constexpr std::pair<const char*,int> g_ActionsTags[] = {
    {"menu.nimble_commander.about",                     10'000},
    {"menu.nimble_commander.preferences",               10'010},
    {"menu.nimble_commander.hide",                      10'020},
    {"menu.nimble_commander.hide_others",               10'030},
    {"menu.nimble_commander.show_all",                  10'040},
    {"menu.nimble_commander.quit",                      10'050},
    {"menu.nimble_commander.toggle_admin_mode",         10'070},
    {"menu.nimble_commander.active_license_file",       10'080}, // no longer used
    {"menu.nimble_commander.purchase_license",          10'090}, // no longer used
    {"menu.nimble_commander.purchase_pro_features",     10'100}, // no longer used
    {"menu.nimble_commander.restore_purchases",         10'110}, // no longer used
    {"menu.nimble_commander.registration_info",         10'120}, // no longer used
    
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
    {"menu.file.calculate_checksum",                    11'080}, // no longer used
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
    {"menu.view.sorting_by_accessed_time",              13'132},
    {"menu.view.sorting_view_hidden",                   13'140},
    {"menu.view.sorting_separate_folders",              13'150},
    {"menu.view.sorting_extensionless_folders",         13'270},
//  {"menu.view.sorting_case_sensitive",                13'160}, // no longer used
//  {"menu.view.sorting_numeric_comparison",            13'170}, // no longer used
    {"menu.view.sorting_natural",                       13'161},
    {"menu.view.sorting_case_insens",                   13'162},
    {"menu.view.sorting_case_sens",                     13'163},
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
    {"menu.go.follow_symlink",                          14'300},
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
    {"menu.go.quick_lists.tags",                        14'310},
    
    {"menu.command.system_overview",                    15'000},
    {"menu.command.volume_information",                 15'010},
    {"menu.command.file_attributes",                    15'020},
    {"menu.command.open_xattr",                         15'230},
    {"menu.command.copy_file_name",                     15'030},
    {"menu.command.copy_file_path",                     15'040},
    {"menu.command.copy_file_directory",                15'240},
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
//  {"menu.window.show_vfs_list",                       16'060}, // no longer used
    {"menu.window.bring_all_to_front",                  16'030},
    
    /**
    17'xxx block is used for Menu->Help tags, but is not wired into Shortcuts now
    17'000 - Nimble Commander Help
    17'010 - Visit Forum
    17'020 - Debug submenu
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
    {"panel.focus_left_panel",                          100'170},
    {"panel.focus_right_panel",                         100'171},
    {"panel.show_context_menu",                         100'180},
        
    {"viewer.toggle_text",                              101'000},
    {"viewer.toggle_hex",                               101'001},
    {"viewer.toggle_preview",                           101'002},
//  {"viewer.show_settings",                            101'003}, // no longer used
    {"viewer.show_goto",                                101'004},
    {"viewer.refresh",                                  101'005}
};

static constinit std::pair<const char*, const char*> g_DefaultActionShortcuts[] = {
    {"menu.nimble_commander.about",                         ""        },
    {"menu.nimble_commander.preferences",                   "⌘,"      }, // cmd+,
    {"menu.nimble_commander.toggle_admin_mode",             ""        },
    {"menu.nimble_commander.hide",                          "⌘h"      }, // cmd+h
    {"menu.nimble_commander.hide_others",                   "⌥⌘h"     }, // cmd+alt+h
    {"menu.nimble_commander.show_all",                      ""        },
    {"menu.nimble_commander.quit",                          "⌘q"      }, // cmd+q
    {"menu.nimble_commander.active_license_file",           ""        }, // no longer used
    {"menu.nimble_commander.purchase_license",              ""        }, // no longer used
    {"menu.nimble_commander.purchase_pro_features",         ""        }, // no longer used
    {"menu.nimble_commander.restore_purchases",             ""        }, // no longer used
    {"menu.nimble_commander.registration_info",             ""        }, // no longer used

    {"menu.file.newwindow",                                 "⌘n"      }, // cmd+n
    {"menu.file.new_folder",                                "⇧⌘n"     }, // cmd+shift+n
    {"menu.file.new_folder_with_selection",                 "^⌘n"     }, // cmd+ctrl+n
    {"menu.file.new_file",                                  "⌥⌘n"     }, // cmd+alt+n
    {"menu.file.new_tab",                                   "⌘t"      }, // cmd+t
    {"menu.file.enter",                                     "\\r"     }, // ↵
    {"menu.file.open_with_submenu",                         ""        }, //
    {"menu.file.always_open_with_submenu",                  "⌥"       }, // alt
    {"menu.file.open",                                      "⇧\\r"    }, // shift+↵
    {"menu.file.reveal_in_opposite_panel",                  "⌥\\r"    }, // alt+↵
    {"menu.file.reveal_in_opposite_panel_tab",              "⌥⌘\\r"   }, // alt+cmd+↵
    {"menu.file.calculate_sizes",                           "⇧⌥\\r"   }, // shift+alt+↵
    {"menu.file.calculate_all_sizes",                       "⇧^\\r"   }, // shift+ctrl+↵
    {"menu.file.feed_filename_to_terminal",                 "^⌥\\r"   }, // ctrl+alt+↵
    {"menu.file.feed_filenames_to_terminal",                "^⌥⌘\\r"  }, // ctrl+alt+cmd+↵
//  {"menu.file.calculate_checksum",                        "⇧⌘k"     }, // shift+cmd+k, no longer used
    {"menu.file.duplicate",                                 "⌘d"      }, // cmd+d
    {"menu.file.add_to_favorites",                          "⌘b"      }, // cmd+b
    {"menu.file.close_window",                              "⇧⌘w"     }, // shift+cmd+w
    {"menu.file.close",                                     "⌘w"      }, // cmd+w
    {"menu.file.close_other_tabs",                          "⌥⌘w"     }, // alt+cmd+w
    {"menu.file.find",                                      "⌘f"      }, // cmd+f
    {"menu.file.find_next",                                 "⌘g"      }, // cmd+g
    {"menu.file.find_with_spotlight",                       "⌥⌘f"     }, // alt+cmd+f
    {"menu.file.page_setup",                                "⇧⌘p"     }, // shift+cmd+p
    {"menu.file.print",                                     "⌘p"      }, // cmd+p

    {"menu.edit.copy",                                      "⌘c"      }, // cmd+c
    {"menu.edit.paste",                                     "⌘v"      }, // cmd+v
    {"menu.edit.move_here",                                 "⌥⌘v"     }, // alt+cmd+v
    {"menu.edit.select_all",                                "⌘a"      }, // cmd+a
    {"menu.edit.deselect_all",                              "⌥⌘a"     }, // alt+cmd+a
    {"menu.edit.invert_selection",                          "^⌘a"     }, // ctrl+cmd+a

    {"menu.view.switch_dual_single_mode",                   "⇧⌘p"     }, // shift+cmd+p
    {"menu.view.swap_panels",                               "⌘u"      }, // cmd+u
    {"menu.view.sync_panels",                               "⌥⌘u"     }, // alt+cmd+u
    {"menu.view.refresh",                                   "⌘r"      }, // cmd+r
    {"menu.view.toggle_layout_1",                           "^1"      }, // ctrl+1
    {"menu.view.toggle_layout_2",                           "^2"      }, // ctrl+2
    {"menu.view.toggle_layout_3",                           "^3"      }, // ctrl+3
    {"menu.view.toggle_layout_4",                           "^4"      }, // ctrl+4
    {"menu.view.toggle_layout_5",                           "^5"      }, // ctrl+5
    {"menu.view.toggle_layout_6",                           "^6"      }, // ctrl+6
    {"menu.view.toggle_layout_7",                           "^7"      }, // ctrl+7
    {"menu.view.toggle_layout_8",                           "^8"      }, // ctrl+8
    {"menu.view.toggle_layout_9",                           "^9"      }, // ctrl+9
    {"menu.view.toggle_layout_10",                          "^0"      }, // ctrl+0
    {"menu.view.sorting_by_name",                           "^⌘1"     }, // ctrl+cmd+1
    {"menu.view.sorting_by_extension",                      "^⌘2"     }, // ctrl+cmd+2
    {"menu.view.sorting_by_modify_time",                    "^⌘3"     }, // ctrl+cmd+3
    {"menu.view.sorting_by_size",                           "^⌘4"     }, // ctrl+cmd+4
    {"menu.view.sorting_by_creation_time",                  "^⌘5"     }, // ctrl+cmd+5
    {"menu.view.sorting_by_added_time",                     "^⌘6"     }, // ctrl+cmd+6
    {"menu.view.sorting_by_accessed_time",                  "^⌘7"     }, // ctrl+cmd+7
    {"menu.view.sorting_view_hidden",                       "⇧⌘."     }, // shift+cmd+.
    {"menu.view.sorting_separate_folders",                  ""        },
    {"menu.view.sorting_extensionless_folders",             ""        },
//  {"menu.view.sorting_case_sensitive",                    ""        }, // no longer used
//  {"menu.view.sorting_numeric_comparison",                ""        }, // no longer used
    {"menu.view.sorting_natural",                           ""        },
    {"menu.view.sorting_case_insens",                       ""        },
    {"menu.view.sorting_case_sens",                         ""        },
    {"menu.view.panels_position.move_up",                   "^⌥\uF700"}, // ctrl+alt+↑
    {"menu.view.panels_position.move_down",                 "^⌥\uF701"}, // ctrl+alt+↓
    {"menu.view.panels_position.move_left",                 "^⌥\uF702"}, // ctrl+alt+←
    {"menu.view.panels_position.move_right",                "^⌥\uF703"}, // ctrl+alt+→
    {"menu.view.panels_position.showpanels",                "^⌥o"     }, // ctrl+alt+o
    {"menu.view.panels_position.focusterminal",             "^⌥\t"    }, // ctrl+alt+⇥
    {"menu.view.show_tabs",                                 "⇧⌘t"     }, // shift+cmd+t
    {"menu.view.show_toolbar",                              "⌥⌘t"     }, // alt+cmd+t
    {"menu.view.show_terminal",                             "⌥⌘o"     }, // alt+cmd+o
    
    {"menu.go.back",                                        "⌘["      }, // cmd+[
    {"menu.go.forward",                                     "⌘]"      }, // cmd+]
    {"menu.go.enclosing_folder",                            "⌘\uF700" }, // cmd+↑
    {"menu.go.into_folder",                                 "⌘\uF701" }, // cmd+↓
    {"menu.go.follow_symlink",                              "⌘\uF703" }, // cmd+→
    {"menu.go.left_panel",                                  "\uF704"  }, // F1
    {"menu.go.right_panel",                                 "\uF705"  }, // F2
    {"menu.go.documents",                                   "⇧⌘o"     }, // shift+cmd+o
    {"menu.go.desktop",                                     "⇧⌘d"     }, // shift+cmd+d
    {"menu.go.downloads",                                   "⌥⌘l"     }, // alt+cmd+l
    {"menu.go.home",                                        "⇧⌘h"     }, // shift+cmd+h
    {"menu.go.library",                                     ""        },
    {"menu.go.applications",                                "⇧⌘a"     }, // shift+cmd+a
    {"menu.go.utilities",                                   "⇧⌘u"     }, // shift+cmd+u
    {"menu.go.processes_list",                              "⌥⌘p"     }, // alt+cmd+p
    {"menu.go.favorites.manage",                            "^⌘b"     }, // ctrl+cmd+b
    {"menu.go.to_folder",                                   "⇧⌘g"     }, // shift+cmd+g
    {"menu.go.restore_last_closed",                         "⇧⌘r"     }, // shift+cmd+R
    {"menu.go.connect.ftp",                                 ""        },
    {"menu.go.connect.sftp",                                ""        },
    {"menu.go.connect.webdav",                              ""        },
    {"menu.go.connect.lanshare",                            ""        },
    {"menu.go.connect.dropbox",                             ""        },
    {"menu.go.connect.network_server",                      "⌘k"      }, // cmd+k
    {"menu.go.root",                                        ""        },
    {"menu.go.quick_lists.parent_folders",                  "⌘1"      }, // cmd+1
    {"menu.go.quick_lists.history",                         "⌘2"      }, // cmd+2
    {"menu.go.quick_lists.favorites",                       "⌘3"      }, // cmd+3
    {"menu.go.quick_lists.volumes",                         "⌘4"      }, // cmd+4
    {"menu.go.quick_lists.connections",                     "⌘5"      }, // cmd+5
    {"menu.go.quick_lists.tags",                            "⌘6"      }, // cmd+6

    {"menu.command.system_overview",                        "⌘l"      }, // cmd+l
    {"menu.command.volume_information",                     ""        },
    {"menu.command.file_attributes",                        "^a"      }, // ctrl+a
    {"menu.command.copy_file_name",                         "⇧⌘c"     }, // shift+cmd+c
    {"menu.command.copy_file_path",                         "⌥⌘c"     }, // alt+cmd+c
    {"menu.command.copy_file_directory",                    "⇧⌥⌘c"    }, // shift+alt+cmd+c
    {"menu.command.select_with_mask",                       "⌘="      }, // cmd+=
    {"menu.command.select_with_extension",                  "⌥⌘="     }, // alt+cmd+=
    {"menu.command.deselect_with_mask",                     "⌘-"      }, // cmd+-
    {"menu.command.deselect_with_extension",                "⌥⌘-"     }, // alt+cmd+-
    {"menu.command.quick_look",                             "⌘y"      }, // cmd+y
    {"menu.command.internal_viewer",                        "\uF706"  }, // F3
    {"menu.command.external_editor",                        "\uF707"  }, // F4
    {"menu.command.eject_volume",                           "⌘e"      }, // cmd+e
    {"menu.command.batch_rename",                           "^m"      }, // ctrl+m
    {"menu.command.copy_to",                                "\uF708"  }, // F5
    {"menu.command.copy_as",                                "⇧\uF708" }, // shift+F5
    {"menu.command.move_to",                                "\uF709"  }, // F6
    {"menu.command.move_as",                                "⇧\uF709" }, // shift+F6
    {"menu.command.rename_in_place",                        "^\uF709" }, // ctrl+F6
    {"menu.command.create_directory",                       "\uF70a"  }, // F7
    {"menu.command.move_to_trash",                          "⌘\u007f" }, // cmd+backspace
    {"menu.command.delete",                                 "\uF70b"  }, // F8
    {"menu.command.delete_permanently",                     "⇧\uF70b" }, // shift+F8
    {"menu.command.compress_here",                          "\uF70c"  }, // F9
    {"menu.command.compress_to_opposite",                   "⇧\uF70c" }, // shift+F9
    {"menu.command.link_create_soft",                       ""        },
    {"menu.command.link_create_hard",                       ""        },
    {"menu.command.link_edit",                              ""        },
    {"menu.command.open_xattr",                             "⌥⌘x"     }, // alt+cmd+x

    {"menu.window.minimize",                                "⌘m"      }, // cmd+m
    {"menu.window.fullscreen",                              "^⌘f"     }, // ctrl+cmd+f
    {"menu.window.zoom",                                    ""        },
    {"menu.window.show_previous_tab",                       "⇧^\t"    }, // shift+ctrl+tab
    {"menu.window.show_next_tab",                           "^\t"     }, // ctrl+tab
//  {"menu.window.show_vfs_list",                           ""        }, // no longer used
    {"menu.window.bring_all_to_front",                      ""        },

    {"panel.move_up",                                       "\uF700"  }, // up
    {"panel.move_down",                                     "\uF701"  }, // down
    {"panel.move_left",                                     "\uF702"  }, // left
    {"panel.move_right",                                    "\uF703"  }, // right
    {"panel.move_first",                                    "\uF729"  }, // home
    {"panel.scroll_first",                                  "⌥\uF729" }, // alt+home
    {"panel.move_last",                                     "\uF72B"  }, // end
    {"panel.scroll_last",                                   "⌥\uF72B" }, // alt+end
    {"panel.move_next_page",                                "\uF72D"  }, // page down
    {"panel.scroll_next_page",                              "⌥\uF72D" }, // alt+page down
    {"panel.move_prev_page",                                "\uF72C"  }, // page up
    {"panel.scroll_prev_page",                              "⌥\uF72C" }, // alt+page up
    {"panel.move_next_and_invert_selection",                "\u0003"  }, // insert
    {"panel.invert_item_selection",                         ""        },
    {"panel.go_into_enclosing_folder",                      "\u007f"  }, // backspace
    {"panel.go_into_folder",                                ""        },
    {"panel.go_root",                                       "/"       }, // slash
    {"panel.go_home",                                       "⇧~"      }, // shift+tilde
    {"panel.show_preview",                                  " "       }, // space
    {"panel.show_previous_tab",                             "⇧⌘{"     }, // shift+cmd+{
    {"panel.show_next_tab",                                 "⇧⌘}"     }, // shift+cmd+}
    {"panel.show_tab_no_1",                                 ""        },
    {"panel.show_tab_no_2",                                 ""        },
    {"panel.show_tab_no_3",                                 ""        },
    {"panel.show_tab_no_4",                                 ""        },
    {"panel.show_tab_no_5",                                 ""        },
    {"panel.show_tab_no_6",                                 ""        },
    {"panel.show_tab_no_7",                                 ""        },
    {"panel.show_tab_no_8",                                 ""        },
    {"panel.show_tab_no_9",                                 ""        },
    {"panel.show_tab_no_10",                                ""        },
    {"panel.focus_left_panel",                              "⇧⌘\uF702"}, // shift+cmd+left
    {"panel.focus_right_panel",                             "⇧⌘\uF703"}, // shift+cmd+right
    {"panel.show_context_menu",                             "^\\r"    }, // ctrl+↵
    
    {"viewer.toggle_text",                                  "⌘1"      }, // cmd+1
    {"viewer.toggle_hex",                                   "⌘2"      }, // cmd+2
    {"viewer.toggle_preview",                               "⌘3"      }, // cmd+3
//  {"viewer.show_settings",                                "⌘0"      }, // cmd+0, no longer used
    {"viewer.show_goto",                                    "⌘l"      }, // cmd+l
    {"viewer.refresh",                                      "⌘r"      }, // cmd+r
};
// clang-format on

} // namespace nc::bootstrap
