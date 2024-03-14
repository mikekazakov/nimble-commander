// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Utility/Tags.h>
#include <span>
#include <array>
#include <Cocoa/Cocoa.h>

namespace nc::panel {

struct TrailingTagsInplaceDisplay {
    static constexpr int MaxDrawn = 3;
    static constexpr int Diameter = 9;
    static constexpr int Step = 5;
    static constexpr int Margin = 8;

    struct Geom {
        int width = 0;
        int margin = 0;
    };

    // Provides informations about required space to draw the specified set of tags
    static Geom Place(std::span<const utility::Tags::Tag> _tags) noexcept;

    // Draws the specified set of tags in the current context.
    // if _accent is given it is used to stroke the tags, natural stroke colors is used otherwise.
    // background colors is used when more than one tag is drawn.
    static void Draw(double _offset_x,
                     double _view_height,
                     std::span<const utility::Tags::Tag> _tags,
                     NSColor *_accent,
                     NSColor *_background) noexcept;
};

struct TagsMenuDisplay {
    static const std::array<NSImage *, 8> &Images() noexcept;
};

} // namespace nc::panel
