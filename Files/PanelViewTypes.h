//
//  PanelViewTypes.h
//  Files
//
//  Created by Pavel Dogurevich on 10.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

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
    PanelData       *Data       {nullptr};
    int             CursorPos   {-1};
    PanelViewType   ViewType    {PanelViewType::ViewMedium};
    bool            Active      {false};
    int             ItemsDisplayOffset {0};
};
