// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/Document.h>
#include <Viewer/Highlighting/Highlighter.h>
#include <cassert>
#include <fmt/format.h>

#include <lexilla/Lexilla.h>          // NOLINT
#include <lexilla/WordList.h>         // NOLINT
#include <lexilla/LexAccessor.h>      // NOLINT
#include <lexilla/Accessor.h>         // NOLINT
#include <lexilla/CharacterSet.h>     // NOLINT
#include <lexilla/LexerModule.h>      // NOLINT
#include <lexilla/CatalogueModules.h> // NOLINT
#include <lexilla/SciLexer.h>         // NOLINT

namespace nc::viewer::hl {

Highlighter::Highlighter(LexerSettings _settings) : m_Settings(std::move(_settings))
{
    m_Lexer = CreateLexer(m_Settings.name.c_str());
    if( m_Lexer == nullptr ) {
        throw std::invalid_argument(fmt::format("Unable to create a lexer named '{}'.", m_Settings.name));
    }

    for( int i = 0; i < static_cast<int>(m_Settings.wordlists.size()); ++i ) {
        const long rc = m_Lexer->WordListSet(i, m_Settings.wordlists[i].c_str());
        if( rc < 0 ) {
            m_Lexer->Release();
            throw std::invalid_argument(
                fmt::format("Failed to set the wordlist #{}: '{}'.", i, m_Settings.wordlists[i]));
        }
    }

    for( const auto &property : m_Settings.properties ) {
        const long rc = m_Lexer->PropertySet(property.key.c_str(), property.value.c_str());
        if( rc < 0 ) {
            m_Lexer->Release();
            throw std::invalid_argument(
                fmt::format("Failed to set the property '{}'='{}'.", property.key, property.value));
        }
    }
}

Highlighter::~Highlighter()
{
    assert(m_Lexer != nullptr);
    m_Lexer->Release();
}

std::vector<Style> Highlighter::Highlight(std::string_view _text) const
{
    Document doc(_text);
    m_Lexer->Lex(0, doc.Length(), 0, &doc);
    const std::span<const char> lex_styles = doc.Styles();
    std::vector<Style> nc_styles(lex_styles.size());
    m_Settings.mapping.MapStyles(lex_styles, nc_styles);
    return nc_styles;
}

} // namespace nc::viewer::hl
