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
