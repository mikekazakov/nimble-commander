// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class CocoaAppearanceManager
{
public:
    static CocoaAppearanceManager& Instance();
    void ManageWindowApperance( NSWindow *_window );
    void UpdateCurrentAppearance();
    
private:
    spinlock                    m_WindowsLock;
    vector<__weak NSWindow*>    m_Windows;
};
