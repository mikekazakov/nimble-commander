// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class PanelController;

@interface GoToFolderSheetController : NSWindowController <NSTextFieldDelegate>

@property (nonatomic)      PanelController     *panel;
@property (nonatomic, readonly)    const string        &requestedPath;

- (void)showSheetWithParentWindow:(NSWindow *)_window
                          handler:(function<void()>)_handler;
- (void)tellLoadingResult:(int)_code;

@end
