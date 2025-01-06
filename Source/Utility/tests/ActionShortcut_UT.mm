// Copyright (C) 2019-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ActionShortcut.h"
#include "UnitTests_main.h"
#include <Carbon/Carbon.h>
#include <spdlog/fmt/fmt.h>

using nc::utility::ActionShortcut;

#define PREFIX "nc::utility::ActionShortcut "
TEST_CASE(PREFIX "Default constructor makes both unicode and modifiers zero")
{
    const ActionShortcut as;
    CHECK(as.unicode == 0);
    CHECK(as.modifiers.is_empty());
}

TEST_CASE(PREFIX "ShortCut with both unicode and modifiers zero is convertible to false")
{
    CHECK(static_cast<bool>(ActionShortcut{}) == false);
    CHECK(static_cast<bool>(ActionShortcut{49, NSEventModifierFlagCommand}) == true);
}

TEST_CASE(PREFIX "Properly parses persistency strings")
{
    CHECK(ActionShortcut{""} == ActionShortcut{});
    CHECK(ActionShortcut{"1"} == ActionShortcut{49, 0});
    CHECK(ActionShortcut{"⌘1"} == ActionShortcut{49, NSEventModifierFlagCommand});
    CHECK(ActionShortcut{"⇧⌘1"} == ActionShortcut{49, NSEventModifierFlagShift | NSEventModifierFlagCommand});
    CHECK(ActionShortcut{"^⌘1"} == ActionShortcut{49, NSEventModifierFlagControl | NSEventModifierFlagCommand});
    CHECK(ActionShortcut{"⌥⌘1"} == ActionShortcut{49, NSEventModifierFlagOption | NSEventModifierFlagCommand});
    CHECK(ActionShortcut{"^⇧⌥⌘1"} == ActionShortcut{49,
                                                    NSEventModifierFlagShift | NSEventModifierFlagControl |
                                                        NSEventModifierFlagOption | NSEventModifierFlagCommand});
    CHECK(ActionShortcut{"⌘\x7f"} == ActionShortcut{127, NSEventModifierFlagCommand});
}

TEST_CASE(PREFIX "Handles serialized special symbols properly")
{
    CHECK(ActionShortcut{"\\r"} == ActionShortcut{13, 0});
    CHECK(ActionShortcut{"\\t"} == ActionShortcut{9, 0});
}

TEST_CASE(PREFIX "Produces correct persistent strings")
{
    CHECK(ActionShortcut{"⇧^⌥⌘a"}.ToPersString() == "⇧^⌥⌘a");
    CHECK(ActionShortcut{"⇧^⌥⌘1"}.ToPersString() == "⇧^⌥⌘1");
    CHECK(ActionShortcut{"^⌥⌘1"}.ToPersString() == "^⌥⌘1");
    CHECK(ActionShortcut{"⌥⌘1"}.ToPersString() == "⌥⌘1");
    CHECK(ActionShortcut{"⌘1"}.ToPersString() == "⌘1");
    CHECK(ActionShortcut{"1"}.ToPersString() == "1");
    CHECK(ActionShortcut{"\x7f"}.ToPersString() == "\x7f");
}

TEST_CASE(PREFIX "Does proper comparison")
{
    CHECK(ActionShortcut{"⌘1"} == ActionShortcut{"⌘1"});
    CHECK(!(ActionShortcut{"⌘1"} == ActionShortcut{"⌘2"}));
    CHECK(ActionShortcut{"⌘1"} != ActionShortcut{"⌘2"});
    CHECK(!(ActionShortcut{"⌘1"} != ActionShortcut{"⌘1"}));
    CHECK(!(ActionShortcut{"⌘1"} == ActionShortcut{"^1"}));
    CHECK(ActionShortcut{"⌘1"} != ActionShortcut{"^1"});
}

TEST_CASE(PREFIX "PrettyString()")
{
    struct TestCase {
        const char *input;
        NSString *pretty;
    } const test_cases[] = {
        {.input = "", .pretty = @""},
        {.input = "⌘1", .pretty = @"⌘1"},
        {.input = "^1", .pretty = @"⌃1"},
        {.input = "⇧1", .pretty = @"⇧1"},
        {.input = "⌥1", .pretty = @"⌥1"},
        {.input = "⌘⇧⌥^1", .pretty = @"⌃⌥⇧⌘1"},
        {.input = "⌘A", .pretty = @"⌘A"},
        {.input = "⌘a", .pretty = @"⌘A"},
        {.input = "\uF70D", .pretty = @"F10"},
    };
    for( auto &test_case : test_cases ) {
        auto pretty = ActionShortcut(test_case.input).PrettyString();
        INFO(test_case.input);
        INFO(test_case.pretty.UTF8String);
        INFO(pretty.UTF8String);
        CHECK([pretty isEqualToString:test_case.pretty]);
    }
}

