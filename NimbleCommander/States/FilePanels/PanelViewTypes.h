//
//  PanelViewTypes.h
//  Files
//
//  Created by Pavel Dogurevich on 10.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

enum class PanelViewFilenameTrimming : int8_t
{
    Heading     = 0,
    Middle      = 1,
    Trailing    = 2
};

namespace PanelViewHitTest {
    enum Options : int8_t {
        FullArea,
        FilenameArea,
        FilenameFact,
    };
};
