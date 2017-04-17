#pragma once

#ifdef RAPIDJSON_RAPIDJSON_H_
    #error include this file before rapidjson headers!
#endif

#define RAPIDJSON_48BITPOINTER_OPTIMIZATION   1
// has minor effect, keep it.

#define RAPIDJSON_SSE2 1
// about a 10% faster parsing recorded, keep it.

// #define RAPIDJSON_SSE42
// can't use this option, as 10.11 can run without it

#define RAPIDJSON_HAS_STDSTRING 1

#include <rapidjson/rapidjson.h>
#include <rapidjson/document.h>

namespace rapidjson
{
    extern CrtAllocator g_CrtAllocator;
    typedef GenericDocument<rapidjson::UTF8<>, rapidjson::CrtAllocator> StandaloneDocument;
    typedef GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> StandaloneValue;
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const char *_str);
    GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> MakeStandaloneString(const string &_str);
    optional<bool> GetOptionalBoolFromObject( const StandaloneValue& _value, const char *_name );
    optional<int> GetOptionalIntFromObject( const StandaloneValue& _value, const char *_name );
    optional<const char*> GetOptionalStringFromObject( const StandaloneValue& _value, const char *_name );
}
