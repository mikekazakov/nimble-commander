// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

//#include <NimbleCommander/Operations/OperationDialogProtocol.h>

namespace nc::ops {



namespace FileCopyOperationDR
{
//    using namespace OperationDialogResult;


    // No result, dialog is not finished.
    constexpr int None = 0;

    // Dialog is finished and the job must stop execution. Closing with this result invokes
    // [ParentOperation Close].
    // Any dialog can be closed with this result by the application.
    constexpr int Stop = 1;

    // Dialog is finished and the job can continue execution.
    constexpr int Continue = 2;
    
    constexpr int Retry = 3;

    constexpr int Skip = 4;

    constexpr int SkipAll = 5;
    
    // Add your own custom results starting from this constant.
    constexpr int Custom = 100;
    
    constexpr int Overwrite     = Custom + 1;
    constexpr int OverwriteOld  = Custom + 2;
    constexpr int Append        = Custom + 3;
}


}
