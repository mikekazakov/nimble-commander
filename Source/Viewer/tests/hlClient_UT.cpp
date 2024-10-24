// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/Client.h"
#include <Base/mach_time.h>
#include <CoreFoundation/CoreFoundation.h>
#include <ankerl/unordered_dense.h>
#include <fmt/format.h>

using namespace nc::viewer::hl;

#define PREFIX "hl::Client "

[[clang::no_destroy]] static const ankerl::unordered_dense::map<char, nc::viewer::hl::Style> m{
    {'D', nc::viewer::hl::Style::Default},
    {'C', nc::viewer::hl::Style::Comment},
    {'W', nc::viewer::hl::Style::Keyword},
    {'P', nc::viewer::hl::Style::Preprocessor},
    {'N', nc::viewer::hl::Style::Number},
    {'O', nc::viewer::hl::Style::Operator},
    {'I', nc::viewer::hl::Style::Identifier},
    {'S', nc::viewer::hl::Style::String},
};

static bool
WaitWithRunloop(std::chrono::nanoseconds _timeout, std::chrono::nanoseconds _slice, std::function<bool()> _done)
{
    const auto deadline = nc::base::machtime() + _timeout;
    do {
        if( _done() ) {
            return true;
        }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, std::chrono::duration<double>(_slice).count(), false);
    } while( deadline > nc::base::machtime() );
    return false;
}

TEST_CASE(PREFIX "Connectivity test")
{
    const std::string settings = R"({
        "lexer": "cpp",
        "wordlists": ["int"],
        "mapping": {
            "SCE_C_WORD": "keyword",
            "SCE_C_PREPROCESSOR": "preprocessor",
            "SCE_C_NUMBER": "number",
            "SCE_C_OPERATOR": "operator",
            "SCE_C_IDENTIFIER": "identifier",
            "SCE_C_COMMENT": "comment"
        }
    })";
    const std::string text =
        R"(#pragma once
/*Hey!*/
int hello = 10;)";
    const std::string hl_exp = "PPPPPPPPPPPPP"
                               "CCCCCCCCD"
                               "WWWDIIIIIDODNNO";
    REQUIRE(text.length() == hl_exp.length());

    auto hl = Client::Highlight(text, settings).value();

    REQUIRE(hl.size() == hl_exp.size());

    for( size_t i = 0; i < hl.size(); ++i ) {
        CHECK(hl[i] == m.at(hl_exp[i]));
    }
}

TEST_CASE(PREFIX "Async connectivity test")
{
    const std::string settings = R"({
        "lexer": "cpp",
        "wordlists": ["int"],
        "mapping": {
            "SCE_C_WORD": "keyword",
            "SCE_C_PREPROCESSOR": "preprocessor",
            "SCE_C_NUMBER": "number",
            "SCE_C_OPERATOR": "operator",
            "SCE_C_IDENTIFIER": "identifier",
            "SCE_C_COMMENT": "comment"
        }
    })";
    const std::string text =
        R"(#pragma once
/*Hey!*/
int hello = 10;)";
    const std::string hl_exp = "PPPPPPPPPPPPP"
                               "CCCCCCCCD"
                               "WWWDIIIIIDODNNO";
    REQUIRE(text.length() == hl_exp.length());

    std::expected<std::vector<nc::viewer::hl::Style>, std::string> hl;
    bool done = false;

    Client::HighlightAsync(text, settings, [&](std::expected<std::vector<nc::viewer::hl::Style>, std::string> _styles) {
        hl = std::move(_styles);
        done = true;
    });

    REQUIRE(WaitWithRunloop(std::chrono::seconds{60}, std::chrono::milliseconds{1}, [&] { return done; }));
    REQUIRE(hl);
    REQUIRE(hl->size() == hl_exp.size());
    for( size_t i = 0; i < hl->size(); ++i ) {
        CHECK(hl->at(i) == m.at(hl_exp[i]));
    }
}

TEST_CASE(PREFIX "Reacting to broken JSON")
{
    const std::string settings = "definitely not a JSON";
    const std::string text;
    auto hl = Client::Highlight(text, settings);
    REQUIRE(!hl.has_value());
    CHECK(hl.error().contains("Unable to parse the lexing settings"));
}

TEST_CASE(PREFIX "Reacting to non-existing lexer")
{
    const std::string settings = R"({
        "lexer": "I don't exist!"
    })";
    const std::string text;
    auto hl = Client::Highlight(text, settings);
    REQUIRE(!hl.has_value());
    CHECK(hl.error().contains("Unable to highlight the document"));
}

TEST_CASE(PREFIX "Reacting to non-existing option")
{
    const std::string settings = R"({
        "lexer": "cpp",
        "wordlists": ["int"],
        "properties": {
            "lexer.json.escape.sequence": "1",
            "lexer.json.allow.comments": "1"
        },
        "mapping": {
            "SCE_C_WORD": "keyword",
            "SCE_C_PREPROCESSOR": "preprocessor",
            "SCE_C_NUMBER": "number",
            "SCE_C_OPERATOR": "operator",
            "SCE_C_IDENTIFIER": "identifier",
            "SCE_C_COMMENT": "comment"
        }
    })";
    const std::string text;
    auto hl = Client::Highlight(text, settings);
    REQUIRE(!hl.has_value());
    CHECK(hl.error().contains("Unable to highlight the document"));
}

TEST_CASE(PREFIX "Reacting to non-existing mapping source")
{
    const std::string settings = R"({
        "lexer": "cpp",
        "mapping": {
            "Hey!": "keyword"
        }
    })";
    const std::string text;
    auto hl = Client::Highlight(text, settings);
    REQUIRE(!hl.has_value());
    CHECK(hl.error().contains("Unable to parse the lexing settings"));
}

TEST_CASE(PREFIX "Reacting to non-existing mapping target")
{
    const std::string settings = R"({
        "lexer": "cpp",
        "mapping": {
            "SCE_C_COMMENT": "Hey!"
        }
    })";
    const std::string text;
    auto hl = Client::Highlight(text, settings);
    REQUIRE(!hl.has_value());
    CHECK(hl.error().contains("Unable to parse the lexing settings"));
}
