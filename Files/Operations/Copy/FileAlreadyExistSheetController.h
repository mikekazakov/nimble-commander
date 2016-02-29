//
//  FileAlreadyExistSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../OperationDialogProtocol.h"
#include "../../SheetController.h"

@interface FileAlreadyExistSheetController : SheetController<OperationDialogProtocol>

- (id)initWithFile:(const char*)_path
           newsize:(unsigned long)_newsize
           newtime:(time_t) _newtime
           exisize:(unsigned long)_exisize
           exitime:(time_t) _exitime
          remember:(bool*)  _remb
            single:(bool) _single;

@end
