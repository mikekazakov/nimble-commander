#include <fstream>
#include <Habanero/algo.h>
#include "3rd_party/rapidjson/include/rapidjson/error/en.h"
#include "3rd_party/rapidjson/include/rapidjson/memorystream.h"
#include "3rd_party/rapidjson/include/rapidjson/stringbuffer.h"
#include "3rd_party/rapidjson/include/rapidjson/prettywriter.h"
#include "Common.h"
#include "Config.h"

static const int g_MaxNamePartLen = 128;

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

rapidjson::CrtAllocator GenericConfig::g_CrtAllocator;

static void MergeObject( rapidjson::Value &_target, rapidjson::Document &_target_document, const rapidjson::Value &_overwrites )
{
    for( auto i = _overwrites.MemberBegin(), e = _overwrites.MemberEnd(); i != e; ++i ) {
        auto &over_name = i->name;
        auto &over_val = i->value;
  
        auto cur_it = _target.FindMember(over_name);
        if( cur_it ==  _target.MemberEnd() ) { // there's no such value in current config tree - just add it at once
            rapidjson::Value key( over_name, _target_document.GetAllocator() );
            rapidjson::Value val( over_val, _target_document.GetAllocator() );
            _target.AddMember( key, val, _target_document.GetAllocator() );
        }
        else {
            auto &cur_val = cur_it->value;
            if( cur_val.GetType() == over_val.GetType() ) {
                if( cur_val.GetType() == rapidjson::kObjectType ) {
                    MergeObject( cur_val, _target_document, over_val);
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

static void MergeDocument( rapidjson::Document &_target, const rapidjson::Document &_overwrites )
{
    if( _target.GetType() != rapidjson::kObjectType || _overwrites.GetType() != rapidjson::kObjectType )
        return;
    
    MergeObject(_target, _target, _overwrites);
}

// _staging = _defaults <- _overwrites;

static void BuildOverwritesRec( const rapidjson::Value &_defaults, const rapidjson::Value &_staging, rapidjson::Value &_overwrites, rapidjson::Document &_overwrites_doc )
{
    for( auto i = _staging.MemberBegin(), e = _staging.MemberEnd(); i != e; ++i ) {
        auto &staging_name = i->name;
        auto &staging_val = i->value;
     
        auto defaults_it = _defaults.FindMember(staging_name);
        if( defaults_it == _defaults.MemberEnd() ) { // no such item in defaults -> should be placed in overwrites
            rapidjson::Value key( staging_name, _overwrites_doc.GetAllocator() );
            rapidjson::Value val( staging_val, _overwrites_doc.GetAllocator() );
            _overwrites.AddMember( key, val, _overwrites_doc.GetAllocator() );
        }
        else {
            auto &defaults_val = defaults_it->value;
            if( defaults_val.GetType() == staging_val.GetType() && defaults_val.GetType() == rapidjson::kObjectType ) {
                // adding an empty object.
                rapidjson::Value key( staging_name, _overwrites_doc.GetAllocator() );
                rapidjson::Value val( rapidjson::kObjectType );
                _overwrites.AddMember( key, val, _overwrites_doc.GetAllocator() );
                
                
                BuildOverwritesRec(defaults_val, staging_val, _overwrites[staging_name], _overwrites_doc);
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

GenericConfig::GenericConfig(const string &_defaults, const string &_overwrites):
    m_OverwritesPath(_overwrites),
    m_DefaultsPath(_defaults)
{
    string def = Load(m_DefaultsPath);
    rapidjson::Document defaults;
    rapidjson::ParseResult ok = defaults.Parse<rapidjson::kParseCommentsFlag>( def.c_str() );

    if (!ok) {
        fprintf(stderr, "Can't load main config. JSON parse error: %s (%zu)", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
        exit(EXIT_FAILURE);
    }
    
    m_Defaults.CopyFrom(defaults, m_Defaults.GetAllocator());
    m_Current.CopyFrom(defaults, m_Defaults.GetAllocator());

    string over = Load(m_OverwritesPath);
    if( !over.empty() ) {
        rapidjson::Document overwrites;
        ok = overwrites.Parse<rapidjson::kParseCommentsFlag>( over.c_str() );
        if (!ok)
            fprintf(stderr, "Overwrites JSON parse error: %s (%zu)", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
        else
            MergeDocument(m_Current, overwrites);
    }
    
    m_Bridge = [[GenericConfigObjC alloc] initWithConfig:this];
}

GenericConfig::ConfigValue GenericConfig::Get(const string &_path) const
{
    return GetInternal( _path );
}

GenericConfig::ConfigValue GenericConfig::Get(const char *_path) const
{
    return GetInternal( _path );
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
    auto v = GetInternal(_path);
    if( v.GetType() == rapidjson::kTrueType )
        return true;
    return false;
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

GenericConfig::ConfigValue GenericConfig::GetInternal( string_view _path ) const
{
    lock_guard<mutex> lock(m_DocumentLock);
    
    const rapidjson::Value *st = &m_Current;
    string_view path = _path;
    size_t p;
    
    while( (p = path.find_first_of(".")) != string_view::npos ) {
        char sub[g_MaxNamePartLen];
        copy( begin(path), begin(path) + p, begin(sub) );
        sub[p] = 0;

        auto submb = st->FindMember(sub);
        if( submb == st->MemberEnd() )
            return ConfigValue( rapidjson::kNullType );
        
        st = &(*submb).value;
        if( st->GetType() != rapidjson::kObjectType )
            return ConfigValue( rapidjson::kNullType );
        
        path = p+1 < path.length() ? path.substr( p+1 ) : string_view();
    }

    char sub[g_MaxNamePartLen];
    copy( begin(path), end(path), begin(sub) );
    sub[path.length()] = 0;
    
    auto it = st->FindMember(sub);
    if( it == st->MemberEnd() )
        return ConfigValue( rapidjson::kNullType );
    
    return ConfigValue( (*it).value, g_CrtAllocator );
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

bool GenericConfig::SetInternal(const char *_path, const ConfigValue &_value)
{
    {
        lock_guard<mutex> lock(m_DocumentLock);
        
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
    DumpOverwrites();
    
    return true;
}

void GenericConfig::DumpOverwrites()
{
    lock_guard<mutex> lock(m_DocumentLock);
    
    MachTimeBenchmark mtb;
    
    rapidjson::Document d(rapidjson::kObjectType);
    BuildOverwrites(m_Defaults, m_Current, d);
    mtb.ResetMicro("built overwrites tree in us: ");

    // this should be async:
    rapidjson::StringBuffer buffer;
    rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
    d.Accept(writer);
    mtb.ResetMicro("composed overwrites json in us: ");
    
//    cout << buffer.GetString() << endl;
    
    ofstream out(m_OverwritesPath, ios::out | ios::binary);
    if( out )
        out << buffer.GetString();
    mtb.ResetMicro("wrote json file in us: ");
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

GenericConfig::ObservationTicket GenericConfig::Observe(const char *_path, function<void()> _change_callback)
{
    if( !_change_callback )
        return ObservationTicket(nullptr, 0);
    
    string path = _path;
    auto t = m_ObservationTicket++;
    {
        Observer o;
        o.callback = move(_change_callback);
        o.ticket = t;
        
        lock_guard<mutex> lock(m_ObserversLock);
        
        auto current_observers_it = m_Observers.find(path);
        
        auto new_observers = make_shared<vector<shared_ptr<Observer>>>();
        if( current_observers_it != end(m_Observers)  ) {
            new_observers->reserve( current_observers_it->second->size() + 1 );
            *new_observers = *(current_observers_it->second);
        }
        new_observers->emplace_back( to_shared_ptr(move(o)) );
        
        m_Observers[path] = move(new_observers);
    }
    
    return ObservationTicket(this, t);
}

void GenericConfig::StopObserving(unsigned long _ticket)
{
    if( !_ticket )
        return;
    
    lock_guard<mutex> lock(m_ObserversLock);
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

shared_ptr<vector<shared_ptr<GenericConfig::Observer>>> GenericConfig::FindObserversLocked(const char *_path)
{
    string path = _path;
    lock_guard<mutex> lock(m_ObserversLock);
    auto observers_it = m_Observers.find(path);
    if( observers_it != end(m_Observers) )
        return  observers_it->second;
    return nullptr;
}

void GenericConfig::FireObservers(const char *_path)
{
    if( auto observers = FindObserversLocked(_path) )
        for( auto &o: *observers )
            o->callback();
}

@implementation GenericConfigObjC
{
    GenericConfig *m_Config;
}

- (instancetype) initWithConfig:(GenericConfig*)_config
{
    self = [super init];
    if( self ) {
        m_Config = _config;
    }
    return self;
}

- (nullable id)valueForKey:(NSString *)key
{
    return nil;
}

- (nullable id)valueForKeyPath:(NSString *)keyPath
{    
    auto v = m_Config->Get( keyPath.UTF8String );
    switch( v.GetType() ) {
        case rapidjson::kTrueType:      return [NSNumber numberWithBool:true];
        case rapidjson::kFalseType:     return [NSNumber numberWithBool:false];
        case rapidjson::kStringType:    return [NSString stringWithUTF8String:v.GetString()];
        case rapidjson::kNumberType:
            if( v.IsInt() )             return [NSNumber numberWithInt:v.GetInt()];
            else if( v.IsUint()  )      return [NSNumber numberWithUnsignedInt:v.GetUint()];
            else if( v.IsInt64() )      return [NSNumber numberWithLongLong:v.GetInt64()];
            else if( v.IsUint64() )     return [NSNumber numberWithUnsignedLongLong:v.GetUint64()];
            else if( v.IsDouble() )     return [NSNumber numberWithDouble:v.GetDouble()];
            else                        return nil; // future guard
        default: break;
    }
    
    return nil;
}

//c A char
//i An int
//s A short
//l A long
//l is treated as a 32-bit quantity on 64-bit programs.
//q A long long
//C An unsigned char
//I An unsigned int
//S An unsigned short
//L An unsigned long
//Q An unsigned long long
//f A float
//d A double
//B A C++ bool or a C99 _Bool
//v A void
//* A character string (char *)
//@ An object (whether statically typed or typed id)
//# A class object (Class)
//: A method selector (SEL)

- (void)setValue:(nullable id)value forKeyPath:(NSString *)keyPath
{
    if( auto n = objc_cast<NSNumber>(value) ) {
        auto type = n.objCType;
        if( strcmp(type, @encode(BOOL)) == 0 )
            m_Config->Set( keyPath.UTF8String, (bool)n.boolValue );
        else if( strcmp(type, @encode(int)) == 0 )
            m_Config->Set( keyPath.UTF8String, n.intValue );
        else if( strcmp(type, @encode(short)) == 0 )
            m_Config->Set( keyPath.UTF8String, (int)n.shortValue );
        else if( strcmp(type, @encode(long)) == 0 )
            m_Config->Set( keyPath.UTF8String, (int)n.longValue );
        else if( strcmp(type, @encode(long long)) == 0 )
            m_Config->Set( keyPath.UTF8String, n.longLongValue );
        else if( strcmp(type, @encode(unsigned int)) == 0 )
            m_Config->Set( keyPath.UTF8String, n.unsignedIntValue );
        else if( strcmp(type, @encode(unsigned short)) == 0 )
            m_Config->Set( keyPath.UTF8String, (unsigned int)n.unsignedShortValue );
        else if( strcmp(type, @encode(unsigned long)) == 0 )
            m_Config->Set( keyPath.UTF8String, (unsigned int)n.unsignedLongValue );
        else if( strcmp(type, @encode(unsigned long long)) == 0 )
            m_Config->Set( keyPath.UTF8String, n.unsignedLongLongValue );
        else if( strcmp(type, @encode(double)) == 0 )
            m_Config->Set( keyPath.UTF8String, n.doubleValue );
        else if( strcmp(type, @encode(float)) == 0 )
            m_Config->Set( keyPath.UTF8String, n.floatValue );
    }
    else if( auto s = objc_cast<NSString>(value) )
        m_Config->Set( keyPath.UTF8String, s.UTF8String );
}

//- (void) addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
//{
//
//    int a = 10;
////    NSNotificationCenter
////    struct GenericConfigObjCObserver
////    {
////        __weak NSObject            *observer;
////        NSKeyValueObservingOptions  options;
////        void                       *context;
////    };
////    GenericConfigObjCObserver o;
////    o.observer = observer;
////    o.options = options;
////    o.context = context;
////    m_Observers[keyPath.UTF8String].emplace_back(o);
//}
//
//- (void) willChangeValueForKey:(NSString *)key
//{
//    
//    
//}
//
//- (void) didChangeValueForKey:(NSString *)key
//{
//    auto it = m_Observers.find(key.UTF8String);
//    if( it != m_Observers.end() )
//        for( auto &i: it->second)
//            if( NSObject *object = i.observer ) {
//                [object observeValueForKeyPath:key ofObject:self change:nil context:i.context];
//            
//        
//            }
//}
//
//- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context
//{
//    
//    
//}
//
//- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
//{
//    
//    
//}


//- (void)observeValueForKeyPath:(nullable NSString *)keyPath
//ofObject:(nullable id)object
//change:(nullable NSDictionary<NSString*, id> *)change
//context:(nullable void *)context;

@end

