//
//  MainWindow.m
//  Files
//
//  Created by Michael G. Kazakov on 01/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "MainWindow.h"
#import "ActionsShortcutsManager.h"

@implementation MainWindow

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    
    IF_MENU_TAG("menu.file.close") {
        item.title = @"Close Window";
        return true;
    }
    IF_MENU_TAG("menu.file.close_window") {
        item.hidden = true;
        return true;
    }
    
    return true;
}

- (IBAction)OnFileCloseWindow:(id)sender { /* dummy, never called */ }

@end
