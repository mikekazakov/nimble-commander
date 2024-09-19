// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataItemVolatileData.h"

namespace nc::panel::data {

static_assert(sizeof(QuickSearchHiglight) == 8);
static_assert(sizeof(ItemVolatileData) == 24);

QuickSearchHiglight::QuickSearchHiglight(std::span<const Range> _ranges) noexcept
{
    // limitation: _ranges must be monotonically rising and have no overlaps
    int idx = 0;
    size_t position = 0;
    for( const Range r : _ranges ) {
        size_t offset = r.offset;
        size_t length = r.length;
        while( length ) {
            if( offset - position < 16 ) {
                if( length < 16 ) {
                    // place this whole segment
                    const uint64_t t = (offset - position) | (length << 4);
                    d |= t << (idx * 8);
                    ++idx;
                    if( idx == 8 )
                        return; // no more room, done
                    position = offset + length;
                    length = 0;
                }
                else {
                    // place 15 characters of this segment
                    const uint64_t t = (offset - position) | (15 << 4);
                    d |= t << (idx * 8);
                    ++idx;
                    if( idx == 8 )
                        return; // no more room, done
                    position = offset + 15;
                    length -= 15;
                    offset += 15;
                }
                continue;
            }
            // place only an offset
            const uint64_t t = 15;
            d |= t << (idx * 8);
            ++idx;
            if( idx == 8 )
                return; // no more room, done
            position += 15;
        }
    }
}

QuickSearchHiglight::Ranges QuickSearchHiglight::unpack() const noexcept
{
    Ranges r;
    uint64_t t = d;
    while( t ) {
        const size_t offset = (t & 0x0F);
        const size_t length = (t & 0xF0) >> 4;
        t >>= 8;
        if( r.count == 0 ) {
            // first segment
            r.segments[0].offset = offset;
            r.segments[0].length = length;
            ++r.count;
        }
        else if( offset == 0 ) {
            // continuation of the previous segment - length
            r.segments[r.count - 1].length += length;
        }
        else if( r.segments[r.count - 1].length == 0 ) {
            // previous segment was an offset placeholder
            r.segments[r.count - 1].offset += offset;
            r.segments[r.count - 1].length = length;
        }
        else {
            // next segment
            r.segments[r.count].offset = r.segments[r.count - 1].offset + r.segments[r.count - 1].length + offset;
            r.segments[r.count].length = length;
            ++r.count;
        }
    }
    return r;
}

bool ItemVolatileData::is_selected() const noexcept
{
    return (flags & flag_selected) != 0;
};

bool ItemVolatileData::is_shown() const noexcept
{
    return (flags & flag_shown) != 0;
}

bool ItemVolatileData::is_highlighted() const noexcept
{
    return (flags & flag_highlight) != 0;
}

bool ItemVolatileData::is_size_calculated() const noexcept
{
    return size != invalid_size;
}

void ItemVolatileData::toggle_selected(bool _v) noexcept
{
    flags = (flags & ~flag_selected) | (_v ? flag_selected : 0);
}

void ItemVolatileData::toggle_shown(bool _v) noexcept
{
    flags = (flags & ~flag_shown) | (_v ? flag_shown : 0);
}

void ItemVolatileData::toggle_highlight(bool _v) noexcept
{
    flags = (flags & ~flag_highlight) | (_v ? flag_highlight : 0);
}

} // namespace nc::panel::data
