// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>

@interface ExternalToolParameterValueSheetController : SheetController

- (id) initWithValueNames:(std::vector<string>)_names;

@property (nonatomic, readonly) const std::vector<string>& values;

@end
