//
//  GoToFolderSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

@class PanelController;

@interface GoToFolderSheetController : NSWindowController <NSTextFieldDelegate>

@property (strong)      PanelController     *panel;
@property (readonly)    const string        &requestedPath;

- (void)showSheetWithParentWindow:(NSWindow *)_window
                          handler:(function<void()>)_handler;
- (void)tellLoadingResult:(int)_code;

@end
