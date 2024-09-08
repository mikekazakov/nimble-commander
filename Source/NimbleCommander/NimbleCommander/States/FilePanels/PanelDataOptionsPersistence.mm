// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataOptionsPersistence.h"
#include <Panel/PanelData.h>
#include <Panel/PanelDataSortMode.h>
#include <Config/RapidJSON.h>

namespace nc::panel::data {

static const auto g_RestorationSepDirsKey = "separateDirectories";
static const auto g_RestorationExtlessDirsKey = "extensionlessDirectories";
static const auto g_RestorationShowHiddenKey = "showHidden";
static const auto g_RestorationCaseSensKey = "caseSensitive";  // backward compatibility
static const auto g_RestorationNumericSortKey = "numericSort"; // backward compatibility
static const auto g_RestorationSortModeKey = "sortMode";
static const auto g_RestorationCollationKey = "collation";
static const auto g_RestorationCollationNatural = "natural";
static const auto g_RestorationCollationCaseInsens = "caseinsens";
static const auto g_RestorationCollationCaseSens = "casesens";

using nc::config::g_CrtAllocator;
using nc::config::Value;

static std::string to_string(SortMode::Collation _col) noexcept
{
    switch( _col ) {
        case SortMode::Collation::Natural:
            return g_RestorationCollationNatural;
        case SortMode::Collation::CaseInsensitive:
            return g_RestorationCollationCaseInsens;
        case SortMode::Collation::CaseSensitive:
            return g_RestorationCollationCaseSens;
    }
}

static std::optional<SortMode::Collation> collation_from_string(std::string_view _col) noexcept
{
    if( _col == g_RestorationCollationNatural )
        return SortMode::Collation::Natural;
    if( _col == g_RestorationCollationCaseInsens )
        return SortMode::Collation::CaseInsensitive;
    if( _col == g_RestorationCollationCaseSens )
        return SortMode::Collation::CaseSensitive;
    return {};
}

OptionsExporter::OptionsExporter(const Model &_data) : m_Data(_data)
{
}

Value OptionsExporter::Export() const
{
    Value json(rapidjson::kObjectType);
    auto add_bool = [&](const char *_name, bool _v) {
        json.AddMember(Value(_name, g_CrtAllocator), Value(_v), g_CrtAllocator);
    };
    auto add_int = [&](const char *_name, int _v) {
        json.AddMember(Value(_name, g_CrtAllocator), Value(_v), g_CrtAllocator);
    };
    auto add_string = [&](const char *_name, const std::string &_v) {
        json.AddMember(Value(_name, g_CrtAllocator), config::MakeStandaloneString(_v), g_CrtAllocator);
    };
    auto sort_mode = m_Data.SortMode();
    add_bool(g_RestorationSepDirsKey, sort_mode.sep_dirs);
    add_bool(g_RestorationExtlessDirsKey, sort_mode.extensionless_dirs);
    add_bool(g_RestorationShowHiddenKey, m_Data.HardFiltering().show_hidden);
    add_int(g_RestorationSortModeKey, static_cast<int>(sort_mode.sort));
    add_string(g_RestorationCollationKey, to_string(sort_mode.collation));
    return json;
}

OptionsImporter::OptionsImporter(Model &_data) : m_Data(_data)
{
}

void OptionsImporter::Import(const Value &_options)
{
    using namespace rapidjson;
    using namespace nc::config;
    if( !_options.IsObject() )
        return;

    auto sort_mode = m_Data.SortMode();
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationSepDirsKey) )
        sort_mode.sep_dirs = *v;
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationExtlessDirsKey) )
        sort_mode.extensionless_dirs = *v;
    if( auto v = GetOptionalStringFromObject(_options, g_RestorationCollationKey) ) {
        if( auto col = collation_from_string(v.value()) )
            sort_mode.collation = col.value();
    }
    else {
        // backward compatibility
        if( auto v1 = GetOptionalBoolFromObject(_options, g_RestorationCaseSensKey); v1.value() ) {
            sort_mode.collation = SortMode::Collation::CaseSensitive;
        }
        else if( auto v2 = GetOptionalBoolFromObject(_options, g_RestorationNumericSortKey); v2.value() ) {
            sort_mode.collation = SortMode::Collation::Natural;
        }
    }
    if( auto v = GetOptionalIntFromObject(_options, g_RestorationSortModeKey) )
        if( auto mode = static_cast<SortMode::Mode>(*v); nc::panel::data::SortMode::validate(mode) )
            sort_mode.sort = mode;
    m_Data.SetSortMode(sort_mode);

    auto hard_filtering = m_Data.HardFiltering();
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationShowHiddenKey) )
        hard_filtering.show_hidden = *v;
    m_Data.SetHardFiltering(hard_filtering);
}

} // namespace nc::panel::data
