// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/Highlighter.h"
#include <lexilla/SciLexer.h>
#include <ankerl/unordered_dense.h>

using namespace nc::viewer::hl;

#define PREFIX "hl::Highlighter "

[[clang::no_destroy]] static const ankerl::unordered_dense::map<char, Style> m{
    {'D', Style::Default},
    {'C', Style::Comment},
    {'W', Style::Keyword},
    {'P', Style::Preprocessor},
    {'N', Style::Number},
    {'O', Style::Operator},
    {'I', Style::Identifier},
    {'S', Style::String},
};

TEST_CASE(PREFIX "Regular use with C++ lexer")
{
    LexerSettings set;
    set.name = "cpp";
    set.wordlists.emplace_back("int");
    set.mapping.SetMapping(SCE_C_DEFAULT, Style::Default);
    set.mapping.SetMapping(SCE_C_COMMENT, Style::Comment);
    set.mapping.SetMapping(SCE_C_COMMENTLINE, Style::Comment);
    set.mapping.SetMapping(SCE_C_WORD, Style::Keyword);
    set.mapping.SetMapping(SCE_C_PREPROCESSOR, Style::Preprocessor);
    set.mapping.SetMapping(SCE_C_NUMBER, Style::Number);
    set.mapping.SetMapping(SCE_C_OPERATOR, Style::Operator);
    set.mapping.SetMapping(SCE_C_IDENTIFIER, Style::Identifier);
    set.mapping.SetMapping(SCE_C_STRING, Style::String);

    const std::string src =
        R"(#pragma once
/*Hey!*/
int hello = 10;)";
    const std::string hl_exp = "PPPPPPPPPPPPP"
                               "CCCCCCCCD"
                               "WWWDIIIIIDODNNO";

    REQUIRE(src.length() == hl_exp.length());

    const Highlighter highlighter(set);
    std::vector<Style> hl = highlighter.Highlight(src);
    REQUIRE(hl.size() == hl_exp.size());

    for( size_t i = 0; i < hl.size(); ++i ) {
        CHECK(hl[i] == m.at(hl_exp[i]));
    }
}

TEST_CASE(PREFIX "Regular use with YAML lexer")
{
    LexerSettings set;
    set.name = "yaml";
    set.mapping.SetMapping(SCE_YAML_DEFAULT, Style::Default);
    set.mapping.SetMapping(SCE_YAML_COMMENT, Style::Comment);
    set.mapping.SetMapping(SCE_YAML_KEYWORD, Style::Keyword);
    set.mapping.SetMapping(SCE_YAML_NUMBER, Style::Number);
    set.mapping.SetMapping(SCE_YAML_REFERENCE, Style::Identifier);
    set.mapping.SetMapping(SCE_YAML_DOCUMENT, Style::Identifier);
    set.mapping.SetMapping(SCE_YAML_OPERATOR, Style::Operator);
    set.mapping.SetMapping(SCE_YAML_IDENTIFIER, Style::Identifier);
    set.mapping.SetMapping(SCE_YAML_TEXT, Style::String);

    const std::string src =
        R"(name: Build and Test #Hey!
on:
  push:
    paths-ignore:
      - '.github/ISSUE_TEMPLATE/**')";

    const std::string hl_exp = "IIIIODDDDDDDDDDDDDDDDCCCCCC"
                               "IIOD"
                               "IIIIIIOD"
                               "IIIIIIIIIIIIIIIIOD"
                               "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD";

    REQUIRE(src.length() == hl_exp.length());

    const Highlighter highlighter(set);
    std::vector<Style> hl = highlighter.Highlight(src);
    REQUIRE(hl.size() == hl_exp.size());

    for( size_t i = 0; i < hl.size(); ++i ) {
        CHECK(hl[i] == m.at(hl_exp[i]));
    }
}

TEST_CASE(PREFIX "Regular use with Bash lexer")
{
    LexerSettings set;
    set.name = "bash";
    set.wordlists.emplace_back("set if command then echo exit fi export");
    set.mapping.SetMapping(SCE_SH_DEFAULT, Style::Default);
    set.mapping.SetMapping(SCE_SH_ERROR, Style::Default);
    set.mapping.SetMapping(SCE_SH_COMMENTLINE, Style::Comment);
    set.mapping.SetMapping(SCE_SH_HERE_DELIM, Style::Comment);
    set.mapping.SetMapping(SCE_SH_HERE_Q, Style::Comment);
    set.mapping.SetMapping(SCE_SH_WORD, Style::Keyword);
    set.mapping.SetMapping(SCE_SH_NUMBER, Style::Number);
    set.mapping.SetMapping(SCE_SH_SCALAR, Style::Number);
    set.mapping.SetMapping(SCE_SH_IDENTIFIER, Style::Identifier);
    set.mapping.SetMapping(SCE_SH_OPERATOR, Style::Operator);
    set.mapping.SetMapping(SCE_SH_BACKTICKS, Style::Operator);
    set.mapping.SetMapping(SCE_SH_PARAM, Style::Identifier);
    set.mapping.SetMapping(SCE_SH_STRING, Style::String);
    set.mapping.SetMapping(SCE_SH_CHARACTER, Style::String);

    const std::string src =
        R"Z(#!/bin/sh
set -e
set -o pipefail
if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8)Z";

    const std::string hl_exp = "CCCCCCCCCD"
                               "WWWDIID"
                               "WWWDIIDIIIIIIIID"
                               "WWDODODWWDSSSSSSSSSSSSSSSSSSSSSSSSDODODWWWWD"
                               "DDDDWWWWDSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSD"
                               "DDDDWWWWDOND"
                               "WWD"
                               "D"
                               "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCD"
                               "WWWWWWDIIIIIIIIOIIIIIIIIIII";

    REQUIRE(src.length() == hl_exp.length());

    const Highlighter highlighter(set);
    std::vector<Style> hl = highlighter.Highlight(src);
    REQUIRE(hl.size() == hl_exp.size());

    for( size_t i = 0; i < hl.size(); ++i ) {
        CHECK(hl[i] == m.at(hl_exp[i]));
    }
}
