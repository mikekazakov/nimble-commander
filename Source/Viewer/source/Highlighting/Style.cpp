// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/Style.h>

namespace nc::viewer::hl {

void StyleMapper::SetMapping(char _lexilla_style, Style _nc_style) noexcept
{
    if( _lexilla_style < 0 ) {
        return;
    }
    if( m_MapsTo.size() < static_cast<size_t>(_lexilla_style) + 1 ) {
        m_MapsTo.resize(static_cast<size_t>(_lexilla_style) + 1, Style::Default);
    }
    m_MapsTo[static_cast<size_t>(_lexilla_style)] = _nc_style;
}

void StyleMapper::MapStyles(std::span<const char> _lexilla_styles, std::span<Style> _nc_styles) const noexcept
{
    if( _lexilla_styles.size() != _nc_styles.size() ) {
        abort();
    }

    for( size_t i = 0; i < _lexilla_styles.size(); ++i ) {
        const char ls = _lexilla_styles[i];
        if( ls < 0 || static_cast<size_t>(ls) >= m_MapsTo.size() ) {
            _nc_styles[i] = Style::Default;
        }
        else {
            _nc_styles[i] = m_MapsTo[static_cast<size_t>(ls)];
        }
    }
}

} // namespace nc::viewer::hl
