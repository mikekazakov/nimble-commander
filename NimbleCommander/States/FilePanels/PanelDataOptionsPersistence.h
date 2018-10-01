// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/RapidJSON_fwd.h>

namespace nc::panel::data {

class Model;

class OptionsExporter
{
public:
    OptionsExporter(const Model &_data);
    nc::config::Value Export() const;
private:
    const Model &m_Data;
};

class OptionsImporter
{
public:
    OptionsImporter(Model &_data);
    void Import(const nc::config::Value& _options);
private:
    Model &m_Data;
};

}
