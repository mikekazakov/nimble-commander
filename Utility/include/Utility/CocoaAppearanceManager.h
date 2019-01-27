// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/spinlock.h>
#include <vector>
#include <Cocoa/Cocoa.h>

namespace nc::utility {

// This abomination has to be a singleton at the moment,
// alternatives are much worse than that.
// As a plan: when 10.14 became the _lowest_ supported version - introduce
// something like themes_v2, where there will be _no_ override of a system appearance.
class CocoaAppearanceManager
{
public:
    CocoaAppearanceManager();
    static CocoaAppearanceManager& Instance();
    void ManageWindowApperance( NSWindow *_window );
    void SetCurrentAppearance( NSAppearance *_appearance );
    
private:
    void UpdateCurrentAppearance();
    spinlock m_WindowsLock;
    std::vector<__weak NSWindow*>m_Windows;
    NSAppearance *m_Appearance;
};

}
