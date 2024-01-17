// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UI/TagsPresentation.h"
#include <Cocoa/Cocoa.h>
#include <array>
#include <utility>
#include <numeric>
#include <algorithm>
#include <ranges>

namespace nc::panel {

static NSColor *Saturate(NSColor *_color) noexcept
{
    double factor = 1.5;
    double hue, saturation, brightness, alpha;
    [_color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    return [NSColor colorWithCalibratedHue:hue
                                saturation:std::min(1.0, saturation * factor)
                                brightness:brightness
                                     alpha:alpha];
}

// fill, stroke
static std::pair<NSColor *, NSColor *> Color(utility::Tags::Color _color) noexcept
{
    assert(std::to_underlying(_color) < 8);
    [[clang::no_destroy]] static std::array<NSColor *, 8> fill_colors;
    [[clang::no_destroy]] static std::array<NSColor *, 8> stroke_colors;
    static std::once_flag once;
    std::call_once(once, [] {
        // TODO: explicit components for stroke
        constexpr int components[8][4] = {{0, 0, 0, 0},
                                          {147, 147, 151, 255},
                                          {71, 208, 83, 255},
                                          {174, 88, 220, 255},
                                          {42, 125, 252, 255},
                                          {252, 205, 40, 255},
                                          {252, 73, 72, 255},
                                          {252, 154, 40, 255}};

        for( size_t i = 0; i < 8; ++i ) {
            fill_colors[i] = [NSColor colorWithCalibratedRed:components[i][0] / 255.
                                                       green:components[i][1] / 255.
                                                        blue:components[i][2] / 255.
                                                       alpha:components[i][3] / 255.];
            stroke_colors[i] = Saturate(fill_colors[i]);
        }
    });
    auto idx = std::to_underlying(_color);
    return {fill_colors[idx], stroke_colors[idx]};
}

TrailingTagsInplaceDisplay::Geom
TrailingTagsInplaceDisplay::Place(const std::span<const utility::Tags::Tag> _tags) noexcept
{
    auto count = std::ranges::count_if(_tags, [](auto &_tag) { return _tag.Color() != utility::Tags::Color::None; });
    if( count == 0 )
        return {};
    return {Diameter + (std::min(static_cast<int>(count), MaxDrawn) - 1) * Step, Margin};
}

void TrailingTagsInplaceDisplay::Draw(const double _offset_x,
                                      const double _view_height,
                                      const std::span<const utility::Tags::Tag> _tags,
                                      NSColor *_accent,
                                      NSColor *_background) noexcept
{
    if( _tags.empty() )
        return;

    // Take up to MaxDrawn tags that have a color other than None
    std::array<utility::Tags::Color, MaxDrawn> colors_to_draw;
    size_t num_colors_to_draw = 0;

    for( auto it = _tags.rbegin(); it != _tags.rend() && num_colors_to_draw < MaxDrawn; ++it ) {
        if( it->Color() != utility::Tags::Color::None )
            colors_to_draw[num_colors_to_draw++] = it->Color();
    }

    if( num_colors_to_draw == 0 )
        return;

    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
    [currentContext saveGraphicsState];

    constexpr double radius = static_cast<double>(Diameter / 2);
    constexpr double spacing = static_cast<double>(Step);

    for( ssize_t i = num_colors_to_draw - 1; i >= 0; --i ) {
        auto colors = Color(colors_to_draw[i]);
        [colors.first setFill];
        if( _accent )
            [_accent setStroke];
        else
            [colors.second setStroke];

        NSPoint center = NSMakePoint(_offset_x + i * spacing, _view_height / 2.);

        NSBezierPath *circle = [NSBezierPath bezierPath];
        [circle appendBezierPathWithArcWithCenter:center radius:radius startAngle:0 endAngle:360];
        [circle fill];
        [circle setLineWidth:1.];
        [circle stroke];

        if( i < static_cast<ssize_t>(num_colors_to_draw) - 1 ) {
            NSBezierPath *shadow = [NSBezierPath bezierPath];
            [shadow appendBezierPathWithArcWithCenter:center radius:radius + 1. startAngle:0 endAngle:360];
            [_background setStroke];
            [shadow setLineWidth:1.];
            [shadow stroke];
        }
    }

    [currentContext restoreGraphicsState];
}

}
