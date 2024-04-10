// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelListViewTagsView.h"
#include "PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewTableView.h"
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <vector>
#include <ranges>
#include <algorithm>

using namespace nc;

static NSParagraphStyle *const g_Style = [] {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentLeft;
    style.lineBreakMode = NSLineBreakByTruncatingMiddle;
    style.allowsDefaultTighteningForTruncation = false;
    return style;
}();

@implementation NCPanelListViewTagsView {
    std::vector<utility::Tags::Tag> m_Tags;
    NSMutableAttributedString *m_AttrString;
}

- (id)initWithFrame:(NSRect) [[maybe_unused]] _rc
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

- (void)setTags:(std::span<const nc::utility::Tags::Tag>)_tags
{
    if( !std::ranges::equal(m_Tags, _tags) ) {
        m_Tags.assign(_tags.begin(), _tags.end());
        [self buildPresentation];
    }
}

- (void)buildPresentation
{
    if( !m_Tags.empty() ) {
        PanelListViewRowView *row_view = static_cast<PanelListViewRowView *>(self.superview);
        if( !row_view )
            return;
        NSDictionary *attrs = @{
            NSFontAttributeName: row_view.listView.font,
            NSForegroundColorAttributeName: row_view.rowTextColor,
            NSParagraphStyleAttributeName: g_Style
        };

        std::string text = m_Tags.front().Label();
        for( auto i = std::next(m_Tags.begin()), e = m_Tags.end(); i != e; ++i ) {
            text += ", ";
            text += i->Label();
        }

        m_AttrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithUTF8StdString:text]
                                                              attributes:attrs];
    }
    else {
        m_AttrString = nil;
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

    [row_view.rowBackgroundColor set];
    NSRectFill(self.bounds);
    [PanelListViewTableView drawVerticalSeparatorForView:self];

    if( m_AttrString ) {
        const auto geometry = list_view.geometry;
        NSRect rc = NSMakeRect(geometry.LeftInset(),
                               geometry.TextBaseLine(),
                               self.bounds.size.width - geometry.LeftInset() - geometry.RightInset(),
                               0.);
        [m_AttrString drawWithRect:rc options:0];
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
