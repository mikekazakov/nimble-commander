//
//  MainWindowExternalTerminalEditorState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MainWindowStateProtocol.h"

@interface MainWindowExternalTerminalEditorState : NSView<MainWindowStateProtocol>

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const string&)_binary_path
                      params:(const string&)_params
                        file:(const string&)_file_path;

@end

