// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ExternalToolsSupport.h"


@interface ToolsMenuDelegateInfoWrapper : NSObject
@property (nonatomic, readonly) shared_ptr<const ExternalTool> object;
@end

@interface ToolsMenuDelegate : NSObject<NSMenuDelegate>

@end
