// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreGraphics/CGEventTypes.h>

namespace nc::utility {

class FunctionalKeysPass
{
    FunctionalKeysPass();
    FunctionalKeysPass(const FunctionalKeysPass&) = delete;
    void operator=(const FunctionalKeysPass&) = delete;
public:
    static FunctionalKeysPass &Instance();
    
    bool Enabled() const;
    bool Enable();
    void Disable();
private:
    bool ObtainAccessiblityRights();
    CGEventRef HandleRegularKeyEvents(CGEventType _type, CGEventRef _event);
    CGEventRef HandleControlButtons(CGEventType _type, CGEventRef _event);
    CGEventRef      Callback(CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event);
    CFMachPortRef   m_Port;
    bool            m_Enabled;
};

}
