// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/Highlighter.h"
#include <lexilla/SciLexer.h>

using namespace nc::viewer::hl;

#define PREFIX "hl::Highlighter "

TEST_CASE(PREFIX "Regular use with C++ lexer")
{
    LexerSettings set;
    set.name = "cpp";
    set.wordlists.push_back("int");
    set.mapping.SetMapping(SCE_C_DEFAULT, Style::Default);
    set.mapping.SetMapping(SCE_C_COMMENT, Style::Comment);
    set.mapping.SetMapping(SCE_C_COMMENTLINE, Style::Comment);
    set.mapping.SetMapping(SCE_C_WORD, Style::Keyword);
    set.mapping.SetMapping(SCE_C_PREPROCESSOR, Style::Preprocessor);
    set.mapping.SetMapping(SCE_C_NUMBER, Style::Number);
    set.mapping.SetMapping(SCE_C_OPERATOR, Style::Operator);
    set.mapping.SetMapping(SCE_C_IDENTIFIER, Style::Identifier);
    set.mapping.SetMapping(SCE_C_STRING, Style::String);

    std::unordered_map<char, Style> m;
    m['D'] = Style::Default;
    m['C'] = Style::Comment;
    m['W'] = Style::Keyword;
    m['P'] = Style::Preprocessor;
    m['N'] = Style::Number;
    m['O'] = Style::Operator;
    m['I'] = Style::Identifier;
    m['S'] = Style::String;

    const std::string src =
        R"(#pragma once
/*Hey!*/
int hello = 10;)";
    const std::string hl_exp = "PPPPPPPPPPPPP"
                               "CCCCCCCCD"
                               "WWWDIIIIIDODNNO";

    REQUIRE(src.length() == hl_exp.length());

    Highlighter highlighter(set);
    std::vector<Style> hl = highlighter.Highlight(src);
    REQUIRE(hl.size() == hl_exp.size());

    for( size_t i = 0; i < hl.size(); ++i ) {
        CHECK(hl[i] == m.at(hl_exp[i]));
    }
}
