#include <fstream>
#include <Habanero/algo.h>
#include <Utility/FSEventsDirUpdate.h>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>
#include "Config.h"

static const int g_MaxNamePartLen = 128;
static const auto g_WriteDelay = 30s;
static const auto g_ReadDelay = 1s;

static string Load(const string &_filepath)
{
    ifstream in(_filepath, ios::in | ios::binary);
    if( in ) {
        string contents;
        in.seekg( 0, ios::end );
        contents.resize( in.tellg() );
        in.seekg( 0, ios::beg );
        in.read( &contents[0], contents.size() );
        in.close();
        return contents;
    }
    return "";
}

static time_t ModificationTime( const string &_filepath )
{
    struct stat st;
    if( stat( _filepath.c_str(), &st ) == 0 )
        return st.st_mtime;
    return 0;
}

rapidjson::CrtAllocator GenericConfig::g_CrtAllocator;

// _target += _overwrites
static void MergeObject( rapidjson::Value &_target, rapidjson::Document &_target_document, const rapidjson::Value &_overwrites )
{
    for( auto i = _overwrites.MemberBegin(), e = _overwrites.MemberEnd(); i != e; ++i ) {
        auto &over_name = i->name;
        auto &over_val = i->value;
  
        auto cur_it = _target.FindMember(over_name);
        if( cur_it ==  _target.MemberEnd() ) {
            // there's no such value in current config tree - just add it at once
            rapidjson::Value key( over_name, _target_document.GetAllocator() );
            rapidjson::Value val( over_val, _target_document.GetAllocator() );
            _target.AddMember( key, val, _target_document.GetAllocator() );
        }
        else {
            auto &cur_val = cur_it->value;
            if( cur_val.GetType() == over_val.GetType() ) {
                if( cur_val.GetType() == rapidjson::kObjectType ) {
                    MergeObject( cur_val, _target_document, over_val );
                }
                else if( cur_val != over_val ) {
                    // overwriting itself is here:
                    cur_val.CopyFrom( over_val, _target_document.GetAllocator() );
                }
            }
            else {
                cur_val.CopyFrom( over_val, _target_document.GetAllocator() );
            }
        }
    }
}

static void MergeDocument( rapidjson::Document &_target, const rapidjson::Document &_overwrites)
{
    if( _target.GetType() != rapidjson::kObjectType || _overwrites.GetType() != rapidjson::kObjectType )
        return;
    
    MergeObject(_target, _target, _overwrites);
}

// _staging = _defaults <- _overwrites;
static void BuildOverwritesRec(const rapidjson::Value &_defaults,
                               const rapidjson::Value &_staging,
                               rapidjson::Value &_overwrites,
                               rapidjson::Document &_overwrites_doc )
{
    for( auto i = _staging.MemberBegin(), e = _staging.MemberEnd(); i != e; ++i ) {
        auto &staging_name = i->name;
        auto &staging_val = i->value;
     
        auto defaults_it = _defaults.FindMember(staging_name);
        if( defaults_it == _defaults.MemberEnd() ) {
            // no such item in defaults -> should be placed in overwrites
            rapidjson::Value key( staging_name, _overwrites_doc.GetAllocator() );
            rapidjson::Value val( staging_val, _overwrites_doc.GetAllocator() );
            _overwrites.AddMember( key, val, _overwrites_doc.GetAllocator() );
        }
        else {
            auto &defaults_val = defaults_it->value;
            if( defaults_val.GetType() == staging_val.GetType() &&
                defaults_val.GetType() == rapidjson::kObjectType ) {
                // adding an empty object.
                rapidjson::Value key( staging_name, _overwrites_doc.GetAllocator() );
                rapidjson::Value val( rapidjson::kObjectType );
                _overwrites.AddMember( key, val, _overwrites_doc.GetAllocator() );
                
                BuildOverwritesRec(defaults_val,
                                   staging_val,
                                   _overwrites[staging_name],
                                   _overwrites_doc);
            }
            else if( defaults_val != staging_val ) {
                rapidjson::Value key( staging_name, _overwrites_doc.GetAllocator() );
                rapidjson::Value val( staging_val, _overwrites_doc.GetAllocator() );
                _overwrites.AddMember( key, val, _overwrites_doc.GetAllocator() );
            }
            
        }
    }
}

