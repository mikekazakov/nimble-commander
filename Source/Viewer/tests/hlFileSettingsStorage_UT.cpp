// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/FileSettingsStorage.h"
#include <robin_hood.h>
#include <fstream>

using namespace nc::viewer::hl;
using FSL = FileSettingsStorage;

#define PREFIX "hl::FileSettingsStorage "

TEST_CASE(PREFIX "Check invalid inputs")
{
    TempTestDir dir;
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
    TempTestDir dir;
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

TEST_CASE(PREFIX "Settings()")
{
    TempTestDir dir;
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
    TempTestDir dir;
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
