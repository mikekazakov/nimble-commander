// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <Config/ConfigImpl.h>
#include <Config/NonPersistentOverwritesStorage.h>
#include <fmt/format.h>

using ASM = nc::core::ActionsShortcutsManager;
using AS = ASM::Shortcut;
using ASs = ASM::Shortcuts;
using nc::config::ConfigImpl;
using nc::config::NonPersistentOverwritesStorage;

#define PREFIX "nc::core::ActionsShortcutsManager "

static const auto g_EmptyConfigJSON = R"({
    "hotkeyOverrides_v1": {}
})";

static const std::pair<const char *, int> g_Actions[] = {
    {"menu.edit.copy", 12'000},                     //
    {"menu.go.quick_lists.parent_folders", 14'160}, //
    {"menu.window.zoom", 16'020},                   //
    {"viewer.toggle_text", 101'000},                //
};

static const std::pair<const char *, const char *> g_Shortcuts[] = {
    {"menu.edit.copy", "⌘c"},                     //
    {"menu.go.quick_lists.parent_folders", "⌘1"}, //
    {"menu.window.zoom", ""},                     //
    {"viewer.toggle_text", "⌘1"},                 //
};

TEST_CASE(PREFIX "TagFromAction")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    const ASM manager{g_Actions, g_Shortcuts, config};
    CHECK(manager.TagFromAction("menu.edit.copy") == 12'000);          // Valid query
    CHECK(manager.TagFromAction("menu.i.dont.exist") == std::nullopt); // Invalid query
}

TEST_CASE(PREFIX "ActionFromTag")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    const ASM manager{g_Actions, g_Shortcuts, config};
    CHECK(manager.ActionFromTag(12'000) == "menu.edit.copy"); // Valid query
    CHECK(manager.ActionFromTag(346'242) == std::nullopt);    // Invalid query
}

TEST_CASE(PREFIX "ShortCutFromAction")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    ASM manager{g_Actions, g_Shortcuts, config};

    SECTION("Non-existent")
    {
        REQUIRE(manager.ShortcutsFromAction("menu.i.dont.exist") == std::nullopt);
    }
    SECTION("Default value")
    {
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘c")});
    }
    SECTION("Override with a single shortcut")
    {
        REQUIRE(manager.SetShortcutOverride("menu.edit.copy", AS("⌘j")));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j")});
    }
    SECTION("Override with an empty shortcut")
    {
        REQUIRE(manager.SetShortcutOverride("menu.edit.copy", AS()));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{});
    }
    SECTION("Override with two shortcuts")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j"), AS("⌘k")}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
    }
    SECTION("Override with two shortcuts and some empty bogus ones")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS(), AS("⌘j"), AS(), AS("⌘k"), AS()}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
    }
}

TEST_CASE(PREFIX "ShortCutFromTag")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    ASM manager{g_Actions, g_Shortcuts, config};

    REQUIRE(manager.ShortcutsFromTag(346'242) == std::nullopt);
    REQUIRE(manager.ShortcutsFromTag(12'000) == ASs{AS("⌘c")});
    REQUIRE(manager.SetShortcutOverride("menu.edit.copy", AS("⌘j")));
    REQUIRE(manager.ShortcutsFromTag(12'000) == ASs{AS("⌘j")});
}

TEST_CASE(PREFIX "DefaultShortCutFromTag")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    ASM manager{g_Actions, g_Shortcuts, config};

    REQUIRE(manager.DefaultShortcutsFromTag(346'242) == std::nullopt);
    REQUIRE(manager.DefaultShortcutsFromTag(12'000) == ASs{AS("⌘c")});
    REQUIRE(manager.SetShortcutOverride("menu.edit.copy", AS("⌘j")));
    REQUIRE(manager.DefaultShortcutsFromTag(12'000) == ASs{AS("⌘c")});
}

TEST_CASE(PREFIX "RevertToDefaults")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    ASM manager{g_Actions, g_Shortcuts, config};

    REQUIRE(manager.SetShortcutOverride("menu.edit.copy", AS("⌘j")));
    manager.RevertToDefaults();
    REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘c")});
}

TEST_CASE(PREFIX "ActionTagsFromShortCut")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    ASM manager{g_Actions, g_Shortcuts, config};

    SECTION("Non-existent shortcut")
    {
        REQUIRE(manager.ActionTagsFromShortcut(AS("⇧^⌘⌥j")) == std::nullopt);
    }
    SECTION("Non-existent shortcut when a domain is specified")
    {
        REQUIRE(manager.ActionTagsFromShortcut(AS("⇧^⌘⌥j"), "this.domain.doesnt.exist.") == std::nullopt);
    }
    SECTION("Existent shortcut, but a domain doesn't match")
    {
        REQUIRE(manager.ActionTagsFromShortcut(AS("⌘1"), "this.domain.doesnt.exist.") == std::nullopt);
    }
    SECTION("Shortcut used by two actions in different domains")
    {
        auto tags = manager.ActionTagsFromShortcut(AS("⌘1"));
        REQUIRE(tags);
        REQUIRE(std::set<int>(tags->begin(), tags->end()) ==
                std::set<int>{manager.TagFromAction("menu.go.quick_lists.parent_folders").value(),
                              manager.TagFromAction("viewer.toggle_text").value()});
    }
    SECTION("Shortcut used by two actions in different domains, specify first")
    {
        REQUIRE(manager.ActionTagsFromShortcut(AS("⌘1"), "menu.") ==
                ASM::ActionTags{manager.TagFromAction("menu.go.quick_lists.parent_folders").value()});
    }
    SECTION("Shortcut used by two actions in different domains, specify second")
    {
        REQUIRE(manager.ActionTagsFromShortcut(AS("⌘1"), "viewer.") ==
                ASM::ActionTags{manager.TagFromAction("viewer.toggle_text").value()});
    }
    SECTION("Shortcut is used by by two actions by default and one via override")
    {
        REQUIRE(manager.SetShortcutOverride("menu.window.zoom", AS("⌘1")));
        auto tags = manager.ActionTagsFromShortcut(AS("⌘1"));
        REQUIRE(tags);
        REQUIRE(std::set<int>(tags->begin(), tags->end()) ==
                std::set<int>{
                    manager.TagFromAction("menu.go.quick_lists.parent_folders").value(),
                    manager.TagFromAction("viewer.toggle_text").value(),
                    manager.TagFromAction("menu.window.zoom").value(),
                });
    }
    SECTION("Shortcut is used by by two actions by default and one via override (multiple shortcuts)")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.window.zoom", std::array{AS("⇧^⌘⌥j"), AS("⌘1")}));
        auto tags = manager.ActionTagsFromShortcut(AS("⌘1"));
        REQUIRE(tags);
        REQUIRE(std::set<int>(tags->begin(), tags->end()) ==
                std::set<int>{
                    manager.TagFromAction("menu.go.quick_lists.parent_folders").value(),
                    manager.TagFromAction("viewer.toggle_text").value(),
                    manager.TagFromAction("menu.window.zoom").value(),
                });
    }
    SECTION("After setting an override the original is not reported as being used")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j")}));
        REQUIRE(manager.ActionTagsFromShortcut(AS("⌘c"), "menu.") == std::nullopt);
    }
    SECTION("After setting and removing the override its not reported as being used")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.window.zoom", std::array{AS("⇧^⌘⌥k"), AS("⇧^⌘⌥j")}));
        REQUIRE(manager.SetShortcutsOverride("menu.window.zoom", {}));
        REQUIRE(manager.ActionTagsFromShortcut(AS("⇧^⌘⌥k")) == std::nullopt);
        REQUIRE(manager.ActionTagsFromShortcut(AS("⇧^⌘⌥j")) == std::nullopt);
    }
}

TEST_CASE(PREFIX "FirstOfActionTagsFromShortCut")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    const ASM manager{g_Actions, g_Shortcuts, config};
    REQUIRE(manager.FirstOfActionTagsFromShortcut({}, AS("⌘1")) == std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortcut(std::initializer_list<int>{346'242}, AS("⌘1")) == std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortcut(
                std::initializer_list<int>{manager.TagFromAction("menu.go.quick_lists.parent_folders").value()},
                AS("⌘1")) == manager.TagFromAction("menu.go.quick_lists.parent_folders").value());
    REQUIRE(manager.FirstOfActionTagsFromShortcut(
                std::initializer_list<int>{manager.TagFromAction("menu.go.quick_lists.parent_folders").value()},
                AS("⌘1"),
                "menu.") == manager.TagFromAction("menu.go.quick_lists.parent_folders").value());
    REQUIRE(manager.FirstOfActionTagsFromShortcut(
                std::initializer_list<int>{manager.TagFromAction("menu.go.quick_lists.parent_folders").value()},
                AS("⌘1"),
                "viewer.") == std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortcut(
                std::initializer_list<int>{manager.TagFromAction("viewer.toggle_text").value()}, AS("⌘1")) ==
            manager.TagFromAction("viewer.toggle_text").value());
    REQUIRE(manager.FirstOfActionTagsFromShortcut(
                std::initializer_list<int>{manager.TagFromAction("viewer.toggle_text").value()}, AS("⌘1"), "menu.") ==
            std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortcut(
                std::initializer_list<int>{manager.TagFromAction("viewer.toggle_text").value()}, AS("⌘1"), "viewer.") ==
            manager.TagFromAction("viewer.toggle_text").value());
}

TEST_CASE(PREFIX "Configuration persistence")
{
    SECTION("Loading from config - single empty override")
    {
        const auto json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ""
            }
        })";
        ConfigImpl config{json, std::make_shared<NonPersistentOverwritesStorage>("")};
        const ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{});
    }
    SECTION("Loading from config - single override")
    {
        const auto json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": "⌘j"
            }
        })";
        ConfigImpl config{json, std::make_shared<NonPersistentOverwritesStorage>("")};
        const ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j")});
    }
    SECTION("Loading from config - single empty array")
    {
        const auto json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": []
            }
        })";
        ConfigImpl config{json, std::make_shared<NonPersistentOverwritesStorage>("")};
        const ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{});
    }
    SECTION("Loading from config - single array with one shortcut")
    {
        const auto json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ["⌘j"]
            }
        })";
        ConfigImpl config{json, std::make_shared<NonPersistentOverwritesStorage>("")};
        const ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j")});
    }
    SECTION("Loading from config - single array with two shortcuts")
    {
        const auto json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ["⌘j", "⌘k"]
            }
        })";
        ConfigImpl config{json, std::make_shared<NonPersistentOverwritesStorage>("")};
        const ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
    }
    SECTION("Loading from config - mixed usage")
    {
        const auto json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ["⌘j", "⌘k"],
                "menu.window.zoom": "⇧^⌘⌥j"
            }
        })";
        ConfigImpl config{json, std::make_shared<NonPersistentOverwritesStorage>("")};
        const ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
        REQUIRE(manager.ShortcutsFromAction("menu.window.zoom") == ASs{AS("⇧^⌘⌥j")});
    }
    SECTION("Writing to config - single empty override")
    {
        ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
        ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", {}));
        const auto expected_json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ""
            }
        })";
        const ConfigImpl expected_config{expected_json, std::make_shared<NonPersistentOverwritesStorage>("")};
        REQUIRE(config.Get("hotkeyOverrides_v1") == expected_config.Get("hotkeyOverrides_v1"));
    }
    SECTION("Writing to config - single override")
    {
        ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
        ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j")}));
        const auto expected_json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": "⌘j"
            }
        })";
        const ConfigImpl expected_config{expected_json, std::make_shared<NonPersistentOverwritesStorage>("")};
        REQUIRE(config.Get("hotkeyOverrides_v1") == expected_config.Get("hotkeyOverrides_v1"));
    }
    SECTION("Writing to config - single override with two hotkeys ")
    {
        ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
        ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j"), AS("⌘k")}));
        const auto expected_json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ["⌘j", "⌘k"]
            }
        })";
        const ConfigImpl expected_config{expected_json, std::make_shared<NonPersistentOverwritesStorage>("")};
        REQUIRE(config.Get("hotkeyOverrides_v1") == expected_config.Get("hotkeyOverrides_v1"));
    }
    SECTION("Writing to config - mixed usage")
    {
        ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
        ASM manager{g_Actions, g_Shortcuts, config};
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j"), AS("⌘k")}));
        REQUIRE(manager.SetShortcutOverride("menu.window.zoom", AS("⇧^⌘⌥j")));
        const auto expected_json = R"({
            "hotkeyOverrides_v1": {
                "menu.edit.copy": ["⌘j", "⌘k"],
                "menu.window.zoom": "⇧^⌥⌘j"
            }
        })";
        const ConfigImpl expected_config{expected_json, std::make_shared<NonPersistentOverwritesStorage>("")};
        REQUIRE(config.Get("hotkeyOverrides_v1") == expected_config.Get("hotkeyOverrides_v1"));
    }
}

TEST_CASE(PREFIX "SetShortcutsOverride")
{
    ConfigImpl config{g_EmptyConfigJSON, std::make_shared<NonPersistentOverwritesStorage>("")};
    ASM manager{g_Actions, g_Shortcuts, config};
    SECTION("Empty")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", {}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{});
    }
    SECTION("Single")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j")}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j")});
    }
    SECTION("Single and empty")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS(), AS("⌘j"), AS()}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j")});
    }
    SECTION("Single and duplicates")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j"), AS("⌘j")}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j")});
    }
    SECTION("Two")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j"), AS("⌘k")}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
    }
    SECTION("Two and empty")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS(), AS("⌘j"), AS(), AS("⌘k"), AS()}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
    }
    SECTION("Two and duplicates")
    {
        REQUIRE(manager.SetShortcutsOverride("menu.edit.copy", std::array{AS("⌘j"), AS("⌘k"), AS("⌘j"), AS("⌘k")}));
        REQUIRE(manager.ShortcutsFromAction("menu.edit.copy") == ASs{AS("⌘j"), AS("⌘k")});
    }
}
