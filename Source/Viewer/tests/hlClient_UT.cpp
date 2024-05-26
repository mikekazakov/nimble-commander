// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/Client.h"
#include <robin_hood.h>

using namespace nc::viewer::hl;

#define PREFIX "hl::Client "

[[clang::no_destroy]] static const robin_hood::unordered_flat_map<char, Style> m{
    {'D', Style::Default},
    {'C', Style::Comment},
    {'W', Style::Keyword},
    {'P', Style::Preprocessor},
    {'N', Style::Number},
    {'O', Style::Operator},
    {'I', Style::Identifier},
    {'S', Style::String},
};

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

    Client cl;
    auto hl = cl.Highlight(text, settings);

    REQUIRE(hl.size() == hl_exp.size());

    for( size_t i = 0; i < hl.size(); ++i ) {
        CHECK(hl[i] == m.at(hl_exp[i]));
    }
}
