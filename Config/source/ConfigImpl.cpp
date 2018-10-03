// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConfigImpl.h"
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>
#include <Habanero/algo.h>

namespace nc::config {

static rapidjson::Document ParseDefaultsOrThrow(std::string_view _default_document);
static rapidjson::Document ParseOverwritesOrReturnNull(std::string_view _overwrites_document);
    
static const rapidjson::Value *
    FindNode(std::string_view _path, const rapidjson::Value &_root) noexcept;
static std::pair<const rapidjson::Value *, std::string_view>
    FindParentNode(std::string_view _path, const rapidjson::Value &_root) noexcept;
static rapidjson::Document
    MergeDocuments( const rapidjson::Document &_main, const rapidjson::Document &_overwrites );
rapidjson::Document BuildOverwrites(const rapidjson::Document &_defaults,
                                    const rapidjson::Document &_staging);
static std::vector<std::string> ListDifferences(const rapidjson::Document &_original_document,
                                                const rapidjson::Document &_new_document);
static std::string Serialize(const rapidjson::Document &_document);
    
static const auto g_ParseFlags = rapidjson::kParseCommentsFlag;

ConfigImpl::ConfigImpl(std::string_view _default_document,
                       std::shared_ptr<OverwritesStorage> _storage,
                       std::shared_ptr<Executor> _overwrites_dump_executor,
                       std::shared_ptr<Executor> _overwrites_reload_executor):
    m_OverwritesStorage(_storage),
    m_OverwritesDumpExecutor(_overwrites_dump_executor),
    m_OverwritesReloadExecutor(_overwrites_reload_executor)
{
    if( _storage == nullptr )
        throw std::invalid_argument("ConfigImpl::ConfigImpl: overwrites storage can't be nullptr");
    
    if( _overwrites_dump_executor == nullptr || _overwrites_reload_executor == nullptr )
        throw std::invalid_argument("ConfigImpl::ConfigImpl: executor can't be nullptr");

    const auto defaults = ParseDefaultsOrThrow(_default_document);
    m_Defaults.CopyFrom(defaults, m_Defaults.GetAllocator());

    m_Document.CopyFrom(defaults, m_Document.GetAllocator());
    
    if( auto overwrites_text = m_OverwritesStorage->Read() ) {
        auto overwrites_document = ParseOverwritesOrReturnNull(*overwrites_text);
        if( overwrites_document.GetType() != rapidjson::Type::kNullType ) {
            auto new_doc = MergeDocuments(m_Document, overwrites_document);
            std::swap( m_Document, new_doc );
        }
    }
    
    m_OverwritesStorage->SetExternalChangeCallback([this]{
        OverwritesDidChange();
    });    
}

ConfigImpl::~ConfigImpl()
{
    m_OverwritesStorage->SetExternalChangeCallback(nullptr);
}
    
bool ConfigImpl::Has(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    return FindInDocument_Unlocked(_path) != nullptr;
}
    
const rapidjson::Value *ConfigImpl::FindInDocument_Unlocked(std::string_view _path) const
{
    return FindNode(_path, m_Document);
}
    
const rapidjson::Value *ConfigImpl::FindInDefaults_Unlocked(std::string_view _path) const
{
    return FindNode(_path, m_Defaults);        
}
    
Value ConfigImpl::Get(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        return Value{*value, g_CrtAllocator};
    return Value{rapidjson::kNullType};
}
    
Value ConfigImpl::GetDefault(std::string_view _path) const
{        
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDefaults_Unlocked(_path) )
        return Value{*value, g_CrtAllocator};
    return Value{rapidjson::kNullType};
}    

std::string ConfigImpl::GetString(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        if( value->GetType() == rapidjson::kStringType )
            return std::string{value->GetString(), value->GetStringLength()};
    return {};
}
    
bool ConfigImpl::GetBool(std::string_view _path) const
{        
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        return value->GetType() == rapidjson::kTrueType;
    return false;
}

