// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <vector>
#include "Style.h"
#include "LexerSettings.h"

namespace Scintilla {
class ILexer5;
}

namespace nc::viewer::hl {

class Highlighter
{
public:
    Highlighter(LexerSettings _settings);
    Highlighter(const Highlighter &) = delete;
    ~Highlighter();
    Highlighter &operator=(const Highlighter &) = delete;

    std::vector<Style> Highlight(std::string_view _text) const;

private:
    LexerSettings m_Settings;
    Scintilla::ILexer5 *m_Lexer = nullptr;
};

} // namespace nc::viewer::hl
