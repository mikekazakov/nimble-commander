//
//  PanelController+NavigationMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 10/08/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "Common.h"
#import "PanelController+NavigationMenu.h"

@implementation PanelController (NavigationMenu)

- (void) abraCadabra
{
    auto hist_items = m_History.All();
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    int indx = 0;
    for( auto i = rbegin(hist_items), e = rend(hist_items); i != e; ++i, ++indx ) {
        auto &item = *i;
        
        NSString *title = [NSString stringWithUTF8StdString:item.get().verbose_string()];
        
        if( ![menu itemWithTitle:title] ) {
            NSMenuItem *it = [[NSMenuItem alloc] init];
            
            it.title = title;
            it.tag = hist_items.size() - indx - 1;
            it.target = self;
            it.action = @selector(doCalloutByHistoryPopupMenuItem:);
            [menu addItem:it];
        }
    }
    if( menu.itemArray.count > 1 && m_History.IsRecording() )
        [menu removeItemAtIndex:0];
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, 0) inView:self.view];
}

- (void)doCalloutByHistoryPopupMenuItem:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto hist = m_History.RewindAt(item.tag) )
            [self GoToVFSPathStack:*hist];
}

@end
