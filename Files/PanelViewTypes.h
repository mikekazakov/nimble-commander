//
//  PanelViewTypes.h
//  Files
//
//  Created by Pavel Dogurevich on 10.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class PanelData;

enum class PanelViewType
{
    Short   = 0,
    Medium  = 1,
    Full    = 2,
    Wide    = 3
};

enum class PanelViewFilenameTrimming
{
    Heading     = 0,
    Middle      = 1,
    Trailing    = 2
};

struct PanelViewState
{
    PanelData                  *Data                = nullptr;
    int                         CursorPos           = -1;
    PanelViewType               ViewType            = PanelViewType::Medium;
    PanelViewFilenameTrimming   Trimming            = PanelViewFilenameTrimming::Middle;
    int                         ItemsDisplayOffset  = 0;
};

namespace PanelViewHitTest {
    enum Options {
        FullArea,
        FilenameArea,
        FilenameFact,
    };
};
