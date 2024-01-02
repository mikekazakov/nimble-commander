// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "RapidJSON.h"

namespace nc::config {
    
rapidjson::CrtAllocator g_CrtAllocator;

Value MakeStandaloneString(const char *_str)
{
    return Value(_str, g_CrtAllocator);
}

Value MakeStandaloneString(const std::string &_str)
{
    return Value(_str.c_str(), g_CrtAllocator);
}

std::optional<bool> GetOptionalBoolFromObject( const Value& _value, const char *_name )
{
    const auto it = _value.FindMember( _name );
    if( it == _value.MemberEnd() )
        return std::nullopt;
    
    const auto &v = it->value;
    if( !v.IsBool() )
        return std::nullopt;
    
    return v.GetBool();
}

std::optional<int> GetOptionalIntFromObject( const Value& _value, const char *_name )
{
    const auto it = _value.FindMember( _name );
    if( it == _value.MemberEnd() )
        return std::nullopt;
    
    const auto &v = it->value;
    if( !v.IsInt() )
        return std::nullopt;
    
    return v.GetInt();
}

std::optional<const char*> GetOptionalStringFromObject( const Value& _value, const char *_name)
{
    const auto it = _value.FindMember( _name );
    if( it == _value.MemberEnd() )
        return std::nullopt;
    
    const auto &v = it->value;
    if( !v.IsString() )
        return std::nullopt;
    
    return v.GetString();
}

}
