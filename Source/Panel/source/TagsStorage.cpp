// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TagsStorage.h"
#include <Config/Config.h>
#include <Config/RapidJSON.h>
#include <algorithm>

namespace nc::panel {

TagsStorage::TagsStorage(config::Config &_persistant_storage, std::string_view _path)
    : m_Storage(_persistant_storage), m_PathV1(std::string(_path) + ".v1")
{
    m_Initialized = Load();
    if( m_Initialized && m_Tags.empty() ) {
        // In case there are no items on the filesystem with tags we still want to have some tags,
        // use a default set for that
        using Tags = utility::Tags;
        m_Tags = std::vector<Tags::Tag>{
            {Tags::Tag::Internalize("Red"), Tags::Color::Red},
            {Tags::Tag::Internalize("Orange"), Tags::Color::Orange},
            {Tags::Tag::Internalize("Yellow"), Tags::Color::Yellow},
            {Tags::Tag::Internalize("Green"), Tags::Color::Green},
            {Tags::Tag::Internalize("Blue"), Tags::Color::Blue},
            {Tags::Tag::Internalize("Purple"), Tags::Color::Purple},
            {Tags::Tag::Internalize("Grey"), Tags::Color::Gray},
            {Tags::Tag::Internalize("None"), Tags::Color::None},
        };
    }
}

std::vector<utility::Tags::Tag> TagsStorage::Get() const
{
    std::vector<utility::Tags::Tag> copy;
    {
        const std::lock_guard lock{m_Mut};
        copy = m_Tags;
    }

    return copy;
}

void TagsStorage::Set(std::span<const utility::Tags::Tag> _tags)
{
    {
        const std::lock_guard lock{m_Mut};
        m_Tags.assign(_tags.begin(), _tags.end());
        m_Initialized = true;
    }
    Store();
}

bool TagsStorage::Initialized() const noexcept
{
    return m_Initialized;
}

bool TagsStorage::Load()
{
    using Tags = utility::Tags;

    const auto tags = m_Storage.Get(m_PathV1);
    if( !tags.IsArray() )
        return false;

    const unsigned tags_size = tags.Size();
    if( tags_size % 2 != 0 )
        return false;

    m_Tags.clear();

    for( unsigned i = 0; i < tags_size; i += 2 ) {
        auto &label_elem = tags[i];
        auto &color_elem = tags[i + 1];
        if( !label_elem.IsString() || !color_elem.IsString() )
            continue;
        const int color = std::clamp(std::stoi(color_elem.GetString()), 0, 7);
        m_Tags.emplace_back(Tags::Tag::Internalize(label_elem.GetString()), static_cast<Tags::Color>(color));
    }
    return true;
}

void TagsStorage::Store()
{
    using namespace rapidjson;
    nc::config::Value tags{kArrayType};
    {
        const std::lock_guard lock{m_Mut};
        for( auto &tag : m_Tags ) {
            tags.PushBack(nc::config::MakeStandaloneString(tag.Label()), nc::config::g_CrtAllocator);
            tags.PushBack(nc::config::MakeStandaloneString(std::to_string(std::to_underlying(tag.Color()))),
                          nc::config::g_CrtAllocator);
        }
    }
    m_Storage.Set(m_PathV1, tags);
}

} // namespace nc::panel
