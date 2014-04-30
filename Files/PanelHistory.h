//
//  PanelHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "VFS.h"

class PanelHistory
{
public:
    bool IsBeyond() const;
    bool IsBack() const;
    unsigned Length() const;

    void MoveForth();
    void MoveBack();
    void Put(const VFSPathStack& _path);
    const VFSPathStack* Current() const;
private:
    list<VFSPathStack>  m_History;
    unsigned            m_Position{0};
};
