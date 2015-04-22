//
//  FindFilesSheet.m
//  Files
//
//  Created by Michael G. Kazakov on 22/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "FindFilesSheet.h"
#import "FindFilesSheetController.h"

@implementation FindFilesSheet

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if(event.type == NSKeyDown) {
        if( event.modifierFlags & NSCommandKeyMask ){
            auto keycode = event.keyCode;
            if( keycode == 17 ) { // cmd+t
                [self.windowController focusContainingText:self];
                return true;
            }
            if( keycode == 46 ) { // cmd+m
                [self.windowController focusMask:self];
                return true;
            }
            if( keycode == 1 ) { // cmd+s
                [self.windowController focusSize:self];
                return true;
            }
        }
    }
    return [super performKeyEquivalent:event];
}


@end