template <typename T>
inline T ExtractNumericAs(const rapidjson::Value &_value) noexcept
{
    if( _value.IsInt() )            return static_cast<T>(_value.GetInt());
    else if( _value.IsUint() )      return static_cast<T>(_value.GetUint());
    else if( _value.IsInt64() )     return static_cast<T>(_value.GetInt64());
    else if( _value.IsUint64() )    return static_cast<T>(_value.GetUint64());
    else if( _value.IsDouble() )    return static_cast<T>(_value.GetDouble());
    else                            return T{};
}
    
int ConfigImpl::GetInt(std::string_view _path) const
{        
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        if( value->GetType() == rapidjson::kNumberType )
            return ExtractNumericAs<int>(*value);
    return 0;
}
    
unsigned int ConfigImpl::GetUInt(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        if( value->GetType() == rapidjson::kNumberType )
            return ExtractNumericAs<unsigned int>(*value);
    return 0;
}
    
long ConfigImpl::GetLong(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        if( value->GetType() == rapidjson::kNumberType )
            return ExtractNumericAs<long>(*value);
    return 0;
}
    
unsigned long ConfigImpl::GetULong(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        if( value->GetType() == rapidjson::kNumberType )
            return ExtractNumericAs<unsigned long>(*value);
    return 0;        
}   
    
double ConfigImpl::GetDouble(std::string_view _path) const
{
    const auto lock = std::lock_guard{m_DocumentLock};
    if( const auto value = FindInDocument_Unlocked(_path) )
        if( value->GetType() == rapidjson::kNumberType )
            return ExtractNumericAs<double>(*value);
    return 0.;
}
    
void ConfigImpl::Set(std::string_view _path, const Value &_value)
{
    SetInternal(_path, _value);
}
    
void ConfigImpl::Set(std::string_view _path, int _value)
{   
    SetInternal(_path, Value(_value));
}
    
void ConfigImpl::Set(std::string_view _path, unsigned int _value)
{
    SetInternal(_path, Value(_value));
}
    
void ConfigImpl::Set(std::string_view _path, long _value)
{
    SetInternal(_path, Value((int64_t)_value));
}
    
void ConfigImpl::Set(std::string_view _path, unsigned long _value)
{
    SetInternal(_path, Value((uint64_t)_value));
}
    
void ConfigImpl::Set(std::string_view _path, double _value)
{
    SetInternal(_path, Value(_value));
}
    
void ConfigImpl::Set(std::string_view _path, bool _value)
{
    SetInternal(_path, Value(_value));
}
 
void ConfigImpl::Set(std::string_view _path, const char *_value)
{
    if( _value == nullptr )
        return;
    Set(_path, std::string_view{_value});
}
    
void ConfigImpl::Set(std::string_view _path, std::string_view _value)
{
    SetInternal(_path, Value(_value.data(), (unsigned)_value.length(), g_CrtAllocator));
}
    
void ConfigImpl::SetInternal(std::string_view _path, const Value &_value)
{
    if( _path.empty() )
        return;
    
    if( ReplaceOrInsert(_path, _value) == true ) {
        FireObservers(_path);
        MarkDirty();
    }
}

bool ConfigImpl::ReplaceOrInsert(std::string_view _path, const Value &_value)
{
    const auto lock = std::lock_guard{m_DocumentLock};
    
    const auto [const_node, path_left] = FindParentNode(_path, m_Document);
    if( const_node == nullptr || path_left.empty() )
        return false;
    
    const auto node = const_cast<rapidjson::Value *>(const_node);
    const auto leaf_name = rapidjson::Value{
        rapidjson::StringRef(path_left.data(), path_left.length()) };
    
    if( const auto member_it = node->FindMember(leaf_name); member_it != node->MemberEnd() ) {
        if( member_it->value == _value )
            return false;
        
        member_it->value.CopyFrom( _value, m_Document.GetAllocator() );
    }
    else {
        auto key = rapidjson::Value{path_left.data(),
                                    (unsigned)path_left.length(),
                                    m_Document.GetAllocator() };                        
        auto value = rapidjson::Value{_value,
                                      m_Document.GetAllocator() };
        node->AddMember( key, value, m_Document.GetAllocator() );
    }
    return true;
}
  
