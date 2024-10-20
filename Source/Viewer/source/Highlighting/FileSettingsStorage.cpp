// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/FileSettingsStorage.h>
#include <Viewer/Log.h>
#include <Utility/FSEventsDirUpdate.h>
#include <fstream>
#include <nlohmann/json.hpp>
#include <ranges>
#include <fmt/format.h>

using json = nlohmann::json;

namespace nc::viewer::hl {

[[clang::no_destroy]] static const std::filesystem::path g_MainFile = "Main.json";

static bool RegFileExists(const std::filesystem::path &_path) noexcept
{
    std::error_code ec = {};
    const std::filesystem::file_status status = std::filesystem::status(_path, ec);
    if( ec ) {
        return false;
    }

    return std::filesystem::exists(status) && std::filesystem::is_regular_file(status);
}

FileSettingsStorage::FileSettingsStorage(const std::filesystem::path &_base_dir,
                                         const std::filesystem::path &_overrides_dir)
    : m_BaseDir(_base_dir), m_OverridesDir(_overrides_dir)
{
    const std::filesystem::path base_main = m_BaseDir / g_MainFile;
    const std::filesystem::path overrides_main = m_OverridesDir / g_MainFile;

    if( RegFileExists(overrides_main) ) {
        // Try to load the main settings from the overrides file
        try {
            m_Langs = LoadLangs(overrides_main);
        } catch( std::exception &ex ) {
            // Something went wrong with the overrides, complain but allow to continue
            Log::Warn("Unable to load the languages definitions from '{}', continuing with no definitions",
                      overrides_main.native());
        }
    }
    else {
        // No overrides main exist - use the base file
        m_Langs = LoadLangs(base_main);
    }

    SubscribeToOverridesChanges();
}

FileSettingsStorage::~FileSettingsStorage()
{
    UnsubscribeFromOverridesChanges();
}

std::vector<FileSettingsStorage::Lang> FileSettingsStorage::LoadLangs(const std::filesystem::path &_path)
{
    Log::Debug("Loading languages definitions from '{}'", _path.native());

    std::ifstream f(_path);
    if( !f.is_open() ) {
        Log::Error("Unable to open the file '{}'", _path.native());
        throw std::invalid_argument(fmt::format("Unable to open the file '{}'", _path.native()));
    }

    json data;
    try {
        data = json::parse(f);
    } catch( std::exception &ex ) {
        Log::Error("Unable to parse '{}': {}", _path.native(), ex.what());
        throw std::invalid_argument(fmt::format("Unable to parse '{}': {}", _path.native(), ex.what()));
    }

    if( !data.contains("langs") ) {
        Log::Error("Invalid JSON format '{}': no 'langs' array", _path.native());
        throw std::invalid_argument(fmt::format("Invalid JSON format '{}': no 'langs' array", _path.native()));
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
        Log::Error("Parse error in '{}': {}", _path.native(), ex.what());
        throw std::invalid_argument(fmt::format("Parse error in '{}': {}", _path.native(), ex.what()));
    }

    ankerl::unordered_dense::set<std::string_view, UnorderedStringHashEqual, UnorderedStringHashEqual> set;
    set.reserve(output.size());
    for( auto &lang : output ) {
        if( set.contains(lang.name) ) {
            Log::Error("The language '{}' is defined more than once", lang.name);
            throw std::invalid_argument(fmt::format("The language '{}' is defined more than once", lang.name));
        }
        set.emplace(lang.name);
    }

    return output;
}

void FileSettingsStorage::ReloadLangs()
{
    const std::filesystem::path base_main = m_BaseDir / g_MainFile;
    const std::filesystem::path overrides_main = m_OverridesDir / g_MainFile;
    m_Langs.clear();

    try {
        if( RegFileExists(overrides_main) ) {
            m_Langs = LoadLangs(overrides_main);
        }
        else {
            m_Langs = LoadLangs(base_main);
        }
    } catch( std::exception &ex ) {
        // Something went wrong with the overrides, complain but allow to continue
        Log::Warn("Unable to reload the languages definitions from '{}', continuing with no definitions",
                  overrides_main.native());
    }
    m_Outdated = false;
}

std::optional<std::string> FileSettingsStorage::Language(std::string_view _filename) noexcept
{
    if( m_Outdated ) {
        ReloadLangs();
    }

    for( auto &lang : m_Langs ) {
        if( lang.mask.MatchName(_filename) ) {
            return lang.name;
        }
    }
    return {};
}

std::vector<std::string> FileSettingsStorage::List()
{
    std::vector<std::string> list;
    list.reserve(m_Langs.size());
    for( const Lang &lang : m_Langs ) {
        list.push_back(lang.name);
    }
    return list;
}

std::shared_ptr<const std::string> FileSettingsStorage::Settings(std::string_view _lang)
{
    Log::Trace("Settings() called");

    if( auto sett_it = m_Settings.find(_lang); sett_it != m_Settings.end() ) {
        Log::Trace("Retreived the syntax settings for the language '{}'", _lang);
        return sett_it->second;
    }

    if( m_Outdated ) {
        ReloadLangs();
    }

    const auto lang_it = std::ranges::find_if(m_Langs, [&](auto &lang) { return lang.name == _lang; });
    if( lang_it == m_Langs.end() ) {
        return {};
    }

    const std::filesystem::path base_settings_path = m_BaseDir / lang_it->settings_filename;
    const std::filesystem::path overrides_settings_path = m_OverridesDir / lang_it->settings_filename;
    const std::filesystem::path settings_path =
        RegFileExists(overrides_settings_path) ? overrides_settings_path : base_settings_path;

    std::ifstream ifs{settings_path};
    if( ifs ) {
        std::string text((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
        auto shared = std::make_shared<std::string>(std::move(text));
        m_Settings.emplace(_lang, shared);
        Log::Debug("Sucessfuly loaded the syntax settings from the file '{}'", settings_path.native());
        return shared;
    }
    else {
        m_Settings.emplace(_lang, nullptr);
        Log::Error("Unable to load the syntax settings from the file '{}'", settings_path.native());
        return {};
    }
}

void FileSettingsStorage::SubscribeToOverridesChanges()
{
    Log::Trace("SubscribeToOverridesChanges() called");
    m_OverridesObservationToken =
        utility::FSEventsDirUpdate::Instance().AddWatchPath(m_OverridesDir.c_str(), [this] { OverridesChanged(); });
}

void FileSettingsStorage::UnsubscribeFromOverridesChanges()
{
    Log::Trace("UnsubscribeFromOverridesChanges() called");
    if( m_OverridesObservationToken ) {
        utility::FSEventsDirUpdate::Instance().RemoveWatchPathWithTicket(m_OverridesObservationToken);
        m_OverridesObservationToken = 0;
    }
}

void FileSettingsStorage::OverridesChanged()
{
    Log::Trace("OverridesChanged() called");
    m_Outdated = true;  // mark the definitions as outdated
    m_Settings.clear(); // drop anything was loaded before
}

} // namespace nc::viewer::hl
