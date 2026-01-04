// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreGraphics/CGEventTypes.h>

namespace nc::utility {

class FunctionalKeysPass
{
    FunctionalKeysPass();

public:
    FunctionalKeysPass(const FunctionalKeysPass &) = delete;
    void operator=(const FunctionalKeysPass &) = delete;

    static FunctionalKeysPass &Instance() noexcept;

    [[nodiscard]] bool Enabled() const;
    bool Enable();
    void Disable();

private:
    static bool ObtainAccessiblityRights();
    static CGEventRef HandleRegularKeyEvents(CGEventType _type, CGEventRef _event) noexcept;
    static CGEventRef HandleControlButtons(CGEventType _type, CGEventRef _event) noexcept;
    CGEventRef Callback(CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event) noexcept;
    void OnDidBecomeActive() noexcept;
    void OnResignActive() noexcept;

    CFMachPortRef m_Port = nullptr;
    bool m_Enabled = false;
};

} // namespace nc::utility