Token ConfigImpl::Observe(std::string_view _path, std::function<void()> _on_change)
{
    if( !_on_change || _path.empty() )
        return CreateToken(0);
    
    const auto token = m_ObservationToken++;
    auto observer = hbn::intrusive_ptr{ new Observer{token, std::move(_on_change)} }; 
    
    InsertObserver(_path, std::move(observer));
    
    return CreateToken(token);
}
    
void ConfigImpl::ObserveForever(std::string_view _path, std::function<void()> _on_change)
{        
    if( !_on_change || _path.empty() )
        return;
    
    auto observer = hbn::intrusive_ptr{ new Observer{0, std::move(_on_change)} }; 
    InsertObserver(_path, std::move(observer));
}
    
void ConfigImpl::InsertObserver(std::string_view _path,
                                hbn::intrusive_ptr<const Observer> _observer)
{
    const auto path = std::string{_path};
    const auto lock = std::lock_guard{m_ObserversLock};
    if( auto current_observers_it = m_Observers.find(path);
        current_observers_it != std::end(m_Observers)  ) {
        // somebody is already watching this path        
        auto new_observers = hbn::intrusive_ptr{ new Observers };
        new_observers->observers.reserve( current_observers_it->second->observers.size() + 1 );
        new_observers->observers = current_observers_it->second->observers;
        new_observers->observers.emplace_back( std::move(_observer) );
        current_observers_it->second = new_observers;
    }
    else {
        // it's the first request to observe this path
        auto new_observers = hbn::intrusive_ptr{ new Observers };
        new_observers->observers.emplace_back( std::move(_observer) );
        m_Observers.emplace( std::move(path), std::move(new_observers) );
    }        
}
    
void ConfigImpl::DropToken(unsigned long _number)
{
    if( _number == 0 )
        return;
    
    const auto lock = std::lock_guard{m_ObserversLock};
    for( auto observers_it = m_Observers.begin(), observers_end = m_Observers.end();
        observers_it != observers_end;
        ++observers_it ) {
        auto &path = *observers_it;
        auto &observers = path.second->observers;
        
        const auto to_drop_it = std::find_if(begin(observers),
                                             end(observers),
                                             [_number](auto &observer){
            return observer->token == _number;
        });
        if( to_drop_it != end(observers) ) {
            const auto observer = *to_drop_it; // holding by a *strong* shared pointer
            
            // We need to guarantee that the callback will not be called after the token is
            // destroyed. To achieve this, the callback calls are guared by a *recursive* mutex
            // and its removal from the list is guarded by the same mutex.
            // Once the observer was marked as 'removed', the FireObservers method will not 
            // fire it even if it still has a version of observers list with this observer.
            // The mutex is recursive becase the callback might want to delete its own
            // observation token and we don't want to deadlock in this case.
            const auto lock = std::lock_guard{observer->lock};
            observer->was_removed = true;
            
            if( observers.size() > 1 ) {
                auto new_observers = hbn::intrusive_ptr{ new Observers };
                new_observers->observers.reserve( observers.size() - 1 );
                std::copy(observers.begin(),
                          to_drop_it,
                          std::back_inserter(new_observers->observers));
                std::copy(std::next(to_drop_it),
                          observers.end(),
                          std::back_inserter(new_observers->observers));
                path.second = std::move(new_observers);
            }
            else {
                m_Observers.erase(observers_it);
            }
            
            break;
        }
    }
}
    
