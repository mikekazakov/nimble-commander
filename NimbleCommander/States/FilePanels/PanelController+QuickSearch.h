//
//  PanelController+QuickSearch.h
//  Files
//
//  Created by Michael G. Kazakov on 25.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (QuickSearch)

/**
 * QuickSearchClearFiltering turn off any filtering (nor soft or hard), forces PanelData to rebuild it's indeces
 * and causes PanelView to possibile modify cursor position and scrolling.
 */
- (void) QuickSearchClearFiltering;

/**
 * Returns true if event was processed
 */
- (bool) QuickSearchProcessKeyDown:(NSEvent *)event;

- (void) QuickSearchSetCriteria:(NSString *)_text;

/**
 * Updates textual info after panel data changed.
 */
- (void) QuickSearchUpdate;

@end
