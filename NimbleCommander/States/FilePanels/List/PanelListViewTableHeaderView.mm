// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelListViewTableHeaderView.h"
#include "PanelListView.h"

@implementation PanelListViewTableHeaderView

- (NSMenu*)menu
{
    if( auto v = objc_cast<PanelListView>(self.tableView.enclosingScrollView.superview) )
        if( auto menu = v.columnsSelectionMenu ) {
            menu.allowsContextMenuPlugIns = false;
            menu.font = [NSFont menuFontOfSize:11];
            return menu;
        }
    return nil;
}

@end
