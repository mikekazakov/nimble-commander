// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelPreview.h"

@class QLPreviewPanel;
@class MainWindowFilePanelState;

@interface NCPanelQLPanelAdaptor : NSObject<NCPanelPreview>

+ (NCPanelQLPanelAdaptor*) adaptorForState:(MainWindowFilePanelState*)_state;
+ (void)registerQuickLook:(QLPreviewPanel *)_ql_panel forState:(MainWindowFilePanelState*)_state;
+ (void)unregisterQuickLook:(QLPreviewPanel *)_ql_panel forState:(MainWindowFilePanelState*)_state;

@end
