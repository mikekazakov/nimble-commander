// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <vector>
#include <string>

@interface ExternalToolParameterValueSheetController : SheetController

- (id)initWithValueNames:(std::vector<std::string>)_names toolName:(const std::string &)_name;

@property(nonatomic, readonly) const std::vector<std::string> &values;

@end
