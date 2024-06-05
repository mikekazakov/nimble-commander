// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <stdint.h>
#include <span>
#include <vector>

namespace nc::viewer::hl {

enum class Style : uint8_t {
    Default = 0,
    Comment = 1,
    Preprocessor = 2,
    Keyword = 3,
    Operator = 4,
    Identifier = 5,
    Number = 6,
    String = 7
};

class StyleMapper
{
public:
    void SetMapping(char _from_lexilla_style, Style _to_nc_style) noexcept;
    void MapStyles(std::span<const char> _lexilla_styles, std::span<Style> _nc_styles) const noexcept;

private:
    std::vector<Style> m_MapsTo;
};

} // namespace nc::viewer::hl
