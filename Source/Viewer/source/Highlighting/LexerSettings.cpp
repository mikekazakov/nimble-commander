// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/LexerSettings.h>
#include <lexilla/SciLexerStyleNames.h>
#include <nlohmann/json.hpp>
#include <frozen/unordered_map.h>
#include <frozen/string.h>
#include <ankerl/unordered_dense.h>
#include <fmt/format.h>
#include <map>

namespace nc::viewer::hl {

using json = nlohmann::json;

[[clang::no_destroy]] static const ankerl::unordered_dense::map<std::string_view, char> g_SCENames = [] {
    static_assert(std::size(Lexilla::g_SCENames) == std::size(Lexilla::g_SCEValues));
    const size_t len = std::size(Lexilla::g_SCENames);
    ankerl::unordered_dense::map<std::string_view, char> names;
    names.reserve(len);
    for( size_t i = 0; i < len; ++i ) {
        names.emplace(Lexilla::g_SCENames[i], Lexilla::g_SCEValues[i]);
    }
    return names;
}();

static constinit frozen::unordered_map<frozen::string, Style, 8> g_MappedStyles{
    {"default", Style::Default},           //
    {"comment", Style::Comment},           //
    {"preprocessor", Style::Preprocessor}, //
    {"keyword", Style::Keyword},           //
    {"operator", Style::Operator},         //
    {"identifier", Style::Identifier},     //
    {"number", Style::Number},             //
    {"string", Style::String}              //
};

std::expected<LexerSettings, std::string> ParseLexerSettings(std::string_view _json) noexcept
{
    try {
        json json_obj = json::parse(_json, nullptr, true, true);

        LexerSettings sets;
        sets.name = json_obj.at("lexer");

        if( json_obj.contains("wordlists") ) {
            sets.wordlists = json_obj.at("wordlists").get<std::vector<std::string>>();
        }

        if( json_obj.contains("properties") ) {
            auto &props = json_obj.at("properties");
            for( auto it = props.begin(); it != props.end(); ++it ) {
                sets.properties.push_back({it.key(), it.value()});
            }
        }

        if( json_obj.contains("mapping") ) {
            auto &mapping = json_obj.at("mapping");
            for( auto it = mapping.begin(); it != mapping.end(); ++it ) {
                std::string key = it.key();
                std::string value = it.value();

                auto key_it = g_SCENames.find(key);
                if( key_it == g_SCENames.end() ) {
                    return std::unexpected{fmt::format("Unknown style '{}'", key)};
                }

                auto value_it = g_MappedStyles.find(frozen::string(value));
                if( value_it == g_MappedStyles.end() ) {
                    return std::unexpected{fmt::format("Unknown style '{}'", value)};
                }

                sets.mapping.SetMapping(key_it->second, value_it->second);
            }
        }

        return sets;
    } catch( std::exception &e ) {
        return std::unexpected{fmt::format("Failed to parse JSON: {}", e.what())};
    }
}

} // namespace nc::viewer::hl
