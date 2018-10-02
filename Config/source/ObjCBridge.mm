// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ObjCBridge.h"
#include "RapidJSON.h"
#include <Utility/ObjCpp.h>

using nc::config::Config;

@implementation NCConfigObjCBridge
{
    Config *m_Config;
}

- (instancetype) initWithConfig:(Config&)_config
{
    self = [super init];
    if( self ) {
        m_Config = &_config;
    }
    return self;    
}

- (nullable id)valueForKey:(NSString *)key
{
    return nil;
}

- (id)valueForKeyPath:(NSString *)_key_path
{
    const auto raw_path_string = _key_path.UTF8String;
    if( raw_path_string == nullptr )
        return nil;
    return [NCConfigObjCBridge valueForKeyPath:raw_path_string inConfig:*m_Config];
}

- (void)setValue:(nullable id)value forKeyPath:(NSString *)_key_path
{
    const auto raw_path_string = _key_path.UTF8String;
    if( raw_path_string == nullptr )
        return;
    [NCConfigObjCBridge setValue:value forKeyPath:raw_path_string inConfig:*m_Config];
}

+ (id)valueForKeyPath:(std::string_view)key_path inConfig:(Config&)_config
{
    auto v = _config.Get( key_path );
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

/*
 Objective-C types:
 c A char
 i An int
 s A short
 l A long
 l is treated as a 32-bit quantity on 64-bit programs.
 q A long long
 C An unsigned char
 I An unsigned int
 S An unsigned short
 L An unsigned long
 Q An unsigned long long
 f A float
 d A double
 B A C++ bool or a C99 _Bool
 v A void
 * A character string (char *)
 @ An object (whether statically typed or typed id)
 # A class object (Class)
 : A method selector (SEL)
 */
+ (void)setValue:(nullable id)value forKeyPath:(std::string_view)_key_path inConfig:(Config&)_config
{    
    if( const auto n = objc_cast<NSNumber>(value) ) {        
        const auto type = n.objCType;
        if( !type || type[0] == 0 || type[1] != 0 )
            return;
        
        switch( type[0] ) {
            case 'c': // @encode(BOOL)
            case 'B': // @encode(bool)
                _config.Set( _key_path, (bool)n.boolValue );
                break;
            case 'i': // @encode(int)
                _config.Set( _key_path, n.intValue );
                break;
            case 's': // @encode(short)
                _config.Set( _key_path, (int)n.shortValue );
                break;
            case 'q': // @encode(long), @encode(long long)
                _config.Set( _key_path, n.longValue );
                break;
            case 'I': // @encode(unsigned int)
                _config.Set( _key_path, n.unsignedIntValue );
                break;
            case 'S': // @encode(unsigned short)
                _config.Set( _key_path, (unsigned int)n.unsignedShortValue );
                break;
            case 'Q': // @encode(unsigned long), @encode(unsigned long long)
                _config.Set( _key_path, n.unsignedLongValue );
                break;
            case 'd': // @encode(double)
                _config.Set( _key_path, n.doubleValue );
                break;
            case 'f': // @encode(float)
                _config.Set( _key_path, n.floatValue );
                break;
        }
    }
    else if( const auto s = objc_cast<NSString>(value) ) {
        const auto string = s.UTF8String;
        if( string == nullptr )
            return;
        
        _config.Set( _key_path, string );
    }
}

@end
