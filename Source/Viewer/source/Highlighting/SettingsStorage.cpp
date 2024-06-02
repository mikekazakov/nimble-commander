// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/SettingsStorage.h>
#include <fstream>
#include <nlohmann/json.hpp>
#include <ranges>
#include <fmt/format.h>
using json = nlohmann::json;

namespace nc::viewer::hl {

std::string DummySettingsStorage::Language(std::string_view _filename)
{
    (void)_filename;
    return {};
}

std::shared_ptr<const std::string> DummySettingsStorage::Settings(std::string_view _lang)
{
    (void)_lang;

    const auto settings = R"({
        "lexer": "cpp",
        "wordlists": ["alignas alignof and and_eq asm auto bitand bitor bool break case catch char char8_t char16_t char32_t class compl concept const consteval constexpr constinit const_cast continue co_await co_return co_yield decltype default delete do double dynamic_cast else enum explicit export extern false float for friend goto if inline int long mutable namespace new noexcept not not_eq nullptr operator or or_eq private protected public register reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while xor xor_eq"],
        "mapping": {
            "SCE_C_DEFAULT": "default",
            "SCE_C_COMMENT": "comment",
            "SCE_C_COMMENTLINE": "comment",
            "SCE_C_COMMENTDOC": "comment",
            "SCE_C_NUMBER": "number",
            "SCE_C_WORD": "keyword",
            "SCE_C_STRING": "string",
            "SCE_C_CHARACTER": "string",
            "SCE_C_UUID": "string",
            "SCE_C_PREPROCESSOR": "preprocessor",
            "SCE_C_OPERATOR": "operator",
            "SCE_C_IDENTIFIER": "identifier",
            "SCE_C_STRINGEOL": "string"
        }
    })";
    [[clang::no_destroy]] static auto ptr = std::make_shared<std::string>(settings);
    return ptr;
}

// TODO: logging
// TODO: error handling

FileSettingsStorage::FileSettingsStorage(const std::filesystem::path &_base_dir,
                                         const std::filesystem::path &_overrides_dir)
    : m_BaseDir(_base_dir)
{
    (void)_overrides_dir;
    LoadLangs();
}

void FileSettingsStorage::LoadLangs()
{
    std::ifstream f(m_BaseDir / "Main.json");
    json data = json::parse(f);

    m_Langs.clear();
    if( data.contains("langs") ) {
        auto &langs = data.at("langs");
        for( auto it = langs.begin(); it != langs.end(); ++it ) {
            std::string name = it->at("name");
            std::string settings = it->at("settings");
            std::string filemask = it->at("filemask");
            if( name.empty() || settings.empty() || filemask.empty() ) {
                continue;
            }

            // TODO: check that the lang is unique

            Lang lang;
            lang.name = name;
            lang.settings_filename = settings;
            lang.mask = utility::FileMask(filemask, utility::FileMask::Type::Mask);
            m_Langs.push_back(std::move(lang));
        }
    }
}

std::string FileSettingsStorage::Language(std::string_view _filename)
{
    for( auto &lang : m_Langs ) {
        if( lang.mask.MatchName(_filename) ) {
            return lang.name;
        }
    }
    return {};
}

std::shared_ptr<const std::string> FileSettingsStorage::Settings(std::string_view _lang)
{
    if( auto sett_it = m_Settings.find(_lang); sett_it != m_Settings.end() ) {
        return sett_it->second;
    }

    auto lang_it = std::ranges::find_if(m_Langs, [&](auto &lang) { return lang.name == _lang; });
    if( lang_it == m_Langs.end() ) {
        return {};
    }

    const std::filesystem::path settings_path = m_BaseDir / lang_it->settings_filename;
    std::ifstream ifs{settings_path};
    if( ifs ) {
        std::string text((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
        auto shared = std::make_shared<std::string>(std::move(text));
        m_Settings.emplace(_lang, shared);
        return shared;
    }
    else {
        m_Settings.emplace(_lang, nullptr);
        return {};
    }
}

} // namespace nc::viewer::hl