static void BuildOverwrites( const rapidjson::Document &_defaults, const rapidjson::Document &_staging, rapidjson::Document &_overwrites )
{
    if( _defaults.GetType() != rapidjson::kObjectType ||
       _staging.GetType() != rapidjson::kObjectType ||
       _overwrites.GetType() != rapidjson::kObjectType )
        return;

    BuildOverwritesRec( _defaults, _staging, _overwrites, _overwrites );
}

static vector<string> ListDifferencesPaths( const rapidjson::Document &_defaults, const rapidjson::Document &_staging )
{
    if( _defaults.GetType() != rapidjson::kObjectType ||
        _staging.GetType() != rapidjson::kObjectType )
        return {};
    
    vector<string> list;
    
    stack< tuple<const rapidjson::Value&, const rapidjson::Value&, string>  > st;
    st.emplace( _defaults, _staging, "" );
    
    while( !st.empty() ) {
        const rapidjson::Value &defaults = get<0>(st.top());
        const rapidjson::Value &staging  = get<1>(st.top());
        string                  prefix   = get<2>(st.top());
        st.pop();
        
        for( auto i = staging.MemberBegin(), e = staging.MemberEnd(); i != e; ++i ) {
            auto &staging_name = i->name;
            auto &staging_val = i->value;
            
            auto defaults_it = defaults.FindMember(staging_name);
            if( defaults_it == defaults.MemberEnd() ) // no such item in defaults
                list.emplace_back( prefix + staging_name.GetString() );
            else {
                auto &defaults_val = defaults_it->value;
                if( defaults_val.GetType() == staging_val.GetType() && defaults_val.GetType() == rapidjson::kObjectType )
                    st.emplace( defaults_val, staging_val, prefix + staging_name.GetString() + "." );
                else if( defaults_val != staging_val )
                    list.emplace_back( prefix + staging_name.GetString() );
            }
        }
    }
 
    return list;
}

