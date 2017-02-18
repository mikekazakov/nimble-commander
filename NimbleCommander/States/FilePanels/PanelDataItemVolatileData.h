#pragma once

struct PanelDataItemVolatileData
{
    enum {
        invalid_size = (0xFFFFFFFFFFFFFFFFu),
        flag_selected   = 1 << 0,
        flag_shown      = 1 << 1,
        flag_highlight  = 1 << 2  // temporary item highlight, for instance for context menu
    };
    
    uint64_t size = invalid_size; // for directories will contain invalid_size or actually calculated size. for other types will contain the original size from listing.
    uint16_t icon = 0;   // custom icon ID. zero means invalid value. volatile - can be changed. saved upon directory reload.
    int16_t qs_highlight_begin = 0;
    int16_t qs_highlight_end = 0;
    uint16_t flags = 0;
    
    bool is_selected() const noexcept;
    bool is_shown() const noexcept;
    bool is_highlighted() const noexcept;
    bool is_size_calculated() const noexcept;
    void toggle_selected( bool _v ) noexcept;
    void toggle_shown( bool _v ) noexcept;
    void toggle_highlight( bool _v ) noexcept;
    bool operator==(PanelDataItemVolatileData&_rhs) const noexcept;
    bool operator!=(PanelDataItemVolatileData&_rhs) const noexcept;
};
