// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Theme.h"
#include "CocoaAppearanceManager.h"

CocoaAppearanceManager& CocoaAppearanceManager::Instance()
{
    static const auto i = new CocoaAppearanceManager;
    return *i;
}

void CocoaAppearanceManager::ManageWindowApperance( NSWindow *_window )
{
    LOCK_GUARD(m_WindowsLock) {
        m_Windows.emplace_back(_window); // only adding at the moment, shouldn't be a problem
    }
    _window.appearance = CurrentTheme().Appearance();
}

void CocoaAppearanceManager::UpdateCurrentAppearance()
{
    LOCK_GUARD(m_WindowsLock) {
        for( NSWindow *w: m_Windows )
            if( w )
                w.appearance = CurrentTheme().Appearance();
    }
}
