//
//  PanelViewTypes.h
//  Files
//
//  Created by Pavel Dogurevich on 10.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <stack>

using namespace std;

class PanelData;

enum class PanelViewType
{
    ViewShort,
    ViewMedium,
    ViewFull,
    ViewWide
};

enum class PanelViewDirectoryChangeType
{
    GoIntoSubDir,
    GoIntoParentDir,
    GoIntoOtherDir
};

struct PanelViewState
{
    PanelViewState()
    :   Data(0),
        CursorPos(-1),
        Active(false),
        ViewType(PanelViewType::ViewMedium),
        ItemsDisplayOffset(0)
    {}
    
    PanelData *Data;
    int CursorPos;
    PanelViewType ViewType;
    bool Active;
    
    int ItemsDisplayOffset;
    stack<int> DisplayOffsetStack;
};