void ConfigImpl::FireObservers(std::string_view _path) const
{
    if( const auto observers = FindObservers(_path) ) {
        for( const auto &observer: observers->observers ) {
            const auto lock = std::lock_guard{observer->lock};
            if( observer->was_removed == false ) {
                observer->callback();
            }
        }
    }
}

hbn::intrusive_ptr<const ConfigImpl::Observers>
    ConfigImpl::FindObservers(std::string_view _path) const
{
    const auto path = std::string{_path};
    const auto lock = std::lock_guard{m_ObserversLock};
    if( auto observers_it = m_Observers.find(path); observers_it != std::end(m_Observers) )
        return  observers_it->second;
    return nullptr;        
}
    
void ConfigImpl::MarkDirty()
{
    if( m_WriteScheduled.test_and_set() == false ) {
        m_OverwritesDumpExecutor->Execute([this]{
            WriteOverwrites();   
        });
    }
}   

void ConfigImpl::WriteOverwrites()
{
    auto clear_write_flag = at_scope_end([this]{ m_WriteScheduled.clear(); });
    
    rapidjson::Document overwrites_document;
    {
        auto lock = std::lock_guard{m_DocumentLock};
        overwrites_document = BuildOverwrites(m_Defaults, m_Document);
    }
    
    const auto overwrites_json = Serialize(overwrites_document);
    m_OverwritesStorage->Write(overwrites_json);
}
    
void ConfigImpl::ResetToDefaults()
{   
    std::vector<std::string> diffs;
    {
        auto lock = std::lock_guard{m_DocumentLock};
        diffs = ListDifferences(m_Document, m_Defaults);
        m_Document.CopyFrom(m_Defaults, m_Document.GetAllocator());
    }
    if( diffs.empty() )
        return;
    
    WriteOverwrites();
    
    FireObservers( begin(diffs), end(diffs) );
}

void ConfigImpl::Commit()
{        
    if( m_WriteScheduled.test_and_set() == true ) {
        WriteOverwrites();
    }
}
    
void ConfigImpl::OverwritesDidChange()
{
    if( m_ReadScheduled.test_and_set() == false ) {
        m_OverwritesReloadExecutor->Execute([this]{
            ReloadOverwrites();
        });
    }
}
    
void ConfigImpl::ReloadOverwrites()
{
    auto clear_read_flag = at_scope_end([this]{ m_ReadScheduled.clear(); });

    auto new_overwrites_text = m_OverwritesStorage->Read();
    if( new_overwrites_text == std::nullopt )
        return;
    
    auto new_overwrites_document = ParseOverwritesOrReturnNull(*new_overwrites_text);
    if( new_overwrites_document.GetType() == rapidjson::Type::kNullType )
        return;
    
    auto new_document = MergeDocuments(m_Defaults, new_overwrites_document);

    std::vector<std::string> diffs;    
    {
        auto lock = std::lock_guard{m_DocumentLock};
        diffs = ListDifferences(m_Document, new_document);
        m_Document.CopyFrom(new_document, m_Document.GetAllocator());
    }
    
    FireObservers( begin(diffs), end(diffs) );
}

ConfigImpl::Observer::Observer(unsigned long _token, std::function<void()> _callback) noexcept:
    token{_token},
    callback{std::move(_callback)}
{
}

static rapidjson::Document ParseDefaultsOrThrow(std::string_view _default_document)
{
    if( _default_document.empty() ) {
        return rapidjson::Document{rapidjson::kObjectType};
    }
    
    rapidjson::Document defaults;
    rapidjson::ParseResult ok = defaults.Parse<g_ParseFlags>(_default_document.data(),
                                                             _default_document.length());
    if( !ok ) {
        throw std::invalid_argument{ rapidjson::GetParseError_En(ok.Code()) };
    }
    
    return defaults;
}

