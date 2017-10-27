// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

#include <rapidjson/fwd.h>

namespace rapidjson
{
extern CrtAllocator g_CrtAllocator;
    
using StandaloneDocument = GenericDocument<rapidjson::UTF8<char>,
                                           rapidjson::CrtAllocator,
                                           rapidjson::CrtAllocator>;
    
using StandaloneValue = GenericValue<rapidjson::UTF8<char>,
                                     rapidjson::CrtAllocator>;
    
StandaloneValue MakeStandaloneString(const char *_str);
StandaloneValue MakeStandaloneString(const string &_str);
optional<bool> GetOptionalBoolFromObject( const StandaloneValue& _value, const char *_name );
optional<int> GetOptionalIntFromObject( const StandaloneValue& _value, const char *_name );
optional<const char*> GetOptionalStringFromObject( const StandaloneValue& _value, const char *_name );
}
