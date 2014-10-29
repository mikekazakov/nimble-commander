//
//  FilePanelsTabbedHolder.h
//  Files
//
//  Created by Michael G. Kazakov on 28/10/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rd_party/MMTabBarView/MMTabBarView/MMTabBarView.h"
#import "PanelView.h"

@interface FilePanelsTabbedHolder : NSStackView

@property (nonatomic, readonly) MMTabBarView *tabBar;
@property (nonatomic, readonly) NSTabView    *tabView;
@property (nonatomic, readonly) PanelView    *current; // can return nil in case if there's no panels inserted or in some other weird cases

- (void) addPanel:(PanelView*)_panel;

@end
