//
//  MyToolbar.h
//  Files
//
//  Created by Michael G. Kazakov on 27.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MyToolbar : NSView

- (void) InsertView:(NSView*) _view;
- (void) InsertFlexSpace;

- (void) UpdateVisibility;

@end
