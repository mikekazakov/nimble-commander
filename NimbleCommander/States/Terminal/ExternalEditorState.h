// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/States/MainWindowStateProtocol.h>

@interface NCTermExternalEditorState : NSView<NCMainWindowState>

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const path&)_binary_path
                      params:(const string&)_params
                   fileTitle:(const string&)_file_title; // _file_title is used only for window title

@end

