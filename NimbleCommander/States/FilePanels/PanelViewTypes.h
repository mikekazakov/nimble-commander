//
//  PanelViewTypes.h
//  Files
//
//  Created by Pavel Dogurevich on 10.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class PanelData;

//enum class PanelViewType : int8_t
//{
//    Short   = 0,
//    Medium  = 1,
//    Full    = 2,
//    Wide    = 3
//};

enum class PanelViewFilenameTrimming : int8_t
{
    Heading     = 0,
    Middle      = 1,
    Trailing    = 2
};

// not used anymore
//struct PanelViewState
//{
//    PanelData                  *Data                = nullptr;
//    int                         CursorPos           = -1;
//    PanelViewType               ViewType            = PanelViewType::Medium;
//    int                         ItemsDisplayOffset  = 0;
//};

namespace PanelViewHitTest {
    enum Options : int8_t {
        FullArea,
        FilenameArea,
        FilenameFact,
    };
};
