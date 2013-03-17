//
//  AppDelegate.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "PanelView.h"
#include "JobView.h"


@interface AppDelegate : NSObject <NSApplicationDelegate>

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long) _ticket;

@end
