// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/spinlock.h>
#include <vector>
#include <Cocoa/Cocoa.h>

class CocoaAppearanceManager
{
public:
    static CocoaAppearanceManager& Instance();
    void ManageWindowApperance( NSWindow *_window );
    void UpdateCurrentAppearance();
    
private:
    spinlock                    m_WindowsLock;
    std::vector<__weak NSWindow*>m_Windows;
};