static rapidjson::Document ParseOverwritesOrReturnNull(std::string_view _overwrites_document)
{
    if( _overwrites_document.empty() )
        return rapidjson::Document{rapidjson::kNullType};
    
    rapidjson::Document overwrites;
    rapidjson::ParseResult ok = overwrites.Parse<g_ParseFlags>(_overwrites_document.data(),
                                                               _overwrites_document.length());
    if( !ok )
        return rapidjson::Document{rapidjson::kNullType};
    
    if( overwrites.GetType() != rapidjson::Type::kObjectType )
        return rapidjson::Document{rapidjson::kNullType};
    
    return overwrites;
}
    
static const rapidjson::Value *
    FindNode(const std::string_view _path, const rapidjson::Value &_root) noexcept
{
    auto root = &_root;
    auto path = _path;
    size_t p;
    
    while( (p = path.find_first_of(".")) != std::string_view::npos ) {   
        const auto part_name = rapidjson::Value{ rapidjson::StringRef(path.data(), p) };
        const auto member_it = root->FindMember(part_name);
        if( member_it == root->MemberEnd() )
            return nullptr;
        
        root = &(*member_it).value;
        if( root->GetType() != rapidjson::kObjectType )
            return nullptr;
        
        path = p+1 < path.length() ? path.substr( p+1 ) : std::string_view{};
    }
    
    const auto leaf_name = rapidjson::Value{ rapidjson::StringRef(path.data(), path.length()) };
    const auto leaf_it = root->FindMember(leaf_name);
    if( leaf_it == root->MemberEnd() )
        return nullptr;
    
    return &(*leaf_it).value;
}

static std::pair<const rapidjson::Value *, std::string_view>
    FindParentNode(std::string_view _path, const rapidjson::Value &_root) noexcept
{
    auto root = &_root;
    auto path = _path;
    size_t p;
    
    while( (p = path.find_first_of(".")) != std::string_view::npos ) {   
        const auto part_name = rapidjson::Value{ rapidjson::StringRef(path.data(), p) };
        const auto member_it = root->FindMember(part_name);
        if( member_it == root->MemberEnd() )
            return {nullptr, ""};
        
        root = &(*member_it).value;
        if( root->GetType() != rapidjson::kObjectType )
            return {nullptr, ""};
        
        path = p+1 < path.length() ? path.substr( p+1 ) : std::string_view{};
    }    
    return {root, path};
}

static void TraverseRecursivelyAndMarkEachMember(const rapidjson::Value &_object,
                                                 const std::string &_path_prefix,
                                                 std::vector<std::string> &_changes_list)
{
    assert(_object.GetType() == rapidjson::kObjectType);
    
    for( auto i = _object.MemberBegin(), e = _object.MemberEnd(); i != e; ++i ) {        
        _changes_list.emplace_back( _path_prefix + i->name.GetString() );
        
        if( i->value.GetType() == rapidjson::Type::kObjectType ) {
            auto prefix = _path_prefix + i->name.GetString() + ".";
            TraverseRecursivelyAndMarkEachMember(i->value, prefix, _changes_list);
        }
    }
}    
    
