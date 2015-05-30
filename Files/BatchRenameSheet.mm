//
//  BatchRenameSheet.m
//  Files
//
//  Created by Michael G. Kazakov on 17/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "BatchRenameSheet.h"
#import "BatchRenameSheetController.h"
#include <Carbon/Carbon.h>

@implementation BatchRenameSheet


- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if(event.type == NSKeyDown && (event.modifierFlags & NSControlKeyMask) ) {
        auto keycode = event.keyCode;
        if( keycode == kVK_ANSI_N ) { // ctrl+n
            [self.windowController OnInsertNamePlaceholder:self];
            return true;
        }
        if( keycode == kVK_ANSI_R ) { // ctrl+r
            [self.windowController OnInsertNameRangePlaceholder:self];
            return true;
        }
        if( keycode == kVK_ANSI_C ) { // ctrl+c
            [self.windowController OnInsertCounterPlaceholder:self];
            return true;
        }
        if( keycode == kVK_ANSI_E ) { // ctrl+e
            [self.windowController OnInsertExtensionPlaceholder:self];
            return true;
        }
        if( keycode == kVK_ANSI_D ) { // ctrl+d
            [self.windowController OnInsertDatePlaceholder:self];
            return true;
        }
        if( keycode == kVK_ANSI_T ) { // ctrl+t
            [self.windowController OnInsertTimePlaceholder:self];
            return true;
        }
        if( keycode == kVK_ANSI_A ) { // ctrl+a
            [self.windowController OnInsertMenu:self];
            return true;
        }
    }
    return [super performKeyEquivalent:event];
}


@end
