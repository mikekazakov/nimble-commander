// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Panel/FindFilesData.h>
#include <Config/RapidJSON.h>

namespace nc::panel {

bool operator==(const FindFilesMask &lhs, const FindFilesMask &rhs) noexcept
{
    return lhs.string == rhs.string && lhs.type == rhs.type;
}

bool operator!=(const FindFilesMask &lhs, const FindFilesMask &rhs) noexcept
{
    return !(lhs == rhs);
}

std::vector<FindFilesMask> LoadFindFilesMasks(const nc::config::Config &_source, std::string_view _path)
{
    std::vector<FindFilesMask> masks;

    auto arr = _source.Get(_path);
    if( arr.GetType() == rapidjson::kArrayType )
        for( auto i = arr.Begin(), e = arr.End(); i != e; ++i ) {
            FindFilesMask m;
            if( i->GetType() == rapidjson::kStringType ) {
                // simple "classic" mask
                m.string = i->GetString();
                m.type = FindFilesMask::Classic;
            }
            else if( i->GetType() == rapidjson::kObjectType ) {
                // masks with options encoded as a object
                const auto query_it = i->FindMember("query");
                if( query_it != i->MemberEnd() && query_it->value.GetType() == rapidjson::kStringType )
                    m.string = query_it->value.GetString();
                else
                    continue;

                const auto type_it = i->FindMember("type");
                const auto type = (type_it != i->MemberEnd() && type_it->value.GetType() == rapidjson::kStringType)
                                      ? std::string(type_it->value.GetString())
                                      : std::string{};
                if( type == "classic" )
                    m.type = FindFilesMask::Classic;
                if( type == "regex" )
                    m.type = FindFilesMask::RegEx;
            }

            if( m.string.empty() )
                continue; // refuse meaningless input
            masks.push_back(std::move(m));
        }
    return masks;
}

void StoreFindFilesMasks(nc::config::Config &_dest, std::string_view _path, std::span<const FindFilesMask> _masks)
{
    using namespace nc::config;
    Value arr(rapidjson::kArrayType);
    for( const auto &mask : _masks ) {
        if( mask.type == FindFilesMask::Classic ) {
            arr.PushBack(Value(mask.string.c_str(), g_CrtAllocator), g_CrtAllocator);
        }
        else {
            Value mask_obj(rapidjson::kObjectType);
            mask_obj.AddMember("query", Value(mask.string.c_str(), g_CrtAllocator), g_CrtAllocator);
            if( mask.type == FindFilesMask::RegEx )
                mask_obj.AddMember("type", Value("regex", g_CrtAllocator), g_CrtAllocator);
            arr.PushBack(mask_obj, g_CrtAllocator);
        }
    }
    _dest.Set(_path, arr);
}

} // namespace nc::panel
