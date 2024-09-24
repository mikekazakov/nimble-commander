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
        {.text="",
         .styles=""},
        {.text="int",
         .styles="WWW" },
        {.text="hello",
         .styles="IIIII"},
        {.text="#pragma once\x0A/*Hey!*/ int hello = 10;",
         .styles="PPPPPPPPPPPPP" "CCCCCCCCDWWWDIIIIIDODNNO"
        },
        {.text="//hi!",
         .styles="LLLLL"},
        {.text="\"hi!\"",
         .styles="SSSSS"},
        {.text="//line 1\x0Ahi2;\x0A//line 3\x0Ahi4",
         .styles="LLLLLLLLL" "IIIOD" "LLLLLLLLL" "III"
        },
        {.text="//line 1\x0D\x0Ahi2;\x0D\x0A//line 3\x0D\x0Ahi4",
         .styles="LLLLLLLLLL"    "IIIODD"    "LLLLLLLLLL"    "III"
        },
        {.text="/*line 1*/\x0D\x0A",
         .styles="CCCCCCCCCCDD"
        },
        {.text="\x0A\x0A\x0A\x0A!",
         .styles="D" "D" "D" "D" "O"
        },
        {.text="int привет=10;",
         .styles="WWWDIIIIIIIIIIIIONNO"
        },
        {.text="int ꮚ=10;",
         .styles="WWWDIIIONNO"
        },
        {.text="int 🤡=10;",
         .styles="WWWDIIIIONNO"
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
        {.text = "", .starts = {}, .ends = {}},
        {.text = "a", .starts = {0}, .ends = {1}},
        {.text = "aa", .starts = {0}, .ends = {2}},
        {.text = "Ц", .starts = {0}, .ends = {2}},
        {.text = "aaa", .starts = {0}, .ends = {3}},
        {.text = "a\x0A", .starts = {0}, .ends = {2}}, // wrong??
        {.text = "\x0A", .starts = {0}, .ends = {1}},  // wrong??
        {.text = "\x0A\x0A", .starts = {0, 1}, .ends = {0, 2}},
        {.text = "\x0D\x0A\x0D\x0A", .starts = {0, 2}, .ends = {0, 4}},
        {.text = "a\x0Az", .starts = {0, 2}, .ends = {1, 3}},
        {.text = "a\x0D\x0Az", .starts = {0, 3}, .ends = {1, 4}},
        {.text = "xyz\x0Axyz\x0Axyz", .starts = {0, 4, 8}, .ends = {3, 7, 11}},
        {.text = "xyz\x0D\x0Axyz\x0D\x0Axyz", .starts = {0, 5, 10}, .ends = {3, 8, 13}},
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
