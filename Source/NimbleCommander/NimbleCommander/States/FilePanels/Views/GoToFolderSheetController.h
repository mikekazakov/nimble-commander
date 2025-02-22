// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>
#include <string>
#include <Base/Error.h>
#include <expected>

@class PanelController;

@interface GoToFolderSheetController : NSWindowController <NSTextFieldDelegate>

@property(nonatomic) PanelController *panel;
@property(nonatomic, readonly) const std::string &requestedPath;

- (void)showSheetWithParentWindow:(NSWindow *)_window handler:(std::function<void()>)_handler;
- (void)tellLoadingResult:(const std::expected<void, nc::Error> &)_result;

@end
