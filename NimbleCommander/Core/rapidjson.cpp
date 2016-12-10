#include "rapidjson.h"

namespace rapidjson
{
    CrtAllocator g_CrtAllocator;
    
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const char *_str)
    {
        return StandaloneValue(_str, g_CrtAllocator);
    }
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const string &_str)
    {
        return StandaloneValue(_str.c_str(), g_CrtAllocator);
    }
}
