#pragma once

#include "3rd_party/rapidjson/include/rapidjson/rapidjson.h"
#include "3rd_party/rapidjson/include/rapidjson/document.h"

namespace rapidjson
{
    extern CrtAllocator g_CrtAllocator;
    typedef GenericDocument<rapidjson::UTF8<>, rapidjson::CrtAllocator> StandaloneDocument;
    typedef GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> StandaloneValue;
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const char *_str);
}
