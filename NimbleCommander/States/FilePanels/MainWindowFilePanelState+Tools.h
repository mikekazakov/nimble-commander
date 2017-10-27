// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowFilePanelState.h"
#include "ExternalToolsSupport.h"

@interface MainWindowFilePanelState (ToolsSupport)

- (void) runExtTool:(shared_ptr<const ExternalTool>)_tool;

@end
