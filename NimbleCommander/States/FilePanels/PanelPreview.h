#pragma once

#include <VFS/VFS_fwd.h>

@class PanelController;

@protocol NCPanelPreview <NSObject>
@required

- (void)previewVFSItem:(const VFSPath&)_path forPanel:(PanelController*)_panel;

@end
