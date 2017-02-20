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

}
