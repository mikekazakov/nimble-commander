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
    GenericConfig(const string &_defaults, const string &_overwrites);
    
    typedef rapidjson::GenericValue<rapidjson::UTF8<>, rapidjson::CrtAllocator> ConfigValue;
    
    ConfigValue Get(const string &_path) const;
    ConfigValue Get(const char *_path) const;
    
    bool Set(const char *_path, int _value);
    bool Set(const char *_path, bool _value);
    bool Set(const char *_path, const string &_value);
    bool Set(const char *_path, const char *_value);
    
//    bool 	IsInt () const
//    bool 	IsUint () const
//    bool 	IsInt64 () const
//    bool 	IsUint64 () const
//    bool 	IsDouble () const

#ifdef __OBJC__
    inline GenericConfigObjC    *Bridge() const { return m_Bridge; }
#endif
    
    
private:
    ConfigValue GetInternal(string_view _path) const;
    bool SetInternal(const char *_path, const ConfigValue &_value);
    
    void DumpOverwrites();
    
    string                  m_DefaultsPath;
    string                  m_OverwritesPath;
    

    rapidjson::Document     m_Current;
    rapidjson::Document     m_Defaults;
    mutable mutex           m_Lock;
#ifdef __OBJC__
    GenericConfigObjC      *m_Bridge;
#endif
};

