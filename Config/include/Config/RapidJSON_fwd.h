// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <string>

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

#define RAPIDJSON_HAS_CXX11_RVALUE_REFS 1

#include <rapidjson/fwd.h>

namespace nc::config {
    
extern rapidjson::CrtAllocator g_CrtAllocator;
    
using Document = rapidjson::GenericDocument<rapidjson::UTF8<char>,
                                            rapidjson::CrtAllocator,
                                            rapidjson::CrtAllocator>;
    
using Value = rapidjson::GenericValue<rapidjson::UTF8<char>,
                                      rapidjson::CrtAllocator>;
    
Value MakeStandaloneString(const char *_str);
Value MakeStandaloneString(const std::string &_str);
std::optional<bool> GetOptionalBoolFromObject( const Value& _value, const char *_name );
std::optional<int> GetOptionalIntFromObject( const Value& _value, const char *_name );
std::optional<const char*> GetOptionalStringFromObject( const Value& _value, const char *_name );

}
