//
//  CFString.cpp
//  Habanero
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#include <Habanero/CFString.h>

using namespace std;
using namespace std::experimental;

CFStringRef CFStringCreateWithUTF8StdString(const std::string &_s) noexcept
{
    return CFStringCreateWithBytes(0,
                                   (UInt8*)_s.data(),
                                   _s.length(),
                                   kCFStringEncodingUTF8,
                                   false);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(string_view _s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.data(),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.c_str(),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         strlen(_s),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         _len,
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.c_str(),
                                         _s.length(),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
    
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         strlen(_s),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         _len,
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

string CFStringGetUTF8StdString(CFStringRef _str)
{
    if( const char *cstr = CFStringGetCStringPtr(_str, kCFStringEncodingUTF8) )
        return string(cstr);
    
    CFIndex length = CFStringGetLength(_str);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    auto buffer = make_unique<char[]>(maxSize);
    if( CFStringGetCString(_str, &buffer[0], maxSize, kCFStringEncodingUTF8) )
        return string(buffer.get());
    
    return "";
}

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
    if( p )
        CFRelease(p);
    p = _rhs.p;
    _rhs.p = nullptr;
    return *this;
}
