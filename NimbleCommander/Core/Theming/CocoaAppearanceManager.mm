#include "Theme.h"
#include "CocoaAppearanceManager.h"

CocoaAppearanceManager& CocoaAppearanceManager::Instance()
{
    static const auto i = new CocoaAppearanceManager;
    return *i;
}

void CocoaAppearanceManager::ManageWindowApperance( NSWindow *_window )
{
    _window.appearance = CurrentTheme().Appearance();
    // ....
}

