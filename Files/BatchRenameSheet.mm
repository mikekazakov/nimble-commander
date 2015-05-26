//
//  BatchRenameSheet.m
//  Files
//
//  Created by Michael G. Kazakov on 17/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "BatchRenameSheet.h"
#import "BatchRenameSheetController.h"

@implementation BatchRenameSheet


- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if(event.type == NSKeyDown) {
        if( event.modifierFlags & NSControlKeyMask ){
            auto keycode = event.keyCode;
            if( keycode == 45 ) { // ctrl+n
                [self.windowController OnInsertNamePlaceholder:self];
                return true;
            }
            if( keycode == 15 ) { // ctrl+r
                [self.windowController OnInsertNameRangePlaceholder:self];
                return true;
            }
            if( keycode == 8 ) { // ctrl+c
                [self.windowController OnInsertCounterPlaceholder:self];
                return true;
            }
        }
    }
    return [super performKeyEquivalent:event];
}


@end
