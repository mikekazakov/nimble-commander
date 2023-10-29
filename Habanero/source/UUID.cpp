/* Copyright (c) 2023 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#include "UUID.h"
#include <uuid/uuid.h>
#include <algorithm>

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
    std::copy(m_Data.begin(), m_Data.end(), &u[0]);

    uuid_unparse_lower(u, tmp.data());
    return tmp.data();
}

std::optional<UUID> UUID::FromString(std::string_view _str) noexcept
{
    if( _str.length() != 36 )
        return {};

    std::array<char, 37> tmp;
    tmp.fill(0);
    std::copy(_str.begin(), _str.end(), tmp.begin());

    UUID u;
    if( uuid_parse(tmp.data(), *reinterpret_cast<uuid_t *>(&u)) != 0 )
        return {};
    return u;
}

} // namespace nc::base