static void MergeObjectsRecursively(rapidjson::Value &_target,
                                    rapidjson::Document::AllocatorType &_allocator,
                                    const rapidjson::Value &_main,
                                    const rapidjson::Value &_overwrites,
                                    const std::string &_path_prefix)
{
    assert(_target.GetType() == rapidjson::kObjectType);
    assert(_main.GetType() == rapidjson::kObjectType);
    assert(_overwrites.GetType() == rapidjson::kObjectType);
    
    for(auto main_it = _main.MemberBegin(), main_e = _main.MemberEnd();
        main_it != main_e;
        ++main_it ) {
        const auto &member_name = main_it->name;
        rapidjson::Value key( member_name, _allocator );
        
        auto overwrite_it = _overwrites.FindMember(member_name);
        if( overwrite_it == _overwrites.MemberEnd() ) {
            // this entry is absent in the 'overwrites' document
            // => just copy the value from the 'main' document and be done with it.
            rapidjson::Value value( main_it->value, _allocator );
            _target.AddMember(key, value, _allocator);            
        }
        else {
            // we have an overwrite for this member
            if( main_it->value.GetType() == overwrite_it->value.GetType() ) {
                // ... and the overwrite has the same type
                const auto common_type = main_it->value.GetType(); 
                if( common_type == rapidjson::kObjectType ) {
                    // .. which is an object => add an empty object and go into it recursively.
                    rapidjson::Value value( rapidjson::Type::kObjectType );
                    _target.AddMember( key, value, _allocator );
                    auto &added_member = _target[member_name];
                    
                    MergeObjectsRecursively(added_member,
                                            _allocator,
                                            main_it->value,
                                            overwrite_it->value,
                                            _path_prefix + member_name.GetString() + ".");
                }
                else {
                    // .. which is not an object => copy the value from the overwrite. 
                    rapidjson::Value value( overwrite_it->value, _allocator );
                    _target.AddMember( key, value, _allocator );                    
                }
            }
            else {
                // ... which has a diffent type => copy the value from the overwrite.
                rapidjson::Value value( overwrite_it->value, _allocator );
                _target.AddMember( key, value, _allocator );            
            }
        }
    }
    
    // now we iterate overwrites instead of the main document and everything which was
    // missed during the previous iteration, i.e. values which are absent in the original document.
    for(auto overwrites_it = _overwrites.MemberBegin(), overwrites_e = _overwrites.MemberEnd();
        overwrites_it != overwrites_e;
        ++overwrites_it ) {
        const auto &member_name = overwrites_it->name;
         
        if( _main.FindMember(member_name) != _main.MemberEnd() )
            continue;
            
        rapidjson::Value key( member_name, _allocator );        
        rapidjson::Value value( overwrites_it->value, _allocator );        
        _target.AddMember( key, value, _allocator );
    }        
}

static rapidjson::Document
    MergeDocuments( const rapidjson::Document &_main, const rapidjson::Document &_overwrites )
{
    assert(_main.GetType() == rapidjson::kObjectType);
    assert(_overwrites.GetType() == rapidjson::kObjectType);
        
    rapidjson::Document new_document( rapidjson::Type::kObjectType );

    MergeObjectsRecursively(new_document,
                            new_document.GetAllocator(),
                            _main,
                            _overwrites,
                            "");
    return new_document;
}

// _staging = _defaults + _overwrites =>
// _overwrites = _staging - _defaults
static void BuildOverwritesRecursive(const rapidjson::Value &_defaults,
                                     const rapidjson::Value &_staging,
                                     rapidjson::Value &_overwrites,
                                     rapidjson::Document::AllocatorType &_allocator)
{
    for( auto i = _staging.MemberBegin(), e = _staging.MemberEnd(); i != e; ++i ) {
        auto &staging_name = i->name;
        auto &staging_val = i->value;
     
        auto defaults_it = _defaults.FindMember(staging_name);
        if( defaults_it == _defaults.MemberEnd() ) {
            // no such item in defaults -> should be placed in overwrites
            rapidjson::Value key( staging_name, _allocator );
            rapidjson::Value val( staging_val, _allocator );
            _overwrites.AddMember( key, val, _allocator );
        }
        else {
            auto &defaults_val = defaults_it->value;
            if( defaults_val.GetType() == staging_val.GetType() &&
                defaults_val.GetType() == rapidjson::kObjectType ) {
                // adding an empty object.
                rapidjson::Value key( staging_name, _allocator );
                rapidjson::Value val( rapidjson::kObjectType );
                _overwrites.AddMember( key, val, _allocator );
                
                BuildOverwritesRecursive(defaults_val,
                                         staging_val,
                                         _overwrites[staging_name],
                                         _allocator);
            }
            else if( defaults_val != staging_val ) {
                rapidjson::Value key( staging_name, _allocator );
                rapidjson::Value val( staging_val, _allocator );
                _overwrites.AddMember( key, val, _allocator );
            }   
        }
    }
}

