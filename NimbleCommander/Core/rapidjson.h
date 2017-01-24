#pragma once

#include <rapidjson/rapidjson.h>
#include <rapidjson/document.h>

namespace rapidjson
{
    extern CrtAllocator g_CrtAllocator;
    typedef GenericDocument<rapidjson::UTF8<>, rapidjson::CrtAllocator> StandaloneDocument;
    typedef GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> StandaloneValue;
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const char *_str);
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const string &_str);
}
