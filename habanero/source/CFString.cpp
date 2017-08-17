/* Copyright (c) 2015-2016 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
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
