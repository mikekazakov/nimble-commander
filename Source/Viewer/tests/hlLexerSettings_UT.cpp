// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/LexerSettings.h"
#include <lexilla/SciLexer.h>

using namespace nc::viewer::hl;

#define PREFIX "hl::LexerSettings "

TEST_CASE(PREFIX "Load from a JSON")
{
    const std::string json = R"({
        "lexer": "cpp",
        "wordlists": ["int float char", "enum class"],
        "properties": {
            "some key1": "some val1",
            "some key2": "some val2"
        },
        "mapping": {
            "SCE_C_WORD": "keyword",
            "SCE_C_PREPROCESSOR": "preprocessor",
            "SCE_C_NUMBER": "number"
        }
    })";

    auto sets = ParseLexerSettings(json);
    REQUIRE(sets.has_value());

    CHECK(sets->name == "cpp");
    CHECK(sets->wordlists == std::vector<std::string>{"int float char", "enum class"});
    CHECK(sets->properties == std::vector<LexerSettings::Property>{LexerSettings::Property{"some key1", "some val1"},
                                                                   LexerSettings::Property{"some key2", "some val2"}});

    const std::vector<char> in{SCE_C_WORD, SCE_C_STRING, SCE_C_PREPROCESSOR, SCE_C_NUMBER};
    std::vector<Style> out(in.size());
    sets->mapping.MapStyles(in, out);
    CHECK(out == std::vector<Style>{Style::Keyword, Style::Default, Style::Preprocessor, Style::Number});
}
