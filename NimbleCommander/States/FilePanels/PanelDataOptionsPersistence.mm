// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataOptionsPersistence.h"
#include <Panel/PanelData.h>
#include <Panel/PanelDataSortMode.h>
#include <Config/RapidJSON.h>

namespace nc::panel::data {

static const auto g_RestorationSepDirsKey = "separateDirectories";
static const auto g_RestorationExtlessDirsKey = "extensionlessDirectories";
static const auto g_RestorationShowHiddenKey = "showHidden";
static const auto g_RestorationCaseSensKey = "caseSensitive";
static const auto g_RestorationNumericSortKey = "numericSort";
static const auto g_RestorationSortModeKey = "sortMode";

using nc::config::g_CrtAllocator;
using nc::config::Value;

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
    auto sort_mode = m_Data.SortMode();
    add_bool(g_RestorationSepDirsKey, sort_mode.sep_dirs);
    add_bool(g_RestorationExtlessDirsKey, sort_mode.extensionless_dirs);
    add_bool(g_RestorationShowHiddenKey, m_Data.HardFiltering().show_hidden);
    add_bool(g_RestorationCaseSensKey, sort_mode.case_sens);
    add_bool(g_RestorationNumericSortKey, sort_mode.numeric_sort);
    add_int(g_RestorationSortModeKey, static_cast<int>(sort_mode.sort));
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
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationCaseSensKey) )
        sort_mode.case_sens = *v;
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationNumericSortKey) )
        sort_mode.numeric_sort = *v;
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
