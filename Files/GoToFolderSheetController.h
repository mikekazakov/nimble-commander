//
//  GoToFolderSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include "PanelController.h"

@interface GoToFolderSheetController : NSWindowController <NSTextFieldDelegate>

- (void)showSheetWithParentWindow:(NSWindow *)_window handler:(function<void()>)_handler;

- (void)tellLoadingResult:(int)_code;

- (IBAction)OnGo:(id)sender;
- (IBAction)OnCancel:(id)sender;

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *Error;
@property (strong) IBOutlet NSButton *GoButton;
@property (strong) PanelController      *panel;

@end
