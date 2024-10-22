// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UI/TagsPresentation.h"
#include <Cocoa/Cocoa.h>
#include <array>
#include <utility>
#include <numeric>
#include <algorithm>
#include <ranges>

namespace nc::panel {

// fill, stroke
static std::pair<NSColor *, NSColor *> Color(utility::Tags::Color _color) noexcept
{
    assert(std::to_underlying(_color) < 8);
    [[clang::no_destroy]] static std::array<NSColor *, 8> fill_colors;
    [[clang::no_destroy]] static std::array<NSColor *, 8> stroke_colors;
    static std::once_flag once;
    std::call_once(once, [] {
        constexpr int components[8][7] = {{0, 0, 0, 0, 0, 0, 0},
                                          {147, 147, 151, 129, 128, 133, 255},
                                          {71, 208, 83, 47, 202, 58, 255},
                                          {174, 88, 220, 161, 60, 215, 255},
                                          {42, 125, 252, 17, 102, 255, 255},
                                          {252, 205, 40, 254, 196, 15, 255},
                                          {252, 73, 72, 252, 42, 45, 255},
                                          {252, 154, 40, 253, 136, 15, 255}};
        for( size_t i = 0; i < 8; ++i ) {
            fill_colors[i] = [NSColor colorWithCalibratedRed:components[i][0] / 255.
                                                       green:components[i][1] / 255.
                                                        blue:components[i][2] / 255.
                                                       alpha:components[i][6] / 255.];
            stroke_colors[i] = [NSColor colorWithCalibratedRed:components[i][3] / 255.
                                                         green:components[i][4] / 255.
                                                          blue:components[i][5] / 255.
                                                         alpha:components[i][6] / 255.];
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
    return {.width = Diameter + ((std::min(static_cast<int>(count), MaxDrawn) - 1) * Step), .margin = Margin};
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

    constexpr double radius = static_cast<double>(Diameter) / 2.;
    constexpr double spacing = static_cast<double>(Step);
    static NSBezierPath *const circle = [] {
        NSBezierPath *const circle = [NSBezierPath bezierPath];
        [circle appendBezierPathWithArcWithCenter:NSMakePoint(0., 0.) radius:radius startAngle:0 endAngle:360];
        [circle setLineWidth:1.];
        return circle;
    }();
    static NSBezierPath *const shadow = [] {
        NSBezierPath *const shadow = [NSBezierPath bezierPath];
        [shadow appendBezierPathWithArcWithCenter:NSMakePoint(0., 0.) radius:radius + 1. startAngle:0 endAngle:360];
        [shadow setLineWidth:2.0];
        return shadow;
    }();

    NSGraphicsContext *const currentContext = [NSGraphicsContext currentContext];
    for( ssize_t i = num_colors_to_draw - 1; i >= 0; --i ) {
        [currentContext saveGraphicsState];

        NSAffineTransform *const tr = [NSAffineTransform transform];
        [tr translateXBy:_offset_x + (static_cast<double>(i) * spacing) yBy:_view_height / 2.];
        [tr concat];

        if( i < static_cast<ssize_t>(num_colors_to_draw) - 1 ) {
            [_background setStroke];
            [shadow stroke];
        }

        auto colors = Color(colors_to_draw[i]);
        [colors.first setFill];
        if( _accent )
            [_accent setStroke];
        else
            [colors.second setStroke];

        [circle fill];
        [circle stroke];

        [currentContext restoreGraphicsState];
    }
}

const std::array<NSImage *, 8> &TagsMenuDisplay::Images() noexcept
{
    [[clang::no_destroy]] static const std::array<NSImage *, 8> images = [] {
        std::array<NSImage *, 8> images;
        constexpr double diameter = 12.;
        for( size_t i = 0; i < images.size(); ++i ) {
            auto handler = ^(NSRect _rc) {
              if( i == 0 ) {
                  [NSColor.textColor setStroke];
                  NSBezierPath *const circle = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(_rc, 1., 1.)];
                  [circle stroke];
              }
              else {
                  auto colors = Color(static_cast<utility::Tags::Color>(i));
                  [colors.first setFill];
                  [colors.second setStroke];
                  NSBezierPath *const circle = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(_rc, 1., 1.)];
                  [circle setLineWidth:1.];
                  [circle fill];
                  [circle stroke];
              }
              return YES;
            };
            images[i] = [NSImage imageWithSize:NSMakeSize(diameter, diameter) flipped:false drawingHandler:handler];
            [images[i] setTemplate:i == 0];
        }
        return images;
    }();
    return images;
}

} // namespace nc::panel
