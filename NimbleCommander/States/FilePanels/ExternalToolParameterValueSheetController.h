// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>

@interface ExternalToolParameterValueSheetController : SheetController

- (id) initWithValueNames:(vector<string>)_names;

@property (nonatomic, readonly) const vector<string>& values;

@end
