#include "Common.h"
#include "Config.h"

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

@end

