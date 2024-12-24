// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <Config/ConfigImpl.h>
#include <Config/NonPersistentOverwritesStorage.h>

using nc::core::ActionsShortcutsManager;
using nc::utility::ActionShortcut;

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