rapidjson::Document BuildOverwrites(const rapidjson::Document &_defaults,
                                    const rapidjson::Document &_staging)
{
    if( _defaults.GetType() != rapidjson::kObjectType ||
       _staging.GetType() != rapidjson::kObjectType )
        return rapidjson::Document{rapidjson::Type::kObjectType};
    
    auto overwrites = rapidjson::Document{rapidjson::Type::kObjectType};
    BuildOverwritesRecursive( _defaults, _staging, overwrites, overwrites.GetAllocator() );
    return overwrites;
}

static void ListDifferencesRecursively(const rapidjson::Value &_original,
                                       const rapidjson::Value &_new,
                                       const std::string &_path_prefix,
                                       std::vector<std::string> &_changes)
{
    assert(_original.GetType() == rapidjson::kObjectType);
    assert(_new.GetType() == rapidjson::kObjectType);
    
    for(auto original_it = _original.MemberBegin(), original_e = _original.MemberEnd();
        original_it != original_e;
        ++original_it ) {
        const auto &name = original_it->name;
        
        auto new_it = _new.FindMember(name);
        if( new_it == _new.MemberEnd() ) {
            _changes.emplace_back( _path_prefix + name.GetString() );
            
            if( original_it->value.GetType() == rapidjson::Type::kObjectType )
                TraverseRecursivelyAndMarkEachMember(original_it->value,
                                                     _path_prefix + name.GetString() + ".",
                                                     _changes);                
        }
        else {
            if( original_it->value.GetType() == new_it->value.GetType() ) {
                const auto common_type = original_it->value.GetType(); 
                if( common_type == rapidjson::kObjectType ) {
                    ListDifferencesRecursively(original_it->value,
                                               new_it->value,
                                               _path_prefix + name.GetString() + ".",
                                               _changes);
                }
                else {
                    if( original_it->value != new_it->value )
                        _changes.emplace_back( _path_prefix + name.GetString() );
                }
            }
            else {
                _changes.emplace_back( _path_prefix + name.GetString() );
                
                if( original_it->value.GetType() == rapidjson::Type::kObjectType )
                    TraverseRecursivelyAndMarkEachMember(original_it->value,
                                                         _path_prefix + name.GetString() + ".",
                                                         _changes);
                else if( new_it->value.GetType() == rapidjson::Type::kObjectType )
                    TraverseRecursivelyAndMarkEachMember(new_it->value,
                                                         _path_prefix + name.GetString() + ".",
                                                         _changes);
            }
        }
    }
    
    for(auto new_it = _new.MemberBegin(), new_e = _new.MemberEnd(); new_it != new_e; ++new_it ) {
        const auto &name = new_it->name;
         
        if( _original.FindMember(name) != _original.MemberEnd() )
            continue;
        
        _changes.emplace_back( _path_prefix + name.GetString() );
        if( new_it->value.GetType() == rapidjson::Type::kObjectType )
            TraverseRecursivelyAndMarkEachMember(new_it->value,
                                                 _path_prefix + name.GetString() + ".",
                                                 _changes);        
    }        
}    

static std::vector<std::string> ListDifferences(const rapidjson::Document &_original_document,
                                                const rapidjson::Document &_new_document)
{
    if( _original_document.GetType() != rapidjson::kObjectType ||
       _original_document.GetType() != rapidjson::kObjectType )
        return {};
    
    std::vector<std::string> diffs;
    ListDifferencesRecursively(_original_document, _new_document, "", diffs);
    return diffs;
}

static std::string Serialize(const rapidjson::Document &_document)
{
    rapidjson::StringBuffer buffer;
    rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
    _document.Accept(writer);
    return std::string(buffer.GetString());
}
    
}
