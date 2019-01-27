// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CocoaAppearanceManager.h"

namespace nc::utility {

CocoaAppearanceManager::CocoaAppearanceManager()
{
    m_Appearance = [NSAppearance currentAppearance];
}

CocoaAppearanceManager& CocoaAppearanceManager::Instance()
{
    static const auto instance = new CocoaAppearanceManager;
    return *instance;
}

void CocoaAppearanceManager::ManageWindowApperance( NSWindow *_window )
{
    LOCK_GUARD(m_WindowsLock) {
        m_Windows.emplace_back(_window); // only adding at the moment, shouldn't be a problem
    }
    _window.appearance = m_Appearance;
}

void CocoaAppearanceManager::UpdateCurrentAppearance()
{
    LOCK_GUARD(m_WindowsLock) {
        for( NSWindow *window: m_Windows )
            if( window ) {
                window.appearance = m_Appearance;
            }
    }
}

void CocoaAppearanceManager::SetCurrentAppearance( NSAppearance *_appearance )
{
    if( m_Appearance == _appearance )
        return;
    m_Appearance = _appearance;
    UpdateCurrentAppearance();
}

}
