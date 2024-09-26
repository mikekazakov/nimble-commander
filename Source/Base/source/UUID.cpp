// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UUID.h"
#include <uuid/uuid.h>
#include <algorithm>
#include <UnorderedUtil.h>

namespace nc::base {

static_assert(sizeof(UUID) == sizeof(uuid_t));

UUID::UUID() noexcept
{
    m_Data.fill(0);
}

UUID UUID::Generate() noexcept
{
    UUID u;
    uuid_generate(*reinterpret_cast<uuid_t *>(&u));
    return u;
}

std::string UUID::ToString() const noexcept
{
    std::array<char, 37> tmp;
    tmp.fill(0);

    uuid_t u;
    std::ranges::copy(m_Data, &u[0]);

    uuid_unparse_lower(u, tmp.data());
    return tmp.data();
}

std::optional<UUID> UUID::FromString(std::string_view _str) noexcept
{
    if( _str.length() != 36 )
        return {};

    std::array<char, 37> tmp;
    tmp.fill(0);
    std::ranges::copy(_str, tmp.begin());

    UUID u;
    if( uuid_parse(tmp.data(), *reinterpret_cast<uuid_t *>(&u)) != 0 )
        return {};
    return u;
}

size_t UUID::Hash() const noexcept
{
    const std::string_view v(reinterpret_cast<const char *>(m_Data.data()), m_Data.size());
    return ankerl::unordered_dense::hash<std::string_view>{}(v);
}

} // namespace nc::base

size_t std::hash<nc::base::UUID>::operator()(const nc::base::UUID &u) const noexcept
{
    return u.Hash();
}