TEST_CASE(PREFIX "[NSMenuItem nc_setKeyEquivalentWithShortcut]")
{
    NSMenuItem *const it = [[NSMenuItem alloc] initWithTitle:@"Hello" action:nil keyEquivalent:@""];
    SECTION("Empty")
    {
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"⌘1"}];
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{}];
        CHECK([it.keyEquivalent isEqualToString:@""]);
        CHECK(it.keyEquivalentModifierMask == 0);
    }
    SECTION("Cmd + 1")
    {
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"⌘1"}];
        CHECK([it.keyEquivalent isEqualToString:@"1"]);
        CHECK(it.keyEquivalentModifierMask == NSEventModifierFlagCommand);
    }
    SECTION("Ctrl + 1")
    {
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"^1"}];
        CHECK([it.keyEquivalent isEqualToString:@"1"]);
        CHECK(it.keyEquivalentModifierMask == NSEventModifierFlagControl);
    }
    SECTION("Alt + 1")
    {
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"⌥1"}];
        CHECK([it.keyEquivalent isEqualToString:@"1"]);
        CHECK(it.keyEquivalentModifierMask == NSEventModifierFlagOption);
    }
    SECTION("Shift + 1")
    {
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"⇧1"}];
        CHECK([it.keyEquivalent isEqualToString:@"1"]);
        CHECK(it.keyEquivalentModifierMask == NSEventModifierFlagShift);
    }
    SECTION("Cmd + 0x007f")
    { // Special treatment for Backspace
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"⌘\u007f"}];
        CHECK([it.keyEquivalent isEqualToString:@"\u0008"]);
        CHECK(it.keyEquivalentModifierMask == NSEventModifierFlagCommand);
    }
    SECTION("Cmd + 0x7f28")
    { // Special treatment for Forward Delete
        [it nc_setKeyEquivalentWithShortcut:ActionShortcut{"⌘\u7f28"}];
        CHECK([it.keyEquivalent isEqualToString:@"\u007f"]);
        CHECK(it.keyEquivalentModifierMask == NSEventModifierFlagCommand);
    }
}

