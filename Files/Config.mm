#include <fstream>
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

static rapidjson::CrtAllocator g_CrtAllocator;


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

    if (!ok)
        fprintf(stderr, "JSON parse error: %s (%zu)", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
    
//    bool b = d.HasMember("int_value");
//    int bb = d["int_value"].GetInt();
//    int bbb = d["something"]["inside_something"].GetInt();
    
    
//    Document doc;
//    ParseResult ok = doc.Parse("[42]");
//    if (!ok) {
//        fprintf(stderr, "JSON parse error: %s (%u)",
//                GetParseError_En(ok.Code()), ok.Offset());
//        exit(EXIT_FAILURE);
//    }
    
    
//    m_Current = d;
    m_Defaults.CopyFrom(defaults, m_Defaults.GetAllocator());
    m_Current.CopyFrom(defaults, m_Defaults.GetAllocator());


    string over = Load(m_OverwritesPath);
    rapidjson::Document overwrites;
    ok = overwrites.Parse<rapidjson::kParseCommentsFlag>( over.c_str() );
    if (!ok)
        fprintf(stderr, "JSON parse error: %s (%zu)", rapidjson::GetParseError_En(ok.Code()), ok.Offset());
    
    MergeDocument(m_Current, overwrites);
    
    auto aa1 = Get("something.inside_something").GetInt();
    Set("something.inside_something", 150);
    auto aa2 = Get("something.inside_something").GetInt();
    
//    Get("something..inside_something");
//    Get("something..");
//    Get("something.");
//    Get("something..inside_something.");
    
    int a = 10;
    a = 11;
    
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

GenericConfig::ConfigValue GenericConfig::GetInternal( string_view _path ) const
{
    lock_guard<mutex> lock(m_Lock);
    
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
    lock_guard<mutex> lock(m_Lock);
    
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
        
        
//        [m_Bridge willChangeValueForKey:[NSString stringWithUTF8String:_path]];
        
        it->value.CopyFrom( _value, m_Current.GetAllocator() );
        
        DumpOverwrites();
        
//        [m_Bridge didChangeValueForKey:[NSString stringWithUTF8String:_path]];
        
        
        // NOTIFY ABOUT ACTUAL CHANGE
    }
    else {
        rapidjson::Value key( sub, m_Current.GetAllocator() );
        rapidjson::Value value( _value, m_Current.GetAllocator() );
        st->AddMember( key, value, m_Current.GetAllocator() );
        // NOTIFY ABOUT ACTUAL CHANGE
    }
    
//            [self didChangeValueForKey:@"DialogsCount"];
    
    return true;
}

void GenericConfig::DumpOverwrites()
{
    rapidjson::Document d(rapidjson::kObjectType);
  
    BuildOverwrites(m_Defaults, m_Current, d);
    
    rapidjson::StringBuffer buffer;
    rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
    d.Accept(writer);
    cout << buffer.GetString() << endl;
    
//static void BuildOverwrites( const rapidjson::Document &_defaults, const rapidjson::Document &_staging, rapidjson::Document &_overwrites )
    
}

//static int a = []{
//    GenericConfig gc("/Users/migun/test_defaults.cfg", "/Users/migun/test_overwrites.cfg");
//    
//    
//    
//    
//    return 0;
//}();

//struct GenericConfigObjCObserver
//{
//    __weak NSObject            *observer;
//    NSKeyValueObservingOptions  options;
//    void                       *context;
//};

@implementation GenericConfigObjC
{
    GenericConfig                                               *m_Config;
//    unordered_map<string, vector<GenericConfigObjCObserver>>     m_Observers;
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
        case rapidjson::kNumberType:    return [NSNumber numberWithInt:v.GetInt()];
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
    if( value ) {
        if( auto n = objc_cast<NSNumber>(value) ) {
            auto type = n.objCType;
            if( strcmp(type, @encode(BOOL)) == 0 ) {
                m_Config->Set( keyPath.UTF8String, (bool)n.boolValue );
                
//                int a = 19;
                
            }
            
//            CFNumberType
            
//            NSNumber * n = [NSNumber numberWithBool:YES];
//            if (strcmp([n objCType], @encode(BOOL)) == 0) {
//                NSLog(@"this is a bool");
//            } else if (strcmp([n objCType], @encode(int)) == 0) {
//                NSLog(@"this is an int");
//            }
            
            
//            m_Config->Set(keyPath.UTF8String, n.intValue);
            
            
        }
        
        
    }
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

