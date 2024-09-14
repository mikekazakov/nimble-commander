// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "RapidJSON.h"

namespace nc::config {

rapidjson::CrtAllocator g_CrtAllocator;

Value MakeStandaloneString(std::string_view _str)
{
    return {_str.data(), static_cast<rapidjson::SizeType>(_str.length()), g_CrtAllocator};
}

std::optional<bool> GetOptionalBoolFromObject(const Value &_value, const char *_name)
{
    const auto it = _value.FindMember(_name);
    if( it == _value.MemberEnd() )
        return std::nullopt;

    const auto &v = it->value;
    if( !v.IsBool() )
        return std::nullopt;

    return v.GetBool();
}

std::optional<int> GetOptionalIntFromObject(const Value &_value, const char *_name)
{
    const auto it = _value.FindMember(_name);
    if( it == _value.MemberEnd() )
        return std::nullopt;

    const auto &v = it->value;
    if( !v.IsInt() )
        return std::nullopt;

    return v.GetInt();
}

std::optional<const char *> GetOptionalStringFromObject(const Value &_value, const char *_name)
{
    const auto it = _value.FindMember(_name);
    if( it == _value.MemberEnd() )
        return std::nullopt;

    const auto &v = it->value;
    if( !v.IsString() )
        return std::nullopt;

    return v.GetString();
}

} // namespace nc::config
