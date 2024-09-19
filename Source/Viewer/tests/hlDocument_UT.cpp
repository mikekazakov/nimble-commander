// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/Document.h"

#include <scintilla/ILexer.h>
#include <lexilla/Lexilla.h>
#include <lexilla/WordList.h>
#include <lexilla/LexAccessor.h>
#include <lexilla/Accessor.h>
#include <lexilla/CharacterSet.h>
#include <lexilla/LexerModule.h>
#include <lexilla/CatalogueModules.h>
#include <lexilla/SciLexer.h>
#include <unordered_map>

using namespace nc::viewer::hl;

#define PREFIX "hl::Document "

TEST_CASE(PREFIX "Check integration with a lexer")
{
    Scintilla::ILexer5 *lexer = CreateLexer("cpp");
    lexer->WordListSet(0, "int");

    std::unordered_map<char, char> m;
    m['D'] = 0;
    m['C'] = SCE_C_COMMENT;
    m['L'] = SCE_C_COMMENTLINE;
    m['W'] = SCE_C_WORD;
    m['P'] = SCE_C_PREPROCESSOR;
    m['N'] = SCE_C_NUMBER;
    m['O'] = SCE_C_OPERATOR;
    m['I'] = SCE_C_IDENTIFIER;
    m['S'] = SCE_C_STRING;

    // clang-format off
    struct TC {
        std::string text;
        std::string styles;
    } const tcs[] = {
        {"",
         ""},
        {"int",
         "WWW" },
        {"hello",
         "IIIII"},
        {"#pragma once\x0A/*Hey!*/ int hello = 10;",
         "PPPPPPPPPPPPP" "CCCCCCCCDWWWDIIIIIDODNNO"
        },
        {"//hi!",
         "LLLLL"},
        {"\"hi!\"",
         "SSSSS"},
        {"//line 1\x0Ahi2;\x0A//line 3\x0Ahi4",
         "LLLLLLLLL" "IIIOD" "LLLLLLLLL" "III"
        },
        {"//line 1\x0D\x0Ahi2;\x0D\x0A//line 3\x0D\x0Ahi4",
         "LLLLLLLLLL"    "IIIODD"    "LLLLLLLLLL"    "III"
        },
        {"/*line 1*/\x0D\x0A",
         "CCCCCCCCCCDD"
        },
        {"\x0A\x0A\x0A\x0A!",
         "D" "D" "D" "D" "O"
        },
        {"int привет=10;",
         "WWWDIIIIIIIIIIIIONNO"
        },
        {"int ꮚ=10;",
         "WWWDIIIONNO"
        },
        {"int 🤡=10;",
         "WWWDIIIIONNO"
        },
    };
    // clang-format on

    for( const auto &tc : tcs ) {
        REQUIRE(tc.text.size() == tc.styles.size());
        Document doc(tc.text);
        lexer->Lex(0, doc.Length(), 0, &doc);
        for( size_t i = 0; i < tc.text.length(); ++i ) {
            CHECK(doc.StyleAt(i) == m[tc.styles[i]]);
        }
    }
    lexer->Release();
}

TEST_CASE(PREFIX "Line breaks - LineStart/LineEnd")
{
    struct TC {
        std::string text;
        std::vector<long> starts;
        std::vector<long> ends;
    } const tcs[] = {
        {"", {}, {}},
        {"a", {0}, {1}},
        {"aa", {0}, {2}},
        {"Ц", {0}, {2}},
        {"aaa", {0}, {3}},
        {"a\x0A", {0}, {2}}, // wrong??
        {"\x0A", {0}, {1}},  // wrong??
        {"\x0A\x0A", {0, 1}, {0, 2}},
        {"\x0D\x0A\x0D\x0A", {0, 2}, {0, 4}},
        {"a\x0Az", {0, 2}, {1, 3}},
        {"a\x0D\x0Az", {0, 3}, {1, 4}},
        {"xyz\x0Axyz\x0Axyz", {0, 4, 8}, {3, 7, 11}},
        {"xyz\x0D\x0Axyz\x0D\x0Axyz", {0, 5, 10}, {3, 8, 13}},
    };

    for( const auto &tc : tcs ) {
        REQUIRE(tc.starts.size() == tc.ends.size());
        const Document doc(tc.text);

        for( size_t l = 0; l < tc.starts.size(); ++l ) {
            CHECK(doc.LineStart(l) == tc.starts[l]);
        }

        for( size_t l = 0; l < tc.starts.size(); ++l ) {
            CHECK(doc.LineEnd(l) == tc.ends[l]);
        }

        // OOB - lower
        CHECK(doc.LineStart(-1) == 0);
        CHECK(doc.LineEnd(-1) == 0);

        // OOB - higher
        CHECK(doc.LineStart(tc.starts.size()) == static_cast<long>(tc.text.size()));
        CHECK(doc.LineEnd(tc.starts.size()) == static_cast<long>(tc.text.size()));
    }
}
