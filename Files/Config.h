#pragma once

#include "3rd_party/rapidjson/include/rapidjson/rapidjson.h"
#include "3rd_party/rapidjson/include/rapidjson/document.h"

class GenericConfig;

#ifdef __OBJC__
// GenericConfigObjC is not KVO-complaint, only KVC-complaint!
@interface GenericConfigObjC : NSObject
- (instancetype) initWithConfig:(GenericConfig*)_config;
@end
#endif

class GenericConfig
{
public:
    static rapidjson::CrtAllocator g_CrtAllocator;
    
    GenericConfig(const string &_defaults, const string &_overwrites);
    
    typedef rapidjson::GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> ConfigValue;
    
    ConfigValue Get(const string &_path) const;
    ConfigValue Get(const char *_path) const;
    optional<string> GetString(const char *_path) const;

    /**
     * Return false if value wasn't found.
     */
    bool GetBool(const char *_path) const;
    
    /**
     * Return 0 if value wasn't found.
     */
    int GetInt(const char *_path) const;
    
    bool Set(const char *_path, int _value);
    bool Set(const char *_path, unsigned int _value);
    bool Set(const char *_path, long long _value);
    bool Set(const char *_path, unsigned long long _value);
    bool Set(const char *_path, double _value);
    bool Set(const char *_path, bool _value);
    bool Set(const char *_path, const string &_value);
    bool Set(const char *_path, const char *_value);
    
    struct ObservationTicket
    {
        ObservationTicket(ObservationTicket &&) noexcept;
        ~ObservationTicket();
        const ObservationTicket &operator=(ObservationTicket &&);
        operator bool() const noexcept;
    private:
        ObservationTicket(GenericConfig *_inst, unsigned long _ticket) noexcept;
        ObservationTicket(const ObservationTicket&) = delete;
        void operator=(const ObservationTicket&) = delete;
        
        GenericConfig  *instance;
        unsigned long   ticket;
        friend class GenericConfig;
    };
    
    ObservationTicket Observe(const char *_path, function<void()> _change_callback);
    
#ifdef __OBJC__
    inline GenericConfigObjC    *Bridge() const { return m_Bridge; }
#endif
    
private:
    struct Observer
    {
        function<void()> callback;
        unsigned long ticket;
    };
    
    shared_ptr<vector<shared_ptr<Observer>>>        FindObserversLocked(const char *_path);
    void        FireObservers(const char *_path);
    void        StopObserving(unsigned long _ticket);
    ConfigValue GetInternal(string_view _path) const;
    bool        SetInternal(const char *_path, const ConfigValue &_value);
    void        DumpOverwrites();
    
    mutable mutex                                                       m_DocumentLock;
    rapidjson::Document                                                 m_Current;
    rapidjson::Document                                                 m_Defaults;
    unordered_map<string, shared_ptr<vector<shared_ptr<Observer>>>>     m_Observers;
    mutable mutex                                                       m_ObserversLock;
    
    string                                                              m_DefaultsPath;
    string                                                              m_OverwritesPath;
    atomic_ullong                                                       m_ObservationTicket{ 1 };
#ifdef __OBJC__
    GenericConfigObjC                                                  *m_Bridge;
#endif
    friend struct ObservationTicket;
};


GenericConfig &GlobalConfig() noexcept;