GenericConfig::GenericConfig(const string &_defaults, const string &_overwrites):
    m_OverwritesPath(_overwrites),
    m_DefaultsPath(_defaults)
{
    if( !m_DefaultsPath.empty() ) {
        string def = Load(m_DefaultsPath);
        rapidjson::Document defaults;
        rapidjson::ParseResult ok = defaults.Parse<rapidjson::kParseCommentsFlag>( def.c_str() );
        
        if (!ok) {
            fprintf(stderr, "Can't load main config. JSON parse error: %s (%zu)", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
            exit(EXIT_FAILURE);
        }
        
        m_Defaults.CopyFrom(defaults, m_Defaults.GetAllocator());
        m_Current.CopyFrom(defaults, m_Current.GetAllocator());
    }
    else {
        m_Defaults = rapidjson::Document(rapidjson::kObjectType);
        m_Current = rapidjson::Document(rapidjson::kObjectType);
    }

    string over = Load(m_OverwritesPath);
    if( !over.empty() ) {
        rapidjson::Document overwrites;
        rapidjson::ParseResult ok = overwrites.Parse<rapidjson::kParseCommentsFlag>( over.c_str() );
        if ( !ok )
            fprintf(stderr, "Overwrites JSON parse error: %s (%zu)", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
        else {
            m_OverwritesTime = ModificationTime(m_OverwritesPath);
            MergeDocument(m_Current, overwrites);
        }
    }
    
    FSEventsDirUpdate::Instance().AddWatchPath(path(m_OverwritesPath).parent_path().c_str(), [=]{
        OnOverwritesFileDirChanged();
    });
}

void GenericConfig::ResetToDefaults()
{
    vector<string> diff;
    LOCK_GUARD(m_DocumentLock) {
        diff = ListDifferencesPaths( m_Defaults, m_Current );
        m_Current.CopyFrom( m_Defaults, m_Current.GetAllocator() );
    }

    MarkDirty();
    for( auto&p: diff )
        FireObservers( p );
}

GenericConfig::ConfigValue GenericConfig::Get(const string &_path) const
{
    return GetInternal( _path );
}

GenericConfig::ConfigValue GenericConfig::Get(const char *_path) const
{
    return GetInternal( _path );
}

GenericConfig::ConfigValue GenericConfig::GetDefault(const string &_path) const
{
    return GetInternalDefault( _path );
}

GenericConfig::ConfigValue GenericConfig::GetDefault(const char *_path) const
{
    return GetInternalDefault( _path );
}

optional<string> GenericConfig::GetString(const char *_path) const
{
    auto v = GetInternal(_path);
    if( v.GetType() == rapidjson::kStringType )
        return make_optional<string>(v.GetString());
    return nullopt;
}

bool GenericConfig::GetBool(const char *_path) const
{
    return GetBoolInternal( _path );
}

int GenericConfig::GetInt(const char *_path) const
{
    auto v = GetInternal(_path);
    if( v.GetType() == rapidjson::kNumberType ) {
        if( v.IsInt() )         return v.GetInt();
        else if( v.IsUint()  )  return (int)v.GetUint();
        else if( v.IsInt64() )  return (int)v.GetInt64();
        else if( v.IsUint64() ) return (int)v.GetUint64();
        else if( v.IsDouble() ) return (int)v.GetDouble();
    }
    return 0;
}

int GenericConfig::GetIntOr(const char *_path, int _default) const
{
    auto v = GetInternal(_path);
    if( v.GetType() == rapidjson::kNumberType ) {
        if( v.IsInt() )         return v.GetInt();
        else if( v.IsUint()  )  return (int)v.GetUint();
        else if( v.IsInt64() )  return (int)v.GetInt64();
        else if( v.IsUint64() ) return (int)v.GetUint64();
        else if( v.IsDouble() ) return (int)v.GetDouble();
    }
    return _default;
}

bool GenericConfig::Has(const char *_path) const
{
    lock_guard<spinlock> lock(m_DocumentLock);
    return FindUnlocked(_path) != nullptr;
}

static const rapidjson::Value *FindNode(string_view _path,
                                        const rapidjson::Value *_st)
{
    string_view path = _path;
    size_t p;
    
    while( (p = path.find_first_of(".")) != string_view::npos ) {
        char sub[g_MaxNamePartLen];
        copy( begin(path), begin(path) + p, begin(sub) );
        sub[p] = 0;
        
        auto submb = _st->FindMember(sub);
        if( submb == _st->MemberEnd() )
            return nullptr;
        
        _st = &(*submb).value;
        if( _st->GetType() != rapidjson::kObjectType )
            return nullptr;
        
        path = p+1 < path.length() ? path.substr( p+1 ) : string_view();
    }
    
    char sub[g_MaxNamePartLen];
    copy( begin(path), end(path), begin(sub) );
    sub[path.length()] = 0;
    
    auto it = _st->FindMember(sub);
    if( it == _st->MemberEnd() )
        return nullptr;
    
    return &(*it).value;
}

const rapidjson::Value *GenericConfig::FindUnlocked(string_view _path) const
{
    return FindNode(_path, &m_Current);
}

const rapidjson::Value *GenericConfig::FindDefaultUnlocked(string_view _path) const
{
    return FindNode(_path, &m_Defaults);
}

GenericConfig::ConfigValue GenericConfig::GetInternal( string_view _path ) const
{
    lock_guard<spinlock> lock(m_DocumentLock);
    auto v = FindUnlocked(_path);
    if( !v )
        return ConfigValue( rapidjson::kNullType );
    return ConfigValue( *v, g_CrtAllocator );
}

bool GenericConfig::GetBoolInternal(string_view _path) const
{
    lock_guard<spinlock> lock(m_DocumentLock);
    if( const auto v = FindUnlocked(_path) )
        return v->GetType() == rapidjson::kTrueType;
    return false;
}

GenericConfig::ConfigValue GenericConfig::GetInternalDefault(string_view _path) const
{
    // no need for locking, since m_Defaults is read-only
    auto v = FindDefaultUnlocked(_path);
    if( !v )
        return ConfigValue( rapidjson::kNullType );
    return ConfigValue( *v, g_CrtAllocator );
}

bool GenericConfig::Set(const char *_path, int _value)
{
    return SetInternal( _path, ConfigValue(_value) );
}

bool GenericConfig::Set(const char *_path, unsigned int _value)
{
    return SetInternal( _path, ConfigValue(_value) );
}

bool GenericConfig::Set(const char *_path, long long _value)
{
    return SetInternal( _path, ConfigValue(_value) );
}

bool GenericConfig::Set(const char *_path, unsigned long long _value)
{
    return SetInternal( _path, ConfigValue(_value) );
}

bool GenericConfig::Set(const char *_path, double _value)
{
    return SetInternal( _path, ConfigValue(_value) );
}

bool GenericConfig::Set(const char *_path, bool _value)
{
    return SetInternal( _path, ConfigValue(_value) );
}

bool GenericConfig::Set(const char *_path, const string &_value)
{
    return SetInternal( _path, ConfigValue(_value.c_str(), g_CrtAllocator) );
}

bool GenericConfig::Set(const char *_path, const char *_value)
{
    return SetInternal( _path, ConfigValue(_value, g_CrtAllocator) );
}

bool GenericConfig::Set(const char *_path, const ConfigValue &_value)
{
    return SetInternal( _path, _value );
}

bool GenericConfig::SetInternal(const char *_path, const ConfigValue &_value)
{
    {
        lock_guard<spinlock> lock(m_DocumentLock);
        
        rapidjson::Value *st = &m_Current;
        string_view path = _path;
        size_t p;
        
        while( (p = path.find_first_of(".")) != string_view::npos ) {
            char sub[g_MaxNamePartLen];
            copy( begin(path), begin(path) + p, begin(sub) );
            sub[p] = 0;
            
            auto submb = st->FindMember(sub);
            if( submb == st->MemberEnd() )
                return false;
            
            st = &(*submb).value;
            if( st->GetType() != rapidjson::kObjectType )
                return false;
            
            path = p+1 < path.length() ? path.substr( p+1 ) : string_view();
        }
        
        char sub[g_MaxNamePartLen];
        copy( begin(path), end(path), begin(sub) );
        sub[path.length()] = 0;
        
        auto it = st->FindMember(sub);
        if( it != st->MemberEnd() ) {
            if( it->value == _value )
                return true;
            
            it->value.CopyFrom( _value, m_Current.GetAllocator() );
        }
        else {
            rapidjson::Value key( sub, m_Current.GetAllocator() );
            rapidjson::Value value( _value, m_Current.GetAllocator() );
            st->AddMember( key, value, m_Current.GetAllocator() );
        }
    }

    FireObservers(_path);
    MarkDirty();
    
    return true;
}

GenericConfig::ObservationTicket::ObservationTicket(GenericConfig *_inst, unsigned long _ticket) noexcept:
    instance(_inst),
    ticket(_ticket)
{
}

GenericConfig::ObservationTicket::ObservationTicket(ObservationTicket &&_r) noexcept:
    instance(_r.instance),
    ticket(_r.ticket)
{
    _r.instance = nullptr;
    _r.ticket = 0;
}

GenericConfig::ObservationTicket::~ObservationTicket()
{
    if( *this )
        instance->StopObserving(ticket);
}

const GenericConfig::ObservationTicket &GenericConfig::ObservationTicket::operator=(GenericConfig::ObservationTicket &&_r)
{
    if( *this )
        instance->StopObserving(ticket);
    instance = _r.instance;
    ticket = _r.ticket;
    _r.instance = nullptr;
    _r.ticket = 0;
    return *this;
}

GenericConfig::ObservationTicket::operator bool() const noexcept
{
    return instance != nullptr && ticket != 0;
}

GenericConfig::ObservationTicket GenericConfig::Observe(const char *_path,
                                                        function<void()> _change_callback)
{
    if( !_change_callback )
        return ObservationTicket(nullptr, 0);
    
    string path = _path;
    auto t = m_ObservationTicket++;
    {
        Observer o;
        o.callback = move(_change_callback);
        o.ticket = t;
        
        LOCK_GUARD( m_ObserversLock ) {
            auto current_observers_it = m_Observers.find(path);
            
            if( current_observers_it != end(m_Observers)  ) {
                // somebody is already watching this path
                auto new_observers = make_shared<vector<shared_ptr<Observer>>>();
                new_observers->reserve( current_observers_it->second->size() + 1 );
                *new_observers = *(current_observers_it->second);
                new_observers->emplace_back( to_shared_ptr(move(o)) );
                current_observers_it->second = new_observers;
            }
            else {
                // it's the first request to observe this path
                auto new_observers = make_shared<vector<shared_ptr<Observer>>>
                    (1, to_shared_ptr(move(o)) );
                m_Observers.emplace( move(path), move(new_observers) );
            }
        }
    }
    
    return ObservationTicket(this, t);
}

void GenericConfig::StopObserving(unsigned long _ticket)
{
    if( !_ticket )
        return;
    
    lock_guard<spinlock> lock(m_ObserversLock);
    for( auto &path: m_Observers ) {
        auto &observers = path.second;
        for( size_t i = 0, e = observers->size(); i != e; ++i ) {
            auto &o = (*observers)[i];
            if( o->ticket == _ticket ) {
                auto new_observers = make_shared<vector<shared_ptr<Observer>>>();
                *new_observers = *observers;
                new_observers->erase( next(new_observers->begin(), i) );
                path.second = new_observers;
                return;
            }
        }
    }
}

shared_ptr<vector<shared_ptr<GenericConfig::Observer>>> GenericConfig::FindObserversLocked(const char *_path) const
{
    string path = _path;
    lock_guard<spinlock> lock(m_ObserversLock);
    auto observers_it = m_Observers.find(path);
    if( observers_it != end(m_Observers) )
        return  observers_it->second;
    return nullptr;
}

shared_ptr<vector<shared_ptr<GenericConfig::Observer>>> GenericConfig::FindObserversLocked(const string &_path) const
{
    lock_guard<spinlock> lock(m_ObserversLock);
    auto observers_it = m_Observers.find(_path);
    if( observers_it != end(m_Observers) )
        return  observers_it->second;
    return nullptr;
}

void GenericConfig::FireObservers(const char *_path) const
{
    if( auto observers = FindObserversLocked(_path) )
        for( auto &o: *observers )
            o->callback();
}

void GenericConfig::FireObservers(const string& _path) const
{
    if( auto observers = FindObserversLocked(_path) )
        for( auto &o: *observers )
            o->callback();
}

void GenericConfig::WriteOverwrites(const rapidjson::Document &_overwrites_diff, string _path)
{
    rapidjson::StringBuffer buffer;
    rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
    _overwrites_diff.Accept(writer);
    
    ofstream out(_path, ios::out | ios::binary);
    if( out )
        out << buffer.GetString();
}

void GenericConfig::RunOverwritesDumping()
{
    auto d = make_shared<rapidjson::Document>(rapidjson::kObjectType);
    
    {
        lock_guard<spinlock> lock(m_DocumentLock);
        BuildOverwrites(m_Defaults, m_Current, *d);
    }
    
    string path = m_OverwritesPath;
    m_IOQueue.Run([=]{
        WriteOverwrites(*d, path);
        m_OverwritesTime = ModificationTime(path);
    });
}

void GenericConfig::MarkDirty()
{
    if( !m_WriteScheduled.test_and_set() )
        dispatch_to_main_queue_after(g_WriteDelay, [=]{
            RunOverwritesDumping();
            m_WriteScheduled.clear();
        });
}

void GenericConfig::Commit()
{
    if( m_WriteScheduled.test_and_set() ) {
        RunOverwritesDumping();
        m_IOQueue.Wait();
    }
    m_WriteScheduled.clear();
}

void GenericConfig::OnOverwritesFileDirChanged()
{
    if( !m_ReadScheduled.test_and_set() )
        dispatch_to_main_queue_after(g_ReadDelay, [=]{
            string path = m_OverwritesPath;
            m_IOQueue.Run([=]{
                auto ov_tm = ModificationTime(path);
                if( ov_tm == m_OverwritesTime)
                    return;
                
                string over = Load(path);
                if( !over.empty() ) {
                    auto d = make_shared<rapidjson::Document>(rapidjson::kObjectType);
                    rapidjson::ParseResult ok = d->Parse<rapidjson::kParseCommentsFlag>( over.c_str() );
                    if (!ok)
                        fprintf(stderr, "Overwrites JSON parse error: %s (%zu)\n", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
                    else {
                        fprintf(stdout, "Loaded on-the-fly config overwrites: %s.\n", path.c_str());
                        m_OverwritesTime = ov_tm;
                        dispatch_to_main_queue([=]{
                            MergeChangedOverwrites(*d);
                        });
                    }
                }
            });
            m_ReadScheduled.clear();
        });
}

void GenericConfig::MergeChangedOverwrites(const rapidjson::Document &_new_overwrites_diff)
{
    if( _new_overwrites_diff.GetType() != rapidjson::kObjectType )
        return;
    
    rapidjson::Document new_staging_doc;
    new_staging_doc.CopyFrom(m_Defaults, m_Defaults.GetAllocator());
    MergeDocument(new_staging_doc, _new_overwrites_diff);
    
    vector<string> changes;
    {
        lock_guard<spinlock> lock(m_DocumentLock);
        stack< tuple<const rapidjson::Value*,const rapidjson::Value*, string> > travel;
        travel.emplace( make_tuple(&m_Current, &new_staging_doc, "") );
        
        while( !travel.empty() ) {
            auto current_staging = get<0>(travel.top());
            auto new_staging = get<1>(travel.top());
            string prefix = move(get<2>(travel.top()));
            travel.pop();
            
            for( auto i = new_staging->MemberBegin(), e = new_staging->MemberEnd(); i != e; ++i ) {
                auto &new_staging_name = i->name;
                auto &new_staging_val = i->value;
                
                auto current_staging_it = current_staging->FindMember( new_staging_name );
                if( current_staging_it != current_staging->MemberEnd() ) {
                    auto &current_staging_val = current_staging_it->value;
                    if( current_staging_val.GetType() == new_staging_val.GetType() ) {
                        if( current_staging_val.GetType() == rapidjson::kObjectType ) {
                            travel.emplace( make_tuple(&current_staging_val, &new_staging_val, prefix + new_staging_name.GetString() + ".") );
                            continue; // ok - go inside
                        }
                        else if( current_staging_val == new_staging_val )
                            continue; // ok - same value
                    }
                }
                changes.emplace_back( prefix + new_staging_name.GetString() ); // changed
            }
        }
        
        if( !changes.empty() )
            swap( m_Current, new_staging_doc );
    }
    
    for(auto &path: changes)
        FireObservers( path );
}
