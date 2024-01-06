// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelListViewExtensionView.h"
#include "PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewTableView.h"
#include <Utility/ObjCpp.h>
#include <Base/CFPtr.h>
#include <cassert>

using namespace nc;

static NSParagraphStyle *const g_Style = [] {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentLeft;
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    style.allowsDefaultTighteningForTruncation = false;
    return style;
}();

@implementation NCPanelListViewExtensionView {
    NSString *m_Extension;
    base::CFPtr<CTLineRef> m_Line;
}

- (id)initWithFrame:(NSRect) [[maybe_unused]] _frameRect
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
    }
    return self;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)wantsDefaultClipping
{
    return false;
}

- (void)setExtension:(NSString *)_extension
{
    m_Extension = _extension;
    [self buildPresentation];
}

- (void)buildPresentation
{
    if( m_Extension != nil ) {
        PanelListViewRowView *row_view = static_cast<PanelListViewRowView *>(self.superview);
        if( !row_view )
            return;
        NSDictionary *attrs = @{
            NSFontAttributeName: row_view.listView.font,
            NSForegroundColorAttributeName: row_view.rowTextColor,
            NSParagraphStyleAttributeName: g_Style
        };
        auto attr_str = [[NSMutableAttributedString alloc] initWithString:m_Extension
                                                               attributes:attrs];
        m_Line = base::CFPtr<CTLineRef>::adopt(
            CTLineCreateWithAttributedString(static_cast<CFAttributedStringRef>(attr_str)));
    }
    else {
        m_Line.reset();
    }

    [self setNeedsDisplay:true];
}

- (void)drawRect:(NSRect) [[maybe_unused]] _rect
{
    auto row_view = self.row;
    if( !row_view )
        return;

    auto list_view = self.listView;
    if( !list_view )
        return;

    const auto geometry = list_view.geometry;
    const auto context = NSGraphicsContext.currentContext.CGContext;

    [row_view.rowBackgroundColor set];
    NSRectFill(self.bounds);
    [PanelListViewTableView drawVerticalSeparatorForView:self];

    if( m_Line ) {
        CGContextSetFillColorWithColor(context, row_view.rowTextColor.CGColor);
        CGContextSetTextPosition(context, geometry.LeftInset(), geometry.TextBaseLine());
        CGContextSetTextDrawingMode(context, kCGTextFill);
        CTLineDraw(m_Line.get(), context);
    }
}

- (PanelListViewRowView *)row
{
    return objc_cast<PanelListViewRowView>(self.superview);
}

- (PanelListView *)listView
{
    return self.row.listView;
}

@end
