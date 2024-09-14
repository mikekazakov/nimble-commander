// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <string>

#include <rapidjson/fwd.h>

namespace nc::config {

extern rapidjson::CrtAllocator g_CrtAllocator;

using Document = rapidjson::GenericDocument<rapidjson::UTF8<char>, rapidjson::CrtAllocator, rapidjson::CrtAllocator>;

using Value = rapidjson::GenericValue<rapidjson::UTF8<char>, rapidjson::CrtAllocator>;

Value MakeStandaloneString(std::string_view _str);
std::optional<bool> GetOptionalBoolFromObject(const Value &_value, const char *_name);
std::optional<int> GetOptionalIntFromObject(const Value &_value, const char *_name);
std::optional<const char *> GetOptionalStringFromObject(const Value &_value, const char *_name);

} // namespace nc::config
