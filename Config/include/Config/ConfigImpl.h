// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Config.h"
#include "RapidJSON.h"
#include <Habanero/spinlock.h>
#include <Habanero/intrusive_ptr.h>
#include <vector>
#include <unordered_map>
#include "OverwritesStorage.h"
#include "Executor.h"

namespace nc::config {
    
class ConfigImpl : public Config
{
public:
    ConfigImpl
    (std::string_view _default_document,
     std::shared_ptr<OverwritesStorage> _storage,
     std::shared_ptr<Executor> _overwrites_dump_executor = std::make_shared<ImmediateExecutor>(),
     std::shared_ptr<Executor> _overwrites_reload_executor = std::make_shared<ImmediateExecutor>());
    virtual ~ConfigImpl();
    
    bool Has(std::string_view _path) const override;
    
    Value Get(std::string_view _path) const override;
    Value GetDefault(std::string_view _path) const override;    

    std::string GetString(std::string_view _path) const override;
    bool GetBool(std::string_view _path) const override;
    int GetInt(std::string_view _path) const override;
    unsigned int GetUInt(std::string_view _path) const override;
    long GetLong(std::string_view _path) const override;
    unsigned long GetULong(std::string_view _path) const override;
    double GetDouble(std::string_view _path) const override;

    void Set(std::string_view _path, const Value &_value) override;
    void Set(std::string_view _path, int _value) override;
    void Set(std::string_view _path, unsigned int _value) override;
    void Set(std::string_view _path, long _value) override;
    void Set(std::string_view _path, unsigned long _value) override;
    void Set(std::string_view _path, double _value) override;
    void Set(std::string_view _path, bool _value) override;
    void Set(std::string_view _path, const char *_value) override;
    void Set(std::string_view _path, std::string_view _value) override;
  
    Token Observe(std::string_view _path, std::function<void()> _on_change) override;
    void ObserveForever(std::string_view _path, std::function<void()> _on_change) override;
    
    /**
     * Discards any overwrites and reverts the state of the config to the 'defaults' state.
     * Immediate writes the updated (i.e. empty) overwrites). 
     */
    void ResetToDefaults();
    
    /**
     * Forces the config to write pending overwrites immmediately, bypassing the executor provided
     * upoon construction. If there are no pending changes to be written - does nothing.
     */
    void Commit();
    
private:
    struct Observer : hbn::intrusive_ref_counter<Observer>
    {
        Observer(unsigned long _token, std::function<void()> _callback) noexcept;
        mutable bool was_removed = false;        
        unsigned long token;
        std::function<void()> callback;
        mutable std::recursive_mutex lock;
    };
    static_assert( sizeof(Observer) == 128 );    
    using ObserverPtr = hbn::intrusive_ptr<const Observer>; 
    
    struct Observers : hbn::intrusive_ref_counter<Observers>
    {
        std::vector<ObserverPtr> observers;
    };
    static_assert( sizeof(Observers) == 32 );
    using ObserversPtr = hbn::intrusive_ptr<const Observers>;
    
    void DropToken(unsigned long _number) override;
    const rapidjson::Value *FindInDocument_Unlocked(std::string_view _path) const;
    const rapidjson::Value *FindInDefaults_Unlocked(std::string_view _path) const;
    void SetInternal(std::string_view _path, const Value &_value);
    bool ReplaceOrInsert(std::string_view _path, const Value &_value);
    void InsertObserver(std::string_view _path, ObserverPtr _observer);
    void FireObservers(std::string_view _path) const;
    template <typename Iterator>
    void FireObservers(Iterator _first, Iterator _last) const {
        std::for_each(_first, _last, [this](auto &_v){ this->FireObservers(_v); });
    }    
    ObserversPtr FindObservers(std::string_view _path) const;
    void MarkDirty();
    void WriteOverwrites();
    void OverwritesDidChange();
    void ReloadOverwrites();
    
    rapidjson::Document                             m_Defaults;    
    
    rapidjson::Document                             m_Document;
    mutable spinlock                                m_DocumentLock;    
    
    std::unordered_map<std::string, ObserversPtr>   m_Observers;
    mutable spinlock                                m_ObserversLock;
    
    std::atomic_ullong                                                  m_ObservationToken{ 1 };
    std::atomic_flag                                                    m_WriteScheduled{ false };
    std::atomic_flag                                                    m_ReadScheduled{ false };    
    
    std::shared_ptr<OverwritesStorage>              m_OverwritesStorage;
    std::shared_ptr<Executor>                       m_OverwritesDumpExecutor;
    std::shared_ptr<Executor>                       m_OverwritesReloadExecutor;    
};
    
}
