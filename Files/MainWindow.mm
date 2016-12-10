//
//  MainWindow.m
//  Files
//
//  Created by Michael G. Kazakov on 01/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "MainWindow.h"
#include "../NimbleCommander/Core/ActionsShortcutsManager.h"
#include "MainWindowController.h"

@implementation MainWindow

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    
    IF_MENU_TAG("menu.file.close") {
        item.title = NSLocalizedString(@"Close Window", "Menu item title");
        return true;
    }
    IF_MENU_TAG("menu.file.close_window") {
        item.hidden = true;
        return true;
    }
    
    return [super validateMenuItem:item];
}

- (IBAction)OnFileCloseWindow:(id)sender { /* dummy, never called */ }

- (IBAction)toggleToolbarShown:(id)sender
{
    if( auto wc = objc_cast<MainWindowController>(self.windowController) )
        [wc OnShowToolbar:sender];
    else
        [super toggleToolbarShown:sender];
}

@end
