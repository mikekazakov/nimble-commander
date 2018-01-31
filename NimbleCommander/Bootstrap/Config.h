// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Core/rapidjson_fwd.h"

class GenericConfig;

#ifdef __OBJC__
// GenericConfigObjC is not KVO-complaint, only KVC-complaint!
@interface GenericConfigObjC : NSObject
- (instancetype) initWithConfig:(GenericConfig*)_config;
+ (id)valueForKeyPath:(const char*)keyPath inConfig:(GenericConfig*)_config;
+ (void)setValue:(id)value forKeyPath:(NSString *)keyPath inConfig:(GenericConfig*)_config;
@end
#endif

// TODO: rebuild GenericConfig into an abstact interface and two implementations:
// - files-backed config
// - temporary config initialized from memory
class GenericConfig
{
public:
    static rapidjson::CrtAllocator g_CrtAllocator;
    
    GenericConfig(const string &_initial_json_value);
    GenericConfig(const string &_defaults_path, const string &_overwrites_path);
    ~GenericConfig();
    
    /**
     * This will erase all custom-defined config settings and fire all observers for values that have changed.
     */
    void ResetToDefaults();
    
    /**
     * Force to write data to disk and wait - will block the caller.
     */
    void Commit();
    
    using ConfigValue = rapidjson::StandaloneValue;
    
    bool Has(const char *_path) const;
    ConfigValue Get(const string &_path) const;
    ConfigValue Get(const char *_path) const;
    ConfigValue GetDefault(const string &_path) const;
    ConfigValue GetDefault(const char *_path) const;
    optional<string> GetString(const char *_path) const;

    /**
     * Return false if value wasn't found.
     */
    bool GetBool(const char *_path) const;
    
    /**
     * Return 0 if value wasn't found.
     */
    int GetInt(const char *_path) const;

    /**
     * Return _default if value wasn't found.
     */
    int GetIntOr(const char *_path, int _default) const;
    
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
    
    ObservationTicket Observe(const char *_path, function<void()> _change_callback); // _change_callback can be fired from any thread
    void ObserveUnticketed(const char *_path, function<void()> _change_callback); // _change_callback can be fired from any thread
    template <typename C, typename T>
    void ObserveMany(C &_storage, function<void()> _change_callback, const T &_paths )
    {
        for( const auto &i: _paths )
            _storage.emplace_back( Observe(i, _change_callback) );
    }
    
private:
    struct Observer;
    struct State;
    
    shared_ptr<vector<shared_ptr<Observer>>>        FindObserversLocked(const char *_path) const;
    shared_ptr<vector<shared_ptr<Observer>>>        FindObserversLocked(const string &_path) const;
    void        FireObservers(const char *_path) const;
    void        FireObservers(const string& _path) const;
    void        StopObserving(unsigned long _ticket);
    ConfigValue GetInternal(string_view _path) const;
    bool        GetBoolInternal(string_view _path) const;
    ConfigValue GetInternalDefault(string_view _path) const;
    const rapidjson::Value *FindUnlocked(string_view _path) const;
    const rapidjson::Value *FindDefaultUnlocked(string_view _path) const;
    bool        SetInternal(const char *_path, const ConfigValue &_value);
    void        RunOverwritesDumping();
    void        MarkDirty();
    static void WriteOverwrites(const rapidjson::Document &_overwrites_diff, string _path);
    void        OnOverwritesFileDirChanged();
    void        MergeChangedOverwrites(const rapidjson::Document &_new_overwrites_diff);
    
    unique_ptr<State> I;

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
