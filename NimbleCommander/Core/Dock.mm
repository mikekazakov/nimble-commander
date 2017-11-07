// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Dock.h"
#include <Utility/VerticallyCenteredTextFieldCell.h>

@interface NCCoreDockProgressIndicator : NSProgressIndicator
@end

namespace nc::core {

static const auto g_AdminBadge = @"ADMIN";
static const auto g_Unregistered = @"UNREGISTERED";

static NSView *MakeUnregBadge( NSSize _title_size );

Dock::Dock():
    m_Progress{-1.},
    m_Tile{NSApplication.sharedApplication.dockTile},
    m_Admin{false},
    m_Unregistered{false}
{
    m_ContentView = [NSImageView new];
    m_ContentView.image = NSApplication.sharedApplication.applicationIconImage;
    m_Tile.contentView = m_ContentView;
    
    const auto ind_rect = NSMakeRect(0, 0, m_Tile.size.width, 14);
    m_Indicator = [[NCCoreDockProgressIndicator alloc] initWithFrame:ind_rect];
    m_Indicator.style = NSProgressIndicatorBarStyle;
    m_Indicator.indeterminate = false;
    m_Indicator.minValue = 0;
    m_Indicator.maxValue = 1;
    m_Indicator.hidden = true;
    m_Indicator.wantsLayer = true;
    [m_ContentView addSubview:m_Indicator];
}

Dock::~Dock()
{
}

double Dock::Progress() const noexcept
{
    return m_Progress;
}

void Dock::SetProgress(double _value)
{
    if( _value == m_Progress )
        return;
    
    if( _value >= 0.0 && _value <= 1.0) {
        m_Indicator.doubleValue = _value;
        m_Indicator.hidden = false;
    }
    else {
        m_Indicator.hidden = true;
    }
    
    m_Progress = _value;
    [m_Tile display];
}

void Dock::SetAdminBadge( bool _value )
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

void Dock::SetUnregisteredBadge( bool _value )
{
    if( m_Unregistered == _value )
        return;
    m_Unregistered = _value;
    
    if( !m_UnregBadge ) {
        m_UnregBadge = MakeUnregBadge(m_Tile.size);
        [m_ContentView addSubview:m_UnregBadge];
    }
    
    m_UnregBadge.hidden = !m_Unregistered;
    [m_Tile display];
}

bool Dock::IsAUnregisteredBadgeSet() const noexcept
{
    return m_Unregistered;
}

void Dock::UpdateBadge()
{
    if( m_Admin )
        m_Tile.badgeLabel = g_AdminBadge;
    else
        m_Tile.badgeLabel = @"";
}

static NSView *MakeUnregBadge( NSSize _title_size )
{
    const auto height = 30;
    const auto rc = NSMakeRect(0, (_title_size.height-height)/2, _title_size.width, height);
    const auto v = [[NSTextField alloc] initWithFrame:rc];
    v.cell = [[VerticallyCenteredTextFieldCell alloc] init];
    v.font = [NSFont systemFontOfSize:16];
    v.textColor = NSColor.whiteColor;
    v.stringValue = g_Unregistered;
    v.editable = false;
    v.bezeled = false;
    v.alignment = NSTextAlignmentCenter;
    v.usesSingleLineMode = true;
    v.lineBreakMode = NSLineBreakByClipping;
    v.drawsBackground = false;
    v.wantsLayer = true;
    v.layer.backgroundColor = [NSColor colorWithRed:0.96 green:0.20 blue:0.18 alpha:1.].CGColor;
    v.layer.cornerRadius = rc.size.height / 2;
    v.layer.opaque = false;
    v.layer.opacity = 0.9f;
    return v;
}

}

@implementation NCCoreDockProgressIndicator

- (void)drawRect:(NSRect)dirtyRect
{
    static auto back_color  = [NSColor colorWithCalibratedRed:0.82 green:0.82 blue:0.82 alpha:1.0];
    static auto frame_color = [NSColor colorWithCalibratedRed:0.70 green:0.70 blue:0.70 alpha:1.0];
    static auto inner_color = [NSColor colorWithCalibratedRed:0.19 green:0.51 blue:0.98 alpha:1.0];


    const auto rc = NSMakeRect(self.bounds.origin.x - 0.5, self.bounds.origin.y - 0.5,
                               self.bounds.size.width, self.bounds.size.height);
    const auto outer_rect = NSInsetRect(rc, 1.0, 1.0);
    const auto outer_radius = outer_rect.size.height / 2.0;
    NSBezierPath* bezier_path = [NSBezierPath bezierPathWithRoundedRect:outer_rect
                                                                xRadius:outer_radius
                                                                yRadius:outer_radius];
    [back_color set];
    [bezier_path fill];
  
    [frame_color set];
    [bezier_path setLineWidth:1.0];
    [bezier_path stroke];

    const auto clip_rect = NSInsetRect(outer_rect, 1.0, 1.0);
    const auto clip_radius = clip_rect.size.height / 2;
    bezier_path = [NSBezierPath bezierPathWithRoundedRect:clip_rect
                                                  xRadius:clip_radius
                                                  yRadius:clip_radius];
    [bezier_path setLineWidth:1.0];
    [bezier_path addClip];
  
    const auto inner_rect = NSMakeRect(clip_rect.origin.x,
                                       clip_rect.origin.y,
                                       floor(clip_rect.size.width * self.doubleValue),
                                       clip_rect.size.width);

    [inner_color set];
    NSRectFill(inner_rect);
}

@end
