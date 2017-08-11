#include "Dock.h"

@interface NCCoreDockProgressIndicator : NSProgressIndicator
@end

namespace nc::core {

Dock::Dock():
    m_Progress{-1.},
    m_Tile{NSApplication.sharedApplication.dockTile}
{
    NSImageView *iv = [NSImageView new];
    iv.image = NSApplication.sharedApplication.applicationIconImage;
    m_Tile.contentView = iv;
    
    const auto ind_rect = NSMakeRect(0, 0, m_Tile.size.width, 14);
    m_Indicator = [[NCCoreDockProgressIndicator alloc] initWithFrame:ind_rect];
    m_Indicator.style = NSProgressIndicatorBarStyle;
    m_Indicator.indeterminate = false;
    m_Indicator.minValue = 0;
    m_Indicator.maxValue = 1;
    m_Indicator.hidden = true;
    m_Indicator.wantsLayer = true;
    [iv addSubview:m_Indicator];
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
