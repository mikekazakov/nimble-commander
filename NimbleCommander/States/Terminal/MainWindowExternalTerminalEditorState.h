//
//  MainWindowExternalTerminalEditorState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../../NimbleCommander/States/MainWindowStateProtocol.h"

@interface MainWindowExternalTerminalEditorState : NSView<MainWindowStateProtocol>

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const path&)_binary_path
                      params:(const string&)_params
                   fileTitle:(const string&)_file_title; // _file_title is used only for window title

@end

