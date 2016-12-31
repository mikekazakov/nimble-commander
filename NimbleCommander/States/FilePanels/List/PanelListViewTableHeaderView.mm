#include "PanelListViewTableHeaderView.h"

@implementation PanelListViewTableHeaderView

/*
- (void) drawRect:(NSRect)dirtyRect
{
    

    const auto n = self.tableView.numberOfColumns;
    for( int i = 0; i < n; ++i ) {
        const auto rc = [self headerRectOfColumn:i];
        
        [self.tableView.tableColumns[i].headerCell drawWithFrame:rc
                                                          inView:self];
    }

}
*/
/*
    override func drawRect(dirtyRect: NSRect) {

        guard let columns = tableView?.numberOfColumns
            else { return }

        (0...columns)
            .map { headerRectOfColumn($0) }
            .forEach { super.drawRect($0) }
    }*/

@end
