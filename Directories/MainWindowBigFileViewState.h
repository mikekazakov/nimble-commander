//
//  MainWindowBigFileViewState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainWindowStateProtocol.h"
#import "BigFileView.h"

@interface MainWindowBigFileViewState : NSView<MainWindowStateProtocol, BigFileViewDelegateProtocol>

- (bool) OpenFile: (const char*) _fn;


@end
