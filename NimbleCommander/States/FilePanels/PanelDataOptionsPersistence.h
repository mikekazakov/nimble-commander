#pragma once 

#include <NimbleCommander/Core/rapidjson.h>

class PanelData;

namespace panel {

class DataOptionsExporter
{
public:
    DataOptionsExporter(const PanelData &_data);
    rapidjson::StandaloneValue Export() const;
private:
    const PanelData &m_Data;
};

class DataOptionsImporter
{
public:
    DataOptionsImporter(PanelData &_data);
    void Import(const rapidjson::StandaloneValue& _options);
private:
    PanelData &m_Data;
};

}
