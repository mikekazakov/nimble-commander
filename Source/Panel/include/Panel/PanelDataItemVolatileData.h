// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <limits>
#include <compare>
#include <span>

namespace nc::panel::data {

// Can store up to 8 segments, each with up to characters inside them.
// The maximum stored offset can be 120 characters.
// The maximum amount of highlighted characters can be 120.
struct QuickSearchHiglight {
    // The maximum number of segments in a highlight
    inline static constexpr size_t max_len = 8;

    struct Range {
        size_t offset = 0;
        size_t length = 0;
        constexpr auto operator<=>(const Range &_rhs) const noexcept = default;
    };
    struct Ranges {
        Range segments[max_len];
        size_t count = 0;
        constexpr auto operator<=>(const Ranges &_rhs) const noexcept = default;
    };

    // Default constructor create an empty highlight.
    QuickSearchHiglight() noexcept = default;

    // !Lossy! encoding constructor. It fits as much as possible into the 8-byte word and discards anything else.
    QuickSearchHiglight(std::span<const Range> _ranges) noexcept;

    // Check if the highlight contains and segments with non-zero lenghts
    constexpr bool empty() const noexcept;

    // Returns the number of segments in the highlight
    constexpr uint64_t size() const noexcept;

    // Unpacks the packed highlight in an array of segments repesented as (offset, lengths) pairs.
    Ranges unpack() const noexcept;

    // Comparison operator.
    constexpr auto operator<=>(const QuickSearchHiglight &_rhs) const noexcept = default;

private:
    // 0byte   1byte   2byte   4byte   5byte   6byte   7byte   8byte
    // 0123456789012345678901234567890123456789012345678901234567890123
    // 0         10        20        30        40        50        60
    // oooolllloooolllloooolllloooolllloooolllloooolllloooolllloooollll
    // oooo - 4bit offset, up to 15, encodes a distance from the position of the last encoded character position
    // llll - 4bit length, up to 15
    inline static constexpr uint64_t len_mask = 0xF0F0F0F0F0F0F0F0ULL;
    uint64_t d = 0;
};

struct ItemVolatileData {
    enum Size : uint64_t {
        invalid_size = std::numeric_limits<uint64_t>::max()
    };

    enum {
        flag_selected = 1 << 0,
        flag_shown = 1 << 1,
        flag_highlight = 1 << 2 // temporary item highlight, for instance for context menu
    };

    // for directories will contain invalid_size or actually calculated size. for other types will contain the original
    // size from listing.
    uint64_t size = invalid_size;

    // contains highlighted segments of the filename if any
    QuickSearchHiglight highlight;

    // custom icon ID. zero means invalid value. volatile - can be changed. saved upon directory reload.
    uint16_t icon = 0;

    // volatile flags of the item
    uint16_t flags = 0;

    bool is_selected() const noexcept;
    bool is_shown() const noexcept;
    bool is_highlighted() const noexcept;
    bool is_size_calculated() const noexcept;
    void toggle_selected(bool _v) noexcept;
    void toggle_shown(bool _v) noexcept;
    void toggle_highlight(bool _v) noexcept;
    constexpr auto operator<=>(const ItemVolatileData &_rhs) const noexcept = default;
};

constexpr bool QuickSearchHiglight::empty() const noexcept
{
    return (d & len_mask) == 0;
}

constexpr uint64_t QuickSearchHiglight::size() const noexcept
{
    uint64_t sz = 0;
    uint64_t t = d;
    do {
        t >>= 4;
        sz += t & 0xF;
        t >>= 4;
    } while( t );
    return sz;
}

} // namespace nc::panel::data
