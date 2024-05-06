// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Dock.h"
#include <Utility/VerticallyCenteredTextFieldCell.h>
#include <cmath>

@interface NCCoreDockProgressIndicator : NSProgressIndicator
@end

namespace nc::core {

static const auto g_AdminBadge = @"ADMIN";

Dock::Dock() : m_Progress{-1.}, m_Admin{false}, m_Tile{NSApplication.sharedApplication.dockTile}
{
    m_ContentView = [NSImageView new];
    m_ContentView.image = NSApplication.sharedApplication.applicationIconImage;
    m_Tile.contentView = m_ContentView;

    const auto ind_rect = NSMakeRect(0, 0, m_Tile.size.width, 14);
    m_Indicator = [[NCCoreDockProgressIndicator alloc] initWithFrame:ind_rect];
    m_Indicator.style = NSProgressIndicatorStyleBar;
    m_Indicator.indeterminate = false;
    m_Indicator.minValue = 0;
    m_Indicator.maxValue = 1;
    m_Indicator.hidden = true;
    m_Indicator.wantsLayer = true;
    [m_ContentView addSubview:m_Indicator];
}

Dock::~Dock() = default;

double Dock::Progress() const noexcept
{
    return m_Progress;
}

void Dock::SetProgress(double _value)
{
    if( _value == m_Progress )
        return;

    if( _value >= 0.0 && _value <= 1.0 ) {
        m_Indicator.doubleValue = _value;
        m_Indicator.hidden = false;
    }
    else {
        m_Indicator.hidden = true;
    }

    m_Progress = _value;
    [m_Tile display];
}

void Dock::SetAdminBadge(bool _value)
{
    if( m_Admin == _value )
        return;
    m_Admin = _value;
    UpdateBadge();
}

bool Dock::IsAdminBadgeSet() const noexcept
{
    return m_Admin;
}

void Dock::UpdateBadge()
{
    if( m_Admin )
        m_Tile.badgeLabel = g_AdminBadge;
    else
        m_Tile.badgeLabel = @"";
}

void Dock::SetBaseIcon(NSImage *_icon)
{
    assert(_icon != nil);
    NSApplication.sharedApplication.applicationIconImage = _icon;
    m_ContentView.image = _icon;
}

} // namespace nc::core

@implementation NCCoreDockProgressIndicator

- (void)drawRect:(NSRect) [[maybe_unused]] _dirty_rect
{
    static auto back_color = [NSColor colorWithCalibratedRed:0.82 green:0.82 blue:0.82 alpha:1.0];
    static auto frame_color = [NSColor colorWithCalibratedRed:0.70 green:0.70 blue:0.70 alpha:1.0];
    static auto inner_color = [NSColor colorWithCalibratedRed:0.19 green:0.51 blue:0.98 alpha:1.0];

    const auto rc = NSMakeRect(
        self.bounds.origin.x - 0.5, self.bounds.origin.y - 0.5, self.bounds.size.width, self.bounds.size.height);
    const auto outer_rect = NSInsetRect(rc, 1.0, 1.0);
    const auto outer_radius = outer_rect.size.height / 2.0;
    NSBezierPath *bezier_path = [NSBezierPath bezierPathWithRoundedRect:outer_rect
                                                                xRadius:outer_radius
                                                                yRadius:outer_radius];
    [back_color set];
    [bezier_path fill];

    [frame_color set];
    [bezier_path setLineWidth:1.0];
    [bezier_path stroke];

    const auto clip_rect = NSInsetRect(outer_rect, 1.0, 1.0);
    const auto clip_radius = clip_rect.size.height / 2;
    bezier_path = [NSBezierPath bezierPathWithRoundedRect:clip_rect xRadius:clip_radius yRadius:clip_radius];
    [bezier_path setLineWidth:1.0];
    [bezier_path addClip];

    const auto inner_rect = NSMakeRect(clip_rect.origin.x,
                                       clip_rect.origin.y,
                                       std::floor(clip_rect.size.width * self.doubleValue),
                                       clip_rect.size.width);

    [inner_color set];
    NSRectFill(inner_rect);
}

@end
