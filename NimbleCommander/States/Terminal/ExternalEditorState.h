// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/States/MainWindowStateProtocol.h>
#include <boost/filesystem.hpp>
#include <string>

@interface NCTermExternalEditorState : NSView<NCMainWindowState>

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const boost::filesystem::path&)_binary_path
                      params:(const std::string&)_params
                   fileTitle:(const std::string&)_file_title; // _file_title is used only for window title

@end

