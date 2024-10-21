// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <Config/ConfigImpl.h>
#include <Config/NonPersistentOverwritesStorage.h>

#include <NimbleCommander/Core/Theming/SystemThemeDetector.h>

#include <rapidjson/error/en.h>

#include <algorithm>

using nc::ThemeAppearance;
using nc::ThemesManager;
using nc::config::ConfigImpl;
using nc::config::NonPersistentOverwritesStorage;

#define PREFIX "ThemesManager "

static std::shared_ptr<NonPersistentOverwritesStorage> MakeDummyStorage()
{
    return std::make_shared<NonPersistentOverwritesStorage>("");
}

static std::string ReplQuotes(std::string_view src)
{
    std::string s(src);
    std::ranges::replace(s, '\'', '\"');
    return s;
}

static std::shared_ptr<NonPersistentOverwritesStorage> MakeOverwritesStorage(std::string_view _src)
{
    return std::make_shared<NonPersistentOverwritesStorage>(ReplQuotes(_src));
}

static nc::config::Value JSONToObj(std::string_view _json)
{
    if( _json.empty() )
        return nc::config::Value(rapidjson::kNullType);

    rapidjson::Document doc;
    const rapidjson::ParseResult ok = doc.Parse<rapidjson::kParseCommentsFlag>(_json.data(), _json.length());
    if( !ok ) {
        throw std::invalid_argument{rapidjson::GetParseError_En(ok.Code())};
    }
    nc::config::Value res;
    res.CopyFrom(doc, nc::config::g_CrtAllocator);
    return res;
}

TEST_CASE(PREFIX "Constructs from config")
{
    const auto json = "\
    {\
        'current': 'first',\
        'themes': {\
            'themes_v1': [\
                {'themeName': 'first'},\
                {'themeName': 'second'}\
            ]\
        }\
    }\
    ";
    ConfigImpl config{ReplQuotes(json), MakeDummyStorage()};
    const ThemesManager man(config, "current", "themes");

    // Now query some of the read-only API entrypoints to verify this dummy state
    CHECK(man.SelectedThemeName() == "first");
    CHECK_NOTHROW(man.SelectedTheme()); // currently themes don't provide their names
    CHECK(man.ThemeNames() == std::vector<std::string>{"first", "second"});
    CHECK(man.HasDefaultSettings("first"));
    CHECK(man.HasDefaultSettings("second"));
    CHECK(!man.CanBeRemoved("first"));
    CHECK(!man.CanBeRemoved("second"));
}

TEST_CASE(PREFIX "Switches between light/dark themes when selected manually")
{
    const auto json = "\
    {\
        'current': 'first',\
        'themes': {\
            'themes_v1': [\
                {'themeName': 'first', 'themeAppearance': 'light'},\
                {'themeName': 'second', 'themeAppearance': 'dark'}\
            ]\
        }\
    }\
    ";
    ConfigImpl config{ReplQuotes(json), MakeDummyStorage()};
    ThemesManager man(config, "current", "themes");

    // Now query some of the read-only API entrypoints to verify this dummy state
    // "first" is now selected
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Light);

    man.SelectTheme("second");
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Dark);

    man.SelectTheme("first");
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Light);
}

TEST_CASE(PREFIX "Switches between light/dark themes when system theme changes")
{
    const auto json = "\
    {\
        'current': 'first',\
        'themes': {\
            'automaticSwitching': {\
                'enabled': true,\
                'light': 'first',\
                'dark': 'second'\
            },\
            'themes_v1': [\
                {'themeName': 'first', 'themeAppearance': 'light'},\
                {'themeName': 'second', 'themeAppearance': 'dark'}\
            ]\
        }\
    }\
    ";
    ConfigImpl config{ReplQuotes(json), MakeDummyStorage()};

    SECTION("Enabled")
    {
        ThemesManager man(config, "current", "themes");

        // Expect no changes
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Light);
        CHECK(man.SelectedThemeName() == "first");

        // Now should switch to second
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Dark);
        CHECK(man.SelectedThemeName() == "second");

        // Nothing to change
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Dark);
        CHECK(man.SelectedThemeName() == "second");

        // And first again
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Light);
        CHECK(man.SelectedThemeName() == "first");

        // Nothing to change
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Light);
        CHECK(man.SelectedThemeName() == "first");
    }
    SECTION("Disabled")
    {
        config.Set("themes.automaticSwitching.enabled", false);
        ThemesManager man(config, "current", "themes");
        // Nope
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Light);
        CHECK(man.SelectedThemeName() == "first");
        // Nope
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Dark);
        CHECK(man.SelectedThemeName() == "first");
        // Again nope
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Light);
        CHECK(man.SelectedThemeName() == "first");
    }
    SECTION("Enabled, garbage data")
    {
        config.Set("themes.automaticSwitching.light", "IDontExist");
        config.Set("themes.automaticSwitching.dark", "MeNeither");
        ThemesManager man(config, "current", "themes");
        // Gracefully ignores bogus settings
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Light);
        CHECK(man.SelectedThemeName() == "first");
        // Gracefully ignores bogus settings
        man.NotifyAboutSystemAppearanceChange(ThemeAppearance::Dark);
        CHECK(man.SelectedThemeName() == "first");
    }
}

