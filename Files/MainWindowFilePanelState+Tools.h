#include "MainWindowFilePanelState.h"
#include "../NimbleCommander/States/FilePanels/ExternalToolsSupport.h"
@interface MainWindowFilePanelState (ToolsSupport)




- (void) runExtTool:(shared_ptr<const ExternalTool>)_tool;
@end