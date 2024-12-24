// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <Config/ConfigImpl.h>
#include <Config/NonPersistentOverwritesStorage.h>

using Catch::Matchers::UnorderedEquals;
using nc::core::ActionsShortcutsManager;
using nc::utility::ActionShortcut;
using ASM = ActionsShortcutsManager;

#define PREFIX "nc::core::ActionsShortcutsManager "

static const auto g_EmptyConfigJSON = R"({
    "hotkeyOverrides_v1": {}
})";

TEST_CASE(PREFIX "TagFromAction")
{
    CHECK(ActionsShortcutsManager::TagFromAction("menu.edit.copy") == 12'000);          // Valid query
    CHECK(ActionsShortcutsManager::TagFromAction("menu.i.dont.exist") == std::nullopt); // Invalid query
}

TEST_CASE(PREFIX "ActionFromTag")
{
    CHECK(ActionsShortcutsManager::ActionFromTag(12'000) == "menu.edit.copy"); // Valid query
    CHECK(ActionsShortcutsManager::ActionFromTag(346'242) == std::nullopt);    // Invalid query
}

TEST_CASE(PREFIX "ShortCutFromAction")
{
    nc::config::ConfigImpl config{g_EmptyConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ActionsShortcutsManager manager{config};

    REQUIRE(manager.ShortCutFromAction("menu.i.dont.exist") == std::nullopt);
    REQUIRE(manager.ShortCutFromAction("menu.edit.copy") == ActionShortcut("⌘c"));
    REQUIRE(manager.SetShortCutOverride("menu.edit.copy", ActionShortcut("⌘j")));
    REQUIRE(manager.ShortCutFromAction("menu.edit.copy") == ActionShortcut("⌘j"));
}

TEST_CASE(PREFIX "ShortCutFromTag")
{
    nc::config::ConfigImpl config{g_EmptyConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ActionsShortcutsManager manager{config};

    REQUIRE(manager.ShortCutFromTag(346'242) == std::nullopt);
    REQUIRE(manager.ShortCutFromTag(12'000) == ActionShortcut("⌘c"));
    REQUIRE(manager.SetShortCutOverride("menu.edit.copy", ActionShortcut("⌘j")));
    REQUIRE(manager.ShortCutFromTag(12'000) == ActionShortcut("⌘j"));
}

TEST_CASE(PREFIX "DefaultShortCutFromTag")
{
    nc::config::ConfigImpl config{g_EmptyConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ActionsShortcutsManager manager{config};

    REQUIRE(manager.DefaultShortCutFromTag(346'242) == std::nullopt);
    REQUIRE(manager.DefaultShortCutFromTag(12'000) == ActionShortcut("⌘c"));
    REQUIRE(manager.SetShortCutOverride("menu.edit.copy", ActionShortcut("⌘j")));
    REQUIRE(manager.DefaultShortCutFromTag(12'000) == ActionShortcut("⌘c"));
}

TEST_CASE(PREFIX "RevertToDefaults")
{
    nc::config::ConfigImpl config{g_EmptyConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ActionsShortcutsManager manager{config};

    REQUIRE(manager.SetShortCutOverride("menu.edit.copy", ActionShortcut("⌘j")));
    manager.RevertToDefaults();
    REQUIRE(manager.ShortCutFromAction("menu.edit.copy") == ActionShortcut("⌘c"));
}

TEST_CASE(PREFIX "ActionTagsFromShortCut")
{
    nc::config::ConfigImpl config{g_EmptyConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ActionsShortcutsManager manager{config};

    SECTION("Non-existent shortcut")
    {
        REQUIRE(manager.ActionTagsFromShortCut(ActionShortcut("⇧^⌘⌥j")) == std::nullopt);
    }
    SECTION("Non-existent shortcut when a domain is specified")
    {
        REQUIRE(manager.ActionTagsFromShortCut(ActionShortcut("⇧^⌘⌥j"), "this.domain.doesnt.exist.") == std::nullopt);
    }
    SECTION("Existent shortcut, but a domain doesn't match")
    {
        REQUIRE(manager.ActionTagsFromShortCut(ActionShortcut("⌘1"), "this.domain.doesnt.exist.") == std::nullopt);
    }
    SECTION("Shortcut used by two actions in different domains")
    {
        auto tags = manager.ActionTagsFromShortCut(ActionShortcut("⌘1"));
        REQUIRE(tags);
        REQUIRE(std::set<int>(tags->begin(), tags->end()) ==
                std::set<int>{ActionsShortcutsManager::TagFromAction("menu.go.quick_lists.parent_folders").value(),
                              ActionsShortcutsManager::TagFromAction("viewer.toggle_text").value()});
    }
    SECTION("Shortcut used by two actions in different domains, specify first")
    {
        REQUIRE(manager.ActionTagsFromShortCut(ActionShortcut("⌘1"), "menu.") ==
                ActionsShortcutsManager::ActionTags{
                    ActionsShortcutsManager::TagFromAction("menu.go.quick_lists.parent_folders").value()});
    }
    SECTION("Shortcut used by two actions in different domains, specify second")
    {
        REQUIRE(
            manager.ActionTagsFromShortCut(ActionShortcut("⌘1"), "viewer.") ==
            ActionsShortcutsManager::ActionTags{ActionsShortcutsManager::TagFromAction("viewer.toggle_text").value()});
    }
    SECTION("Shortcut is used by by two actions by default and one via override")
    {
        REQUIRE(manager.SetShortCutOverride("menu.window.zoom", ActionShortcut("⌘1")));
        auto tags = manager.ActionTagsFromShortCut(ActionShortcut("⌘1"));
        REQUIRE(tags);
        REQUIRE(std::set<int>(tags->begin(), tags->end()) ==
                std::set<int>{
                    ActionsShortcutsManager::TagFromAction("menu.go.quick_lists.parent_folders").value(),
                    ActionsShortcutsManager::TagFromAction("viewer.toggle_text").value(),
                    ActionsShortcutsManager::TagFromAction("menu.window.zoom").value(),
                });
    }
    SECTION("After setting and removing the override its not reported as being used")
    {
        REQUIRE(manager.SetShortCutOverride("menu.window.zoom", ActionShortcut("⇧^⌘⌥j")));
        REQUIRE(manager.SetShortCutOverride("menu.window.zoom", {}));
        REQUIRE(manager.ActionTagsFromShortCut(ActionShortcut("⇧^⌘⌥j")) == std::nullopt);
    }
}

TEST_CASE(PREFIX "FirstOfActionTagsFromShortCut")
{
    nc::config::ConfigImpl config{g_EmptyConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ASM manager{config};
    REQUIRE(manager.FirstOfActionTagsFromShortCut({}, ActionShortcut("⌘1")) == std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortCut(std::initializer_list<int>{346'242}, ActionShortcut("⌘1")) ==
            std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortCut(
                std::initializer_list<int>{ASM::TagFromAction("menu.go.quick_lists.parent_folders").value()},
                ActionShortcut("⌘1")) == ASM::TagFromAction("menu.go.quick_lists.parent_folders").value());
    REQUIRE(manager.FirstOfActionTagsFromShortCut(
                std::initializer_list<int>{ASM::TagFromAction("menu.go.quick_lists.parent_folders").value()},
                ActionShortcut("⌘1"),
                "menu.") == ASM::TagFromAction("menu.go.quick_lists.parent_folders").value());

    REQUIRE(manager.FirstOfActionTagsFromShortCut(
                std::initializer_list<int>{ASM::TagFromAction("menu.go.quick_lists.parent_folders").value()},
                ActionShortcut("⌘1"),
                "viewer.") == std::nullopt);

    REQUIRE(manager.FirstOfActionTagsFromShortCut(
                std::initializer_list<int>{ASM::TagFromAction("viewer.toggle_text").value()}, ActionShortcut("⌘1")) ==
            ASM::TagFromAction("viewer.toggle_text").value());

    REQUIRE(manager.FirstOfActionTagsFromShortCut(
                std::initializer_list<int>{ASM::TagFromAction("viewer.toggle_text").value()},
                ActionShortcut("⌘1"),
                "menu.") == std::nullopt);
    REQUIRE(manager.FirstOfActionTagsFromShortCut(
                std::initializer_list<int>{ASM::TagFromAction("viewer.toggle_text").value()},
                ActionShortcut("⌘1"),
                "viewer.") == ASM::TagFromAction("viewer.toggle_text").value());
}
