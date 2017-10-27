// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/rapidjson.h>

namespace nc::panel::data {

class Model;

class OptionsExporter
{
public:
    OptionsExporter(const Model &_data);
    rapidjson::StandaloneValue Export() const;
private:
    const Model &m_Data;
};

class OptionsImporter
{
public:
    OptionsImporter(Model &_data);
    void Import(const rapidjson::StandaloneValue& _options);
private:
    Model &m_Data;
};

}
