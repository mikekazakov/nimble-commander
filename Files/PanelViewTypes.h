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
    ViewShort,
    ViewMedium,
    ViewFull,
    ViewWide
};

struct PanelViewState
{
    PanelData       *Data        = nullptr;
    int             CursorPos    = -1;
    PanelViewType   ViewType     = PanelViewType::ViewMedium;
    int             ItemsDisplayOffset  = 0;
};

namespace PanelViewHitTest {
    enum Options {
        FullArea,
        FilenameArea,
        FilenameFact,
    };
};
