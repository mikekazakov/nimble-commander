#include "MainWindowFilePanelState.h"
#include "ExternalToolsSupport.h"
@interface MainWindowFilePanelState (ToolsSupport)




- (void) runExtTool:(shared_ptr<const ExternalTool>)_tool;
@end