TEST_CASE(PREFIX "API for themes switching")
{
    const auto json = "\
    {\
        'current': 'first',\
        'themes': {\
            'automaticSwitching': {\
                'enabled': true,\
                'light': 'first',\
                'dark': 'second'\
            },\
            'themes_v1': [\
                {'themeName': 'first', 'themeAppearance': 'light'},\
                {'themeName': 'second', 'themeAppearance': 'dark'}\
            ]\
        }\
    }\
    ";
    ConfigImpl config{ReplQuotes(json), MakeDummyStorage()};
    SECTION("AutomaticSwitching()")
    {
        SECTION("Original")
        {
            const ThemesManager man(config, "current", "themes");
            auto as = man.AutomaticSwitching();
            CHECK(as.enabled == true);
            CHECK(as.light == "first");
            CHECK(as.dark == "second");
        }
        SECTION("Disabled")
        {
            config.Set("themes.automaticSwitching.enabled", false);
            const ThemesManager man(config, "current", "themes");
            auto as = man.AutomaticSwitching();
            CHECK(as.enabled == false);
            CHECK(as.light == "first");
            CHECK(as.dark == "second");
        }
        SECTION("Light")
        {
            config.Set("themes.automaticSwitching.light", "Foo");
            const ThemesManager man(config, "current", "themes");
            auto as = man.AutomaticSwitching();
            CHECK(as.enabled == true);
            CHECK(as.light == "Foo");
            CHECK(as.dark == "second");
        }
        SECTION("Dark")
        {
            config.Set("themes.automaticSwitching.dark", "Bar");
            const ThemesManager man(config, "current", "themes");
            auto as = man.AutomaticSwitching();
            CHECK(as.enabled == true);
            CHECK(as.light == "first");
            CHECK(as.dark == "Bar");
        }
    }
    SECTION("SetAutomaticSwitching()")
    {
        ThemesManager man(config, "current", "themes");
        auto as = man.AutomaticSwitching();
        SECTION("enabled")
        {
            as.enabled = false;
            man.SetAutomaticSwitching(as);
            CHECK(man.AutomaticSwitching().enabled == false);
            CHECK(config.GetBool("themes.automaticSwitching.enabled") == false);
        }
        SECTION("light")
        {
            as.light = "Foo";
            man.SetAutomaticSwitching(as);
            CHECK(man.AutomaticSwitching().light == "Foo");
            CHECK(config.GetString("themes.automaticSwitching.light") == "Foo");
        }
        SECTION("dark")
        {
            as.dark = "Bar";
            man.SetAutomaticSwitching(as);
            CHECK(man.AutomaticSwitching().dark == "Bar");
            CHECK(config.GetString("themes.automaticSwitching.dark") == "Bar");
        }
    }
}

