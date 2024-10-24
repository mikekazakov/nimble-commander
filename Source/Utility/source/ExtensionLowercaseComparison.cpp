// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ExtensionLowercaseComparison.h>
#include <Base/CFStackAllocator.h>
#include <Base/algo.h>
#include <string_view>
#include <ranges>

namespace nc::utility {

ExtensionLowercaseComparison &ExtensionLowercaseComparison::Instance() noexcept
{
    [[clang::no_destroy]] static ExtensionLowercaseComparison inst;
    return inst;
}

static std::string ProduceFormCLowercase(std::string_view _string)
{
    const base::CFStackAllocator allocator;

    CFStringRef original = CFStringCreateWithBytesNoCopy(allocator,
                                                         reinterpret_cast<const UInt8 *>(_string.data()),
                                                         _string.length(),
                                                         kCFStringEncodingUTF8,
                                                         false,
                                                         kCFAllocatorNull);

    if( !original )
        return {};

    CFMutableStringRef mutable_string = CFStringCreateMutableCopy(allocator, 0, original);
    CFRelease(original);
    if( !mutable_string )
        return {};

    CFStringLowercase(mutable_string, nullptr);
    CFStringNormalize(mutable_string, kCFStringNormalizationFormC);

    char utf8[128];
    long used = 0;
    CFStringGetBytes(mutable_string,
                     CFRangeMake(0, CFStringGetLength(mutable_string)),
                     kCFStringEncodingUTF8,
                     0,
                     false,
                     reinterpret_cast<UInt8 *>(utf8),
                     sizeof(utf8) - 1,
                     &used);
    utf8[used] = 0;

    CFRelease(mutable_string);
    return utf8;
}

std::string ExtensionLowercaseComparison::ExtensionToLowercase(std::string_view _extension)
{
    if( _extension.length() > m_MaxLength )
        // we don't cache long extensions
        return ProduceFormCLowercase(_extension);

    auto lock = std::lock_guard{m_Lock};
    auto it = m_Data.find(_extension);
    if( it != std::end(m_Data) )
        return it->second;

    auto cl = ProduceFormCLowercase(_extension);
    m_Data.emplace(_extension, cl);
    return cl;
}

bool ExtensionLowercaseComparison::Equal(std::string_view _filename_ext, std::string_view _compare_to_formc_lc)
{
    if( _filename_ext.empty() )
        return _compare_to_formc_lc.empty();
    if( _compare_to_formc_lc.empty() )
        return _filename_ext.empty();

    if( _filename_ext.length() <= m_MaxLength ) {
        auto lock = std::lock_guard{m_Lock};
        auto it = m_Data.find(_filename_ext);
        if( it != std::end(m_Data) )
            return it->second == _compare_to_formc_lc;
        auto cl = ProduceFormCLowercase(_filename_ext);
        auto equal = cl == _compare_to_formc_lc;
        m_Data.emplace(_filename_ext, std::move(cl));
        return equal;
    }
    else {
        auto cl = ProduceFormCLowercase(_filename_ext);
        return cl == _compare_to_formc_lc;
    }
}

ExtensionsLowercaseList::ExtensionsLowercaseList(std::string_view _comma_separated_list)
{
    auto &i = ExtensionLowercaseComparison::Instance();
    std::vector<std::string> exts;
    for( const auto ext : std::views::split(_comma_separated_list, ',') )
        if( auto trimmed = base::Trim(std::string_view{ext}); !trimmed.empty() )
            exts.emplace_back(trimmed);
    for( auto &ext : exts ) {
        if( !ext.empty() )
            m_List.emplace(i.ExtensionToLowercase(ext));
    }
}

bool ExtensionsLowercaseList::contains(std::string_view _extension) const noexcept
{
    return m_List.contains(ExtensionLowercaseComparison::Instance().ExtensionToLowercase(_extension));
}

} // namespace nc::utility
