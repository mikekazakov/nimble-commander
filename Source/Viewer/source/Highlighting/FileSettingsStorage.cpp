// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/FileSettingsStorage.h>
#include <fstream>
#include <nlohmann/json.hpp>
#include <ranges>
#include <fmt/format.h>

using json = nlohmann::json;

namespace nc::viewer::hl {

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