TEST_CASE(PREFIX "Updates automatic theme if a referenced was deleted")
{
    const auto defaults = "\
    {\
        'current': 'Light',\
        'themes': {\
            'automaticSwitching': {\
                'enabled': true,\
                'light': 'third',\
                'dark': 'fourth'\
            },\
            'themes_v1': [\
                {'themeName': 'Light', 'themeAppearance': 'light'},\
                {'themeName': 'Dark', 'themeAppearance': 'dark'}\
            ]\
        }\
    }";
    const auto themes = "\[\
                {'themeName': 'Light', 'themeAppearance': 'light'},\
                {'themeName': 'Dark', 'themeAppearance': 'dark'},\
                {'themeName': 'third', 'themeAppearance': 'light'},\
                {'themeName': 'fourth', 'themeAppearance': 'dark'}]";
    ConfigImpl config{ReplQuotes(defaults), MakeDummyStorage()};
    config.Set("themes.themes_v1", JSONToObj(ReplQuotes(themes)));
    ThemesManager man(config, "current", "themes");
    SECTION("Removed a light theme")
    {
        man.RemoveTheme("third");
        CHECK(man.AutomaticSwitching().enabled == true);
        CHECK(man.AutomaticSwitching().light == "Light");
        CHECK(man.AutomaticSwitching().dark == "fourth");
    }
    SECTION("Removed a dark theme")
    {
        man.RemoveTheme("fourth");
        CHECK(man.AutomaticSwitching().enabled == true);
        CHECK(man.AutomaticSwitching().light == "third");
        CHECK(man.AutomaticSwitching().dark == "Dark");
    }
}

TEST_CASE(PREFIX "Picking a new name for a duplicate theme")
{
    const auto json = "\
    {\
        'current': 'name',\
        'themes': {\
            'themes_v1': [\
                {'themeName': 'name'},\
                {'themeName': 'name 2'},\
                {'themeName': 'another'}\
            ]\
        }\
    }\
    ";
    ConfigImpl config{ReplQuotes(json), MakeDummyStorage()};
    const ThemesManager man(config, "current", "themes");

    CHECK(man.SuitableNameForNewTheme("name") == "name 3");
    CHECK(man.SuitableNameForNewTheme("name ") == "name ");
    CHECK(man.SuitableNameForNewTheme("name 2") == "name 3");
    CHECK(man.SuitableNameForNewTheme("name 2 ") == "name 2 ");
    CHECK(man.SuitableNameForNewTheme("another") == "another 2");
    CHECK(man.SuitableNameForNewTheme("not here") == "not here");
    CHECK(man.SuitableNameForNewTheme("name2") == "name2");
    CHECK(man.SuitableNameForNewTheme("1") == "1");
    CHECK(man.SuitableNameForNewTheme(" 1") == " 1");
    CHECK(man.SuitableNameForNewTheme("1 ") == "1 ");
    CHECK(man.SuitableNameForNewTheme("").empty());
    CHECK(man.SuitableNameForNewTheme(" ") == " ");
}

TEST_CASE(PREFIX "Renames 'Modern' to 'Light'")
{
    const auto json = "\
    {\
        'current': 'Modern',\
        'themes': {\
            'themes_v1': [\
                {'themeName': 'Modern'},\
                {'themeName': 'second'}\
            ]\
        }\
    }\
    ";
    ConfigImpl config{ReplQuotes(json), MakeDummyStorage()};
    const ThemesManager man(config, "current", "themes");
    CHECK(man.ThemeNames() == std::vector<std::string>{"Light", "second"});
    CHECK(man.SelectedThemeName() == "Light");
}

TEST_CASE(PREFIX "New themes can be added when there are overwrites already")
{
    const auto defaults = "\
    {\
        'current': 'Light',\
        'themes': {\
            'themes_v1': [\
                {'themeName': 'Light', 'themeAppearance': 'light'},\
                {'themeName': 'Dark', 'themeAppearance': 'dark'},\
                {'themeName': 'Grey', 'themeAppearance': 'dark'}\
            ]\
        }\
    }";
    const auto overwrites = "\
    {\
        'current': 'Light',\
        'themes': {\
            'themes_v1': [\
                {'themeName': 'Light', 'themeAppearance': 'dark'},\
                {'themeName': 'Dark', 'themeAppearance': 'light'},\
                {'themeName': 'Blue', 'themeAppearance': 'light'}\
            ]\
        }\
    }";
    ConfigImpl config{ReplQuotes(defaults), MakeOverwritesStorage(overwrites)};
    ThemesManager man(config, "current", "themes");
    CHECK(man.ThemeNames() == std::vector<std::string>{"Light", "Dark", "Grey", "Blue"});
    CHECK(man.SelectTheme("Light"));
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Dark);
    CHECK(man.SelectTheme("Dark"));
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Light);
    CHECK(man.SelectTheme("Grey"));
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Dark);
    CHECK(man.SelectTheme("Blue"));
    CHECK(man.SelectedTheme().AppearanceType() == ThemeAppearance::Light);
}
