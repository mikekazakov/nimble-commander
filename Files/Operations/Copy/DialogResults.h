//
//  DialogResults.h
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../OperationDialogProtocol.h"

namespace FileCopyOperationDR
{
    using namespace OperationDialogResult;
    
    constexpr int Overwrite = Custom + 1;
    constexpr int Append    = Custom + 2;
}
