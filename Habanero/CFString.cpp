//
//  CFString.cpp
//  Habanero
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#include "CFString.h"

CFString::CFString():
    p(nullptr)
{
}

CFString::CFString(const std::string &_str):
    p(CFStringCreateWithBytes(0,
                            (UInt8*)_str.c_str(),
                              _str.length(),
                              kCFStringEncodingUTF8,
                              false))
{
}

CFString::CFString(const std::string &_str, CFStringEncoding _encoding):
    p( CFStringCreateWithBytes(0,
                               (UInt8*)_str.c_str(),
                               _str.length(),
                               _encoding,
                               false) )
{
}

CFString::CFString(const char *_str):
    p( _str ? CFStringCreateWithBytes(0,
                                      (UInt8*)_str,
                                      strlen(_str),
                                      kCFStringEncodingUTF8,
                                      false) :
              nullptr)
{
}

CFString::CFString(const CFString &_rhs):
    p( _rhs.p )
{
    if( p )
        CFRetain(p);
}

CFString::CFString(CFString &&_rhs):
    p( _rhs.p )
{
    _rhs.p = nullptr;
}

CFString::~CFString()
{
    if(p)
        CFRelease(p);
}

const CFString &CFString::operator=(const CFString &_rhs) noexcept
{
    if( p )
        CFRelease(p);
    p = _rhs.p;
    if( p )
        CFRetain(p);
    
    return *this;
}

const CFString &CFString::operator=(CFString &&_rhs) noexcept
{
    p = _rhs.p;
    _rhs.p = nullptr;
    return *this;
}
