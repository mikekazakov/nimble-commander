//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+Menu.h"
#import "PanelController.h"

@implementation MainWindowFilePanelState (Menu)

- (IBAction)OnOpen:(id)sender
{
    [[self ActivePanelController] HandleReturnButton];
}

- (IBAction)OnOpenNatively:(id)sender
{
    [[self ActivePanelController] HandleShiftReturnButton];
}

@end
