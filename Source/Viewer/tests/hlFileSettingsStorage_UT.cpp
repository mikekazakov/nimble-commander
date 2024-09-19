// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/FileSettingsStorage.h"
#include <fstream>
#include <Base/dispatch_cpp.h>
#include <CoreFoundation/CoreFoundation.h>

using namespace nc::viewer::hl;
using FSL = FileSettingsStorage;

#define PREFIX "hl::FileSettingsStorage "

static bool runMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation);

TEST_CASE(PREFIX "Check invalid inputs")
{
    const TempTestDir dir;
    SECTION("Base dir doesn't exist")
    {
        CHECK_THROWS_AS(FSL("blah-blah-blah", ""), std::invalid_argument);
    }
    SECTION("Main file doesn't exist")
    {
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("Main file is not a valid json")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "blah-blah-blah" = "blah-blah-blah" })";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("No langs array")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("No langs array")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": false })";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("No name")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [{"settings": "a", "filemask":"a"}]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("No settings")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [{"name": "a", "filemask":"a"}]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("No filemask")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [{"name": "a", "settings":"a"}]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("Empty name")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [{"name": "", "settings": "a", "filemask":"a"}]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("Empty settings")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [{"name": "a", "settings": "", "filemask":"a"}]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("Empty filemask")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [{"name": "a", "settings": "a", "filemask":""}]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
    SECTION("Duplicate")
    {
        std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [
            {"name": "a", "settings": "a", "filemask":"a"},
            {"name": "a", "settings": "a", "filemask":"a"}
        ]})";
        CHECK_THROWS_AS(FSL(dir.directory, ""), std::invalid_argument);
    }
}

TEST_CASE(PREFIX "Language()")
{
    const TempTestDir dir;
    std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [
        {"name": "C++", "settings": "a", "filemask":"*.cpp"},
        {"name": "C#", "settings": "a", "filemask":"*.cs"}
    ]})";
    FSL stor{dir.directory, ""};
    CHECK(stor.Language("meow.cpp") == "C++");
    CHECK(stor.Language("meow.cs") == "C#");
    CHECK(stor.Language("meow.m") == std::nullopt);
    CHECK(stor.Language("") == std::nullopt);
}

TEST_CASE(PREFIX "List()")
{
    const TempTestDir dir;
    std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [
        {"name": "C++", "settings": "a", "filemask":"*.cpp"},
        {"name": "C#", "settings": "a", "filemask":"*.cs"}
    ]})";
    FSL stor{dir.directory, ""};
    CHECK(stor.List() == std::vector<std::string>{"C++", "C#"});
}

TEST_CASE(PREFIX "Settings()")
{
    const TempTestDir dir;
    std::ofstream{dir.directory / "Main.json"} << R"({ "langs": [
        {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"},
        {"name": "C#", "settings": "cs.json", "filemask":"*.cs"}
    ]})";
    std::ofstream{dir.directory / "cpp.json"} << "Hello, World!";
    FSL stor{dir.directory, ""};
    REQUIRE(stor.Settings("C++") != nullptr);
    CHECK(*stor.Settings("C++") == "Hello, World!");
    CHECK(stor.Settings("C++").get() == stor.Settings("C++").get());
    CHECK(stor.Settings("C#") == nullptr);
    CHECK(stor.Settings("C#") == nullptr);
}

TEST_CASE(PREFIX "Loads main settings from an override file")
{
    const TempTestDir dir;
    auto base = dir.directory / "base";
    auto ovr = dir.directory / "ovr";
    std::filesystem::create_directory(base);
    std::filesystem::create_directory(ovr);
    SECTION("Sane overrides")
    {
        std::ofstream{base / "Main.json"} << R"( some nonesense )";
        std::ofstream{ovr / "Main.json"} << R"({ "langs": [
            {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"}
        ]})";
        std::ofstream{base / "cpp.json"} << "Hello, World!";
        FSL stor{base, ovr};
        REQUIRE(stor.Settings("C++") != nullptr);
        CHECK(*stor.Settings("C++") == "Hello, World!");
    }
    SECTION("Corrupted overrides")
    {
        std::ofstream{base / "Main.json"} << R"({ "langs": [
            {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"}
        ]})";
        std::ofstream{ovr / "Main.json"} << R"( some nonesense )";
        std::ofstream{base / "cpp.json"} << "Hello, World!";
        FSL stor{base, ovr};
        REQUIRE(stor.Settings("C++") == nullptr);
    }
    SECTION("Load settings from the overrides directory")
    {
        std::ofstream{base / "Main.json"} << R"({ "langs": [
            {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"}
        ]})";
        std::ofstream{base / "cpp.json"} << "Hello, Base!";
        std::ofstream{ovr / "cpp.json"} << "Hello, Overrides!";
        FSL stor{base, ovr};
        REQUIRE(stor.Settings("C++") != nullptr);
        CHECK(*stor.Settings("C++") == "Hello, Overrides!");
    }
}

