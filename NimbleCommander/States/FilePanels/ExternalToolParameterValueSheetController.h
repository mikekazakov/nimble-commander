//
//  ExternalToolParameterValueSheetController.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 6/21/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>

@interface ExternalToolParameterValueSheetController : SheetController

- (id) initWithValueNames:(vector<string>)_names;

@property (readonly) const vector<string>& values;

@end
