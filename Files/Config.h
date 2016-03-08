#pragma once

#include "3rd_party/rapidjson/include/rapidjson/rapidjson.h"
#include "3rd_party/rapidjson/include/rapidjson/document.h"
#include "DispatchQueue.h"

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
    
    /**
     * This will erase all custom-defined config settings and fire all observers for values that have changed.
     */
    void ResetToDefaults();
    
    void NotifyAboutShutdown();
    
    typedef rapidjson::GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> ConfigValue;
    
    bool Has(const char *_path) const;
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
    
    bool Set(const char *_path, const ConfigValue &_value);
    bool Set(const char *_path, int _value);
    bool Set(const char *_path, unsigned int _value);
    bool Set(const char *_path, long long _value);
    bool Set(const char *_path, unsigned long long _value);
    bool Set(const char *_path, double _value);
    bool Set(const char *_path, bool _value);
    bool Set(const char *_path, const string &_value);
    bool Set(const char *_path, const char *_value);
    
    struct ObservationTicket;
    
    ObservationTicket Observe(const char *_path, function<void()> _change_callback);
    template <typename C, typename T>
    void ObserveMany(C &_storage, function<void()> _change_callback, const T &_paths )
    {
        for( const auto &i: _paths )
            _storage.emplace_back( Observe(i, _change_callback) );
    }
    
private:
    struct Observer
    {
        function<void()> callback;
        unsigned long ticket;
    };
    
    shared_ptr<vector<shared_ptr<Observer>>>        FindObserversLocked(const char *_path) const;
    shared_ptr<vector<shared_ptr<Observer>>>        FindObserversLocked(const string &_path) const;
    void        FireObservers(const char *_path) const;
    void        FireObservers(const string& _path) const;
    void        StopObserving(unsigned long _ticket);
    ConfigValue GetInternal(string_view _path) const;
    const rapidjson::Value *FindUnlocked(string_view _path) const;
    bool        SetInternal(const char *_path, const ConfigValue &_value);
    void        RunOverwritesDumping();
    void        MarkDirty();
    static void WriteOverwrites(const rapidjson::Document &_overwrites_diff, string _path);
    void        OnOverwritesFileDirChanged();
    void        MergeChangedOverwrites(const rapidjson::Document &_new_overwrites_diff);
    
    mutable mutex                                                       m_DocumentLock;
    rapidjson::Document                                                 m_Current;
    rapidjson::Document                                                 m_Defaults;
    unordered_map<string, shared_ptr<vector<shared_ptr<Observer>>>>     m_Observers;
    mutable mutex                                                       m_ObserversLock;
    
    string                                                              m_DefaultsPath;
    string                                                              m_OverwritesPath;
    atomic_ullong                                                       m_ObservationTicket{ 1 };
    SerialQueue                                                         m_IOQueue = SerialQueueT::Make("GenericConfig input/output queue");
    atomic_flag                                                         m_WriteScheduled{ false };
    atomic_flag                                                         m_ReadScheduled{ false };
    time_t                                                              m_OverwritesTime = 0;
    friend struct ObservationTicket;
};

GenericConfig &GlobalConfig() noexcept;
GenericConfig &StateConfig() noexcept;

struct GenericConfig::ObservationTicket
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
