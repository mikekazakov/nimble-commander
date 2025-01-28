// Copyright (C) 2015-2025 Michael G. Kazakov. Subject to GNU General Public License version 3.
#include <Base/CFString.h>
#include <Base/StackAllocator.h>

#include <memory>
#include <vector>

namespace nc::base {

CFStringRef CFStringCreateWithUTF8StdString(const std::string &_s) noexcept
{
    return CFStringCreateWithBytes(
        nullptr, reinterpret_cast<const UInt8 *>(_s.data()), _s.length(), kCFStringEncodingUTF8, false);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(std::string_view _s) noexcept
{
    return CFStringCreateWithBytesNoCopy(nullptr,
                                         reinterpret_cast<const UInt8 *>(_s.data()),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const std::string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(nullptr,
                                         reinterpret_cast<const UInt8 *>(_s.data()),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(
        nullptr, reinterpret_cast<const UInt8 *>(_s), std::strlen(_s), kCFStringEncodingUTF8, false, kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(
        nullptr, reinterpret_cast<const UInt8 *>(_s), _len, kCFStringEncodingUTF8, false, kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const std::string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(nullptr,
                                         reinterpret_cast<const UInt8 *>(_s.data()),
                                         _s.length(),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(
        nullptr, reinterpret_cast<const UInt8 *>(_s), strlen(_s), kCFStringEncodingMacRoman, false, kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(
        nullptr, reinterpret_cast<const UInt8 *>(_s), _len, kCFStringEncodingMacRoman, false, kCFAllocatorNull);
}

std::string CFStringGetUTF8StdString(CFStringRef _str)
{
    if( const char *cstr = CFStringGetCStringPtr(_str, kCFStringEncodingUTF8) )
        return {cstr};

    const CFIndex length = CFStringGetLength(_str);
    const CFIndex max_size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;

    StackAllocator alloc;
    std::pmr::vector<char> buffer(max_size, &alloc);

    if( CFStringGetCString(_str, buffer.data(), max_size, kCFStringEncodingUTF8) )
        return {buffer.data()};

    return {};
}

CFString::CFString(std::string_view _str, CFStringEncoding _encoding) noexcept
    : p(nc::base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytes(nullptr,
                                                                    reinterpret_cast<const UInt8 *>(_str.data()),
                                                                    _str.length(),
                                                                    _encoding,
                                                                    false)))
{
}

CFString::CFString(const char *_str, CFStringEncoding _encoding) noexcept
{
    if( _str )
        p = nc::base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytes(
            nullptr, reinterpret_cast<const UInt8 *>(_str), std::strlen(_str), _encoding, false));
}

} // namespace nc::base