TEST_CASE(PREFIX "ActionShortcut(const EventData &_event)")
{
    // clang-format off
    // NOLINTBEGIN(readability-isolate-declaration)
    const ActionShortcut::EventData
    //                           mod        unmod   kc   mods
        a                       {'a',       'a',     0,   0},
        shift_a                 {'A',       'A',     0,   NSEventModifierFlagShift},
        shift_ctrl_a            {'\x01',    'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagControl},
        shift_ctrl_alt_a        {'\x01',    'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption},
        shift_ctrl_alt_cmd_a    {'\x01',    'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand},
        shift_ctrl_cmd_a        {'\x01',    'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagCommand},
        shift_alt_a             {U'å',      'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagOption},
        shift_alt_cmd_a         {U'å',      'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagOption|NSEventModifierFlagCommand},
        shift_cmd_a             {'a',       'A',     0,   NSEventModifierFlagShift|NSEventModifierFlagCommand},
        ctrl_a                  {'\x01',    'a',     0,   NSEventModifierFlagControl},
        ctrl_alt_a              {'\x01',    'a',     0,   NSEventModifierFlagControl|NSEventModifierFlagOption},
        ctrl_alt_cmd_a          {'\x01',    'a',     0,   NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand},
        ctrl_cmd_a              {'\x01',    'a',     0,   NSEventModifierFlagControl|NSEventModifierFlagCommand},
        alt_a                   {U'å',      'a',     0,   NSEventModifierFlagOption},
        alt_cmd_a               {U'å',      'a',     0,   NSEventModifierFlagOption|NSEventModifierFlagCommand},
        cmd_a                   {'a',       'a',     0,   NSEventModifierFlagCommand},
        b                       {'b',       'b',    11,   0},
        opsqbr                  {']',       ']',    30,   0},
        shift_opsqbr            {'}',       '}',    30,   NSEventModifierFlagShift},
        bckspc                  {'\x7F',    '\x7F', 51,   0},
        shift_bckspc            {'\x7F',    '\x7F', 51,   NSEventModifierFlagShift},
        ctrl_bckspc             {'\x7F',    '\x7F', 51,   NSEventModifierFlagControl},
        alt_bckspc              {'\x7F',    '\x7F', 51,   NSEventModifierFlagOption},
        cmd_bckspc              {'\x7F',    '\x7F', 51,   NSEventModifierFlagCommand}
    ;
    // NOLINTEND(readability-isolate-declaration)
    // clang-format on

    struct TestCase {
        const char *shortcut;
        ActionShortcut::EventData event;
        bool expected;
    } const test_cases[] = {
        // nop
        {.shortcut = "", .event = {}, .expected = true},
        {.shortcut = "", .event = a, .expected = false},
        {.shortcut = "", .event = b, .expected = false},
        // a
        {.shortcut = "a", .event = {}, .expected = false},
        {.shortcut = "a", .event = a, .expected = true},
        {.shortcut = "a", .event = b, .expected = false},
        {.shortcut = "a", .event = shift_a, .expected = false},
        {.shortcut = "a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "a", .event = shift_alt_a, .expected = false},
        {.shortcut = "a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "a", .event = ctrl_a, .expected = false},
        {.shortcut = "a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "a", .event = alt_a, .expected = false},
        {.shortcut = "a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "a", .event = cmd_a, .expected = false},
        // ⇧a
        {.shortcut = "⇧a", .event = {}, .expected = false},
        {.shortcut = "⇧a", .event = a, .expected = false},
        {.shortcut = "⇧a", .event = b, .expected = false},
        {.shortcut = "⇧a", .event = shift_a, .expected = true},
        {.shortcut = "⇧a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = alt_a, .expected = false},
        {.shortcut = "⇧a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧a", .event = cmd_a, .expected = false},
        // ⇧^a
        {.shortcut = "⇧^a", .event = {}, .expected = false},
        {.shortcut = "⇧^a", .event = a, .expected = false},
        {.shortcut = "⇧^a", .event = b, .expected = false},
        {.shortcut = "⇧^a", .event = shift_a, .expected = false},
        {.shortcut = "⇧^a", .event = shift_ctrl_a, .expected = true},
        {.shortcut = "⇧^a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧^a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧^a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = alt_a, .expected = false},
        {.shortcut = "⇧^a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧^a", .event = cmd_a, .expected = false},
        // ⇧^⌥a
        {.shortcut = "⇧^⌥a", .event = {}, .expected = false},
        {.shortcut = "⇧^⌥a", .event = a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = b, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_ctrl_alt_a, .expected = true},
        {.shortcut = "⇧^⌥a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = alt_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥a", .event = cmd_a, .expected = false},
        // ⇧^⌥⌘a
        {.shortcut = "⇧^⌥⌘a", .event = {}, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = b, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_ctrl_alt_cmd_a, .expected = true},
        {.shortcut = "⇧^⌥⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = alt_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌥⌘a", .event = cmd_a, .expected = false},
        // ⇧^⌘a
        {.shortcut = "⇧^⌘a", .event = {}, .expected = false},
        {.shortcut = "⇧^⌘a", .event = a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = b, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_ctrl_cmd_a, .expected = true},
        {.shortcut = "⇧^⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = alt_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧^⌘a", .event = cmd_a, .expected = false},
        // ⇧⌥a
        {.shortcut = "⇧⌥a", .event = {}, .expected = false},
        {.shortcut = "⇧⌥a", .event = a, .expected = false},
        {.shortcut = "⇧⌥a", .event = b, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_alt_a, .expected = true},
        {.shortcut = "⇧⌥a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = alt_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥a", .event = cmd_a, .expected = false},
        // ⇧⌥⌘a
        {.shortcut = "⇧⌥⌘a", .event = {}, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = b, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = shift_alt_cmd_a, .expected = true},
        {.shortcut = "⇧⌥⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = alt_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌥⌘a", .event = cmd_a, .expected = false},
        // ⇧⌘a
        {.shortcut = "⇧⌘a", .event = {}, .expected = false},
        {.shortcut = "⇧⌘a", .event = a, .expected = false},
        {.shortcut = "⇧⌘a", .event = b, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = shift_cmd_a, .expected = true},
        {.shortcut = "⇧⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = alt_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⇧⌘a", .event = cmd_a, .expected = false},
        // ^a
        {.shortcut = "^a", .event = {}, .expected = false},
        {.shortcut = "^a", .event = a, .expected = false},
        {.shortcut = "^a", .event = b, .expected = false},
        {.shortcut = "^a", .event = shift_a, .expected = false},
        {.shortcut = "^a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "^a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "^a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "^a", .event = shift_alt_a, .expected = false},
        {.shortcut = "^a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "^a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "^a", .event = ctrl_a, .expected = true},
        {.shortcut = "^a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "^a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "^a", .event = alt_a, .expected = false},
        {.shortcut = "^a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "^a", .event = cmd_a, .expected = false},
        // ^⌥a
        {.shortcut = "^⌥a", .event = {}, .expected = false},
        {.shortcut = "^⌥a", .event = a, .expected = false},
        {.shortcut = "^⌥a", .event = b, .expected = false},
        {.shortcut = "^⌥a", .event = shift_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_alt_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = ctrl_a, .expected = false},
        {.shortcut = "^⌥a", .event = ctrl_alt_a, .expected = true},
        {.shortcut = "^⌥a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = alt_a, .expected = false},
        {.shortcut = "^⌥a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "^⌥a", .event = cmd_a, .expected = false},
        // ^⌥⌘a
        {.shortcut = "^⌥⌘a", .event = {}, .expected = false},
        {.shortcut = "^⌥⌘a", .event = a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = b, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = ctrl_alt_cmd_a, .expected = true},
        {.shortcut = "^⌥⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = alt_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "^⌥⌘a", .event = cmd_a, .expected = false},
        // ^⌘a
        {.shortcut = "^⌘a", .event = {}, .expected = false},
        {.shortcut = "^⌘a", .event = a, .expected = false},
        {.shortcut = "^⌘a", .event = b, .expected = false},
        {.shortcut = "^⌘a", .event = shift_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "^⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "^⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "^⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "^⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "^⌘a", .event = ctrl_cmd_a, .expected = true},
        {.shortcut = "^⌘a", .event = alt_a, .expected = false},
        {.shortcut = "^⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "^⌘a", .event = cmd_a, .expected = false},
        // ⌥a
        {.shortcut = "⌥a", .event = {}, .expected = false},
        {.shortcut = "⌥a", .event = a, .expected = false},
        {.shortcut = "⌥a", .event = b, .expected = false},
        {.shortcut = "⌥a", .event = shift_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = ctrl_a, .expected = false},
        {.shortcut = "⌥a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⌥a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = alt_a, .expected = true},
        {.shortcut = "⌥a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⌥a", .event = cmd_a, .expected = false},
        // ⌥⌘a
        {.shortcut = "⌥⌘a", .event = {}, .expected = false},
        {.shortcut = "⌥⌘a", .event = a, .expected = false},
        {.shortcut = "⌥⌘a", .event = b, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = alt_a, .expected = false},
        {.shortcut = "⌥⌘a", .event = alt_cmd_a, .expected = true},
        {.shortcut = "⌥⌘a", .event = cmd_a, .expected = false},
        // ⌘a
        {.shortcut = "⌘a", .event = {}, .expected = false},
        {.shortcut = "⌘a", .event = a, .expected = false},
        {.shortcut = "⌘a", .event = b, .expected = false},
        {.shortcut = "⌘a", .event = shift_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_ctrl_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_ctrl_alt_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_ctrl_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_alt_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_alt_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = shift_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = ctrl_a, .expected = false},
        {.shortcut = "⌘a", .event = ctrl_alt_a, .expected = false},
        {.shortcut = "⌘a", .event = ctrl_alt_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = ctrl_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = alt_a, .expected = false},
        {.shortcut = "⌘a", .event = alt_cmd_a, .expected = false},
        {.shortcut = "⌘a", .event = cmd_a, .expected = true},
        // other
        {.shortcut = "]", .event = opsqbr, .expected = true},
        {.shortcut = "⇧}", .event = shift_opsqbr, .expected = true},
        {.shortcut = "\u007f", .event = bckspc, .expected = true},
        {.shortcut = "\u007f", .event = shift_bckspc, .expected = false},
    };

    for( auto &test_case : test_cases ) {
        INFO(fmt::format("'{}' {} {} {} {} {}",
                         test_case.shortcut,
                         test_case.event.char_with_modifiers,
                         test_case.event.char_without_modifiers,
                         test_case.event.modifiers,
                         test_case.event.key_code,
                         test_case.expected));
        const ActionShortcut manual_shortcut = ActionShortcut{test_case.shortcut};
        const ActionShortcut event_shortcut = ActionShortcut{test_case.event};
        const bool equal = manual_shortcut == event_shortcut;
        CHECK(equal == test_case.expected);
    }
}
