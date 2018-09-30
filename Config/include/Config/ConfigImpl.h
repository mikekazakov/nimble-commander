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
    
private:
    struct Observer : hbn::intrusive_ref_counter<Observer>
    {
        Observer(unsigned long _token, std::function<void()> _callback) noexcept;
        mutable bool was_removed = false;        
        unsigned long token;
        std::function<void()> callback;
        mutable std::recursive_mutex lock;
    };
    using ObserverPtr = hbn::intrusive_ptr<const Observer>; 
    
    struct Observers : hbn::intrusive_ref_counter<Observers>
    {
        std::vector<ObserverPtr> observers;
    };
    using ObserversPtr = hbn::intrusive_ptr<const Observers>; 
    
    void DropToken(unsigned long _number) override;
    const rapidjson::Value *FindInDocument_Unlocked(std::string_view _path) const;
    const rapidjson::Value *FindInDefaults_Unlocked(std::string_view _path) const;
    void SetInternal(std::string_view _path, const Value &_value);
    bool ReplaceOrInsert(std::string_view _path, const Value &_value);
    void InsertObserver(std::string_view _path, ObserverPtr _observer);
    void FireObservers(std::string_view _path) const;
    ObserversPtr FindObservers(std::string_view _path) const;
    void MarkDirty();
    void WriteOverwrites();
    
    rapidjson::Document                             m_Defaults;    
    
    rapidjson::Document                             m_Document;
    mutable spinlock                                m_DocumentLock;    
    
    std::unordered_map<std::string, ObserversPtr>   m_Observers;
    mutable spinlock                                m_ObserversLock;
    
    std::atomic_ullong                                                  m_ObservationToken{ 1 };
//    SerialQueue                                                         m_IOQueue{"GenericConfig input/output queue"};
    std::atomic_flag                                                    m_WriteScheduled{ false };
//    atomic_flag                                                         m_ReadScheduled{ false };
//    time_t                                                              m_OverwritesTime = 0;    
    
    std::shared_ptr<OverwritesStorage>              m_OverwritesStorage;
    std::shared_ptr<Executor>                       m_OverwritesDumpExecutor;
    std::shared_ptr<Executor>                       m_OverwritesReloadExecutor;    
};
    
}
