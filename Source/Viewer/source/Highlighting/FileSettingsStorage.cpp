// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/FileSettingsStorage.h>
#include <Viewer/Log.h>
#include <fstream>
#include <nlohmann/json.hpp>
#include <ranges>
#include <fmt/format.h>

using json = nlohmann::json;

namespace nc::viewer::hl {

[[clang::no_destroy]] static const std::filesystem::path g_MainFile = "Main.json";

FileSettingsStorage::FileSettingsStorage(const std::filesystem::path &_base_dir,
                                         const std::filesystem::path &_overrides_dir)
    : m_BaseDir(_base_dir)
{
    (void)_overrides_dir;
    m_Langs = LoadLangs();
}

std::vector<FileSettingsStorage::Lang> FileSettingsStorage::LoadLangs()
{
    const std::filesystem::path main_path = m_BaseDir / g_MainFile;

    Log::Debug(SPDLOC, "Loading languages definitions from '{}'", main_path.native());

    std::ifstream f(main_path);
    if( !f.is_open() ) {
        Log::Error(SPDLOC, "Unable to open the file '{}'", main_path.native());
        throw std::invalid_argument(fmt::format("Unable to open the file '{}'", main_path.native()));
    }

    json data;
    try {
        data = json::parse(f);
    } catch( std::exception &ex ) {
        Log::Error(SPDLOC, "Unable to parse '{}': {}", main_path.native());
        throw std::invalid_argument(fmt::format("Unable to parse '{}': {}", main_path.native(), ex.what()));
    }

    if( !data.contains("langs") ) {
        Log::Error(SPDLOC, "Invalid JSON format '{}': no 'langs' array", main_path.native());
        throw std::invalid_argument(fmt::format("Invalid JSON format '{}': no 'langs' array", main_path.native()));
    }

    std::vector<FileSettingsStorage::Lang> output;
    try {
        auto &langs = data.at("langs");
        for( auto it = langs.begin(); it != langs.end(); ++it ) {
            std::string name = it->at("name");
            if( name.empty() ) {
                throw std::invalid_argument("empty name is not allowed");
            }

            std::string settings = it->at("settings");
            if( settings.empty() ) {
                throw std::invalid_argument("empty settings is not allowed");
            }

            const std::string filemask = it->at("filemask");
            if( filemask.empty() ) {
                throw std::invalid_argument("empty filemask is not allowed");
            }

            Lang lang;
            lang.name = std::move(name);
            lang.settings_filename = std::move(settings);
            lang.mask = utility::FileMask(filemask, utility::FileMask::Type::Mask);
            output.push_back(std::move(lang));
        }

    } catch( std::exception &ex ) {
        Log::Error(SPDLOC, "Parse error in '{}': {}", main_path.native(), ex.what());
        throw std::invalid_argument(fmt::format("Parse error in '{}': {}", main_path.native(), ex.what()));
    }

    robin_hood::unordered_flat_set<std::string_view, RHTransparentStringHashEqual, RHTransparentStringHashEqual> set;
    set.reserve(output.size());
    for( auto &lang : output ) {
        if( set.contains(lang.name) ) {
            Log::Error(SPDLOC, "The language '{}' is defined more than once", lang.name);
            throw std::invalid_argument(fmt::format("The language '{}' is defined more than once", lang.name));
        }
        set.emplace(lang.name);
    }

    return output;
}

std::optional<std::string> FileSettingsStorage::Language(std::string_view _filename) noexcept
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
        Log::Trace(SPDLOC, "Retreived the syntax settings for the language '{}'", _lang);
        return sett_it->second;
    }

    const auto lang_it = std::ranges::find_if(m_Langs, [&](auto &lang) { return lang.name == _lang; });
    if( lang_it == m_Langs.end() ) {
        return {};
    }

    const std::filesystem::path settings_path = m_BaseDir / lang_it->settings_filename;
    std::ifstream ifs{settings_path};
    if( ifs ) {
        std::string text((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
        auto shared = std::make_shared<std::string>(std::move(text));
        m_Settings.emplace(_lang, shared);
        Log::Debug(SPDLOC, "Sucessfuly loaded the syntax settings from the file '{}'", settings_path.native());
        return shared;
    }
    else {
        m_Settings.emplace(_lang, nullptr);
        Log::Error(SPDLOC, "Unable to load the syntax settings from the file '{}'", settings_path.native());
        return {};
    }
}

} // namespace nc::viewer::hl
