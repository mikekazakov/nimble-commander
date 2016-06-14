class FunctionalKeysPass
{
    FunctionalKeysPass();    
public:
    static FunctionalKeysPass &Instance();
    
    bool Enabled() const;
    bool Enable();
    void Disable();
private:
    CGEventRef Callback(CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event);
    CFMachPortRef m_Port;
};
