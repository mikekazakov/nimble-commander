// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
    
optional<bool> GetOptionalBoolFromObject( const StandaloneValue& _value, const char *_name )
{
    const auto it = _value.FindMember( _name );
    if( it == _value.MemberEnd() )
        return nullopt;
    
    const auto &v = it->value;
    if( !v.IsBool() )
        return nullopt;
    
    return v.GetBool();
}

optional<int> GetOptionalIntFromObject( const StandaloneValue& _value, const char *_name )
{
    const auto it = _value.FindMember( _name );
    if( it == _value.MemberEnd() )
        return nullopt;
    
    const auto &v = it->value;
    if( !v.IsInt() )
        return nullopt;
    
    return v.GetInt();
}

optional<const char*> GetOptionalStringFromObject( const StandaloneValue& _value, const char *_name)
{
    const auto it = _value.FindMember( _name );
    if( it == _value.MemberEnd() )
        return nullopt;
    
    const auto &v = it->value;
    if( !v.IsString() )
        return nullopt;
    
    return v.GetString();
}

}
