// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/States/MainWindowStateProtocol.h>
#include <filesystem>
#include <string>

@interface NCTermExternalEditorState : NSView <NCMainWindowState>

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const std::filesystem::path &)_binary_path
                      params:(const std::string &)_params
                   fileTitle:(const std::string &)_file_title; // _file_title is used only for window title

@end
