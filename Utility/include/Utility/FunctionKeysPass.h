// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
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
    CGEventRef      Callback(CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event);
    CFMachPortRef   m_Port;
    bool            m_Enabled;
};
