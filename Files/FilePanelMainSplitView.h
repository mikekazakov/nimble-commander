//
//  FilePanelMainSplitView.h
//  Files
//
//  Created by Michael G. Kazakov on 05.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FilePanelMainSplitView : NSSplitView<NSSplitViewDelegate>

- (void) SwapViews;
- (bool) AnyCollapsed;

@end
