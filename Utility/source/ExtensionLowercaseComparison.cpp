// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <experimental/string_view>
#include <sys/param.h>
#include <Habanero/CFStackAllocator.h>
#include "../include/Utility/ExtensionLowercaseComparison.h"

using namespace std;
using namespace std::experimental;

ExtensionLowercaseComparison& ExtensionLowercaseComparison::Instance() noexcept
{
    static auto inst = new ExtensionLowercaseComparison;
    return *inst;
}

static string ProduceFormCLowercase(string_view _string)
{
    CFStackAllocator allocator;

    CFStringRef original = CFStringCreateWithBytesNoCopy(allocator.Alloc(),
                                                         (UInt8*)_string.data(),
                                                         _string.length(),
                                                         kCFStringEncodingUTF8,
                                                         false,
                                                         kCFAllocatorNull);
    
    if( !original )
        return "";
    
    CFMutableStringRef mutable_string = CFStringCreateMutableCopy(allocator.Alloc(), 0, original);
    CFRelease(original);
    if( !mutable_string )
        return "";
    
    CFStringLowercase(mutable_string, nullptr);
    CFStringNormalize(mutable_string, kCFStringNormalizationFormC);

    char utf8[MAXPATHLEN];
    long used = 0;
    CFStringGetBytes(mutable_string,
                     CFRangeMake(0, CFStringGetLength(mutable_string)),
                     kCFStringEncodingUTF8,
                     0,
                     false,
                     (UInt8*)utf8,
                     MAXPATHLEN-1,
                     &used);
    utf8[used] = 0;
    
    CFRelease(mutable_string);
    return utf8;
}

string ExtensionLowercaseComparison::ExtensionToLowercase(const string &_extension)
{
    if( _extension.length() > m_MaxLength )
        // we don't cache long extensions
        return ProduceFormCLowercase(_extension);
    
    lock_guard<spinlock> lock(m_Lock);
    auto it = m_Data.find( _extension );
    if( it != end(m_Data) )
        return it->second;
    
    auto cl = ProduceFormCLowercase(_extension);
    m_Data.emplace( _extension, cl );
    return cl;    
}

string ExtensionLowercaseComparison::ExtensionToLowercase(const char *_extension)
{
    if( strlen(_extension) > m_MaxLength )
        // we don't cache long extensions
        return ProduceFormCLowercase(_extension);
    
    lock_guard<spinlock> lock(m_Lock);
    auto it = m_Data.find( _extension );
    if( it != end(m_Data) )
        return it->second;
    
    auto cl = ProduceFormCLowercase(_extension);
    m_Data.emplace( _extension, cl );
    return cl;
}

bool ExtensionLowercaseComparison::Equal( const string &_filename_ext, const string &_compare_to_formc_lc )
{
    lock_guard<spinlock> lock(m_Lock);
    auto it = m_Data.find( _filename_ext );
    if( it != end(m_Data) )
        return it->second == _compare_to_formc_lc;
    
    auto cl = ProduceFormCLowercase(_filename_ext);
    if( _filename_ext.length() <= m_MaxLength )
        m_Data.emplace( _filename_ext, cl );
    return cl == _compare_to_formc_lc;
}

bool ExtensionLowercaseComparison::Equal( const char *_filename_ext, const string &_compare_to_formc_lc )
{
    lock_guard<spinlock> lock(m_Lock);
    auto it = m_Data.find( _filename_ext );
    if( it != end(m_Data) )
        return it->second == _compare_to_formc_lc;
    
    auto cl = ProduceFormCLowercase(_filename_ext);
    if( strlen(_filename_ext) <= m_MaxLength )
        m_Data.emplace( _filename_ext, cl );
    return cl == _compare_to_formc_lc;
}
