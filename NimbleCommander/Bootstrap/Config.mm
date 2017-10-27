// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Config.h"
#include <NimbleCommander/Core/rapidjson.h>

@implementation GenericConfigObjC
{
    GenericConfig *m_Config;
}

- (instancetype) initWithConfig:(GenericConfig*)_config
{
    assert( _config );
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

- (id)valueForKeyPath:(NSString *)keyPath
{
    return [GenericConfigObjC valueForKeyPath:keyPath.UTF8String inConfig:m_Config];
    
}

+ (id)valueForKeyPath:(const char*)keyPath inConfig:(GenericConfig*)_config;
{
    auto v = _config->Get( keyPath );
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
    [GenericConfigObjC setValue:value forKeyPath:keyPath inConfig:m_Config];
}

+ (void)setValue:(nullable id)value forKeyPath:(NSString *)keyPath inConfig:(GenericConfig*)_config
{
    if( auto n = objc_cast<NSNumber>(value) ) {
        auto type = n.objCType;
        if( !type || type[0] == 0 || type[1] != 0 )
            return;
        
        switch( type[0] ) {
            case 'c': // @encode(BOOL);
            case 'B': // @encode(bool)
                _config->Set( keyPath.UTF8String, (bool)n.boolValue );
                break;
            case 'i': // @encode(int);
                _config->Set( keyPath.UTF8String, n.intValue );
                break;
            case 's': // @encode(short);
                _config->Set( keyPath.UTF8String, (int)n.shortValue );
                break;
            case 'q': // @encode(long), @encode(long long)
                _config->Set( keyPath.UTF8String, (int)n.longValue );
                break;
            case 'I': // @encode(unsigned int)
                _config->Set( keyPath.UTF8String, n.unsignedIntValue );
                break;
            case 'S': // @encode(unsigned short)
                _config->Set( keyPath.UTF8String, (unsigned int)n.unsignedShortValue );
                break;
            case 'Q': // @encode(unsigned long), @encode(unsigned long long)
                _config->Set( keyPath.UTF8String, (unsigned int)n.unsignedLongValue );
                break;
            case 'd': // @encode(double)
                _config->Set( keyPath.UTF8String, n.doubleValue );
                break;
            case 'f': // @encode(float)
                _config->Set( keyPath.UTF8String, n.floatValue );
                break;
        }
    }
    else if( auto s = objc_cast<NSString>(value) )
        _config->Set( keyPath.UTF8String, s.UTF8String );
}

@end