TEST_CASE(PREFIX "React to changes in the overrides directory")
{
    const TempTestDir dir;
    auto base = dir.directory / "base";
    auto ovr = dir.directory / "ovr";
    std::filesystem::create_directory(base);
    std::filesystem::create_directory(ovr);
    std::ofstream{base / "Main.json"} << R"({ "langs": [
        {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"},
        {"name": "JS", "settings": "js.json", "filemask":"*.js"}
    ]})";
    std::ofstream{ovr / "Main.json"} << R"({ "langs": [
        {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"}
    ]})";
    std::ofstream{base / "cpp.json"} << "Hello, World! Base";
    std::ofstream{base / "js.json"} << "JavaScript! Base";
    std::ofstream{ovr / "cpp.json"} << "Hello, World! Ovr";
    FSL stor{base, ovr};

    SECTION("Change of the settings file in the overrides")
    {
        REQUIRE(stor.Settings("C++") != nullptr);
        CHECK(*stor.Settings("C++") == "Hello, World! Ovr");
        std::ofstream{ovr / "cpp.json"} << "Hello, World! Take #2";
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("C++") != nullptr && *stor.Settings("C++") == "Hello, World! Take #2";
        }));
    }
    SECTION("Override settings file removed")
    {
        REQUIRE(stor.Settings("C++") != nullptr);
        CHECK(*stor.Settings("C++") == "Hello, World! Ovr");
        std::filesystem::remove(ovr / "cpp.json");
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("C++") != nullptr && *stor.Settings("C++") == "Hello, World! Base";
        }));
    }
    SECTION("Override settings file added")
    {
        std::filesystem::remove(ovr / "cpp.json");
        REQUIRE(stor.Settings("C++") != nullptr);
        CHECK(*stor.Settings("C++") == "Hello, World! Base");
        std::ofstream{ovr / "cpp.json"} << "Hello, World! Take #2";
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("C++") != nullptr && *stor.Settings("C++") == "Hello, World! Take #2";
        }));
    }
    SECTION("Change of the main file in the overrides")
    {
        std::ofstream{base / "java.json"} << "Hey there!";
        std::ofstream{ovr / "Main.json"} << R"({ "langs": [
            {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"},
            {"name": "Java", "settings": "java.json", "filemask":"*.java"}
        ]})";
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("Java") != nullptr && *stor.Settings("Java") == "Hey there!";
        }));
    }
    SECTION("Removal of the main file in the overrides")
    {
        REQUIRE(stor.Settings("JS") == nullptr);
        std::filesystem::remove(ovr / "Main.json");
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("JS") != nullptr && *stor.Settings("JS") == "JavaScript! Base";
        }));
    }
    SECTION("Adding of the main file in the overrides")
    {
        REQUIRE(stor.Settings("JS") == nullptr);
        std::filesystem::remove(ovr / "Main.json");
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("JS") != nullptr && *stor.Settings("JS") == "JavaScript! Base";
        }));
        std::ofstream{ovr / "java.json"} << "Hey there!";
        std::ofstream{ovr / "Main.json"} << R"({ "langs": [
            {"name": "C++", "settings": "cpp.json", "filemask":"*.cpp"},
            {"name": "Java", "settings": "java.json", "filemask":"*.java"}
        ]})";
        CHECK(runMainLoopUntilExpectationOrTimeout(std::chrono::seconds{10}, [&] {
            return stor.Settings("Java") != nullptr && *stor.Settings("Java") == "Hey there!";
        }));
    }
}

static bool runMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation)
{
    dispatch_assert_main_queue();
    assert(_timeout.count() > 0);
    assert(_expectation);
    const auto start_tp = std::chrono::steady_clock::now();
    const auto time_slice = 1. / 100.; // 10 ms;
    while( true ) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, time_slice, false);
        if( std::chrono::steady_clock::now() - start_tp > _timeout )
            return false;
        if( _expectation() )
            return true;
    }
}
