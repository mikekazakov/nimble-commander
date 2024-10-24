// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FileMask.h"
#include <Base/CFPtr.h>
#include <Base/CFStackAllocator.h>
#include <Base/algo.h>
#include <algorithm>
#include <optional>
#include <ranges>
#include <regex>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>

namespace nc::utility {

static bool strincmp2(const char *s1, const char *s2, size_t _n)
{
    while( _n-- > 0 ) {
        if( *s1 != tolower(*s2++) )
            return false;
        if( *s1++ == '\0' )
            break;
    }
    return true;
}

static std::string regex_escape(const std::string &string_to_escape)
{
    // TODO: migrate to RE2
    // do not escape "?" and "*"
    [[clang::no_destroy]] static const std::regex escape(R"([.^$|()\[\]{}+\\])");
    [[clang::no_destroy]] static const std::string replace("\\\\&");
    return std::regex_replace(
        string_to_escape, escape, replace, std::regex_constants::match_default | std::regex_constants::format_sed);
}

static std::vector<std::string> sub_masks(std::string_view _source)
{
    std::vector<std::string> masks;
    for( const auto mask : std::views::split(_source, ',') )
        if( auto trimmed = base::Trim(std::string_view{mask}); !trimmed.empty() )
            masks.emplace_back(trimmed);

    for( auto &s : masks ) {
        s = regex_escape(s);
        s = base::ReplaceAll(s, '*', ".*");
        s = base::ReplaceAll(s, '?', ".");
    }

    return masks;
}

static bool string_needs_normalization(std::string_view _string) noexcept
{
    return std::ranges::any_of(_string, [](const unsigned char _c) {
        return _c > 127 || (_c >= 0x41 && _c <= 0x5A); // >= 'A' && <= 'Z'
    });
}

class InplaceFormCLowercaseString
{
public:
    InplaceFormCLowercaseString(std::string_view _string) noexcept;
    [[nodiscard]] std::string_view str() const noexcept;

private:
    char m_Buf[4096]; // strings longer than this will be truncated and possibly not matched.
    std::string_view m_View;
};

InplaceFormCLowercaseString::InplaceFormCLowercaseString(std::string_view _string) noexcept
{
    if( !string_needs_normalization(_string) )
        m_View = _string; // using the original string! The characters are not copied.

    using base::CFPtr;
    const base::CFStackAllocator allocator;

    auto original =
        CFPtr<CFStringRef>::adopt(CFStringCreateWithBytesNoCopy(allocator,
                                                                reinterpret_cast<const UInt8 *>(_string.data()),
                                                                _string.length(),
                                                                kCFStringEncodingUTF8,
                                                                false,
                                                                kCFAllocatorNull));

    if( !original )
        return;

    auto mutable_string = CFPtr<CFMutableStringRef>::adopt(CFStringCreateMutableCopy(allocator, 0, original.get()));
    if( !mutable_string )
        return;

    CFStringLowercase(mutable_string.get(), nullptr);
    CFStringNormalize(mutable_string.get(), kCFStringNormalizationFormC);

    long characters_used = 0;
    CFStringGetBytes(mutable_string.get(),
                     CFRangeMake(0, CFStringGetLength(mutable_string.get())),
                     kCFStringEncodingUTF8,
                     0,
                     false,
                     reinterpret_cast<UInt8 *>(m_Buf),
                     sizeof(m_Buf),
                     &characters_used);
    m_View = {m_Buf, static_cast<size_t>(characters_used)};
}

std::string_view InplaceFormCLowercaseString::str() const noexcept
{
    return m_View;
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
        return "";

    CFMutableStringRef mutable_string = CFStringCreateMutableCopy(allocator, 0, original);
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
                     reinterpret_cast<UInt8 *>(utf8),
                     MAXPATHLEN - 1,
                     &used);
    utf8[used] = 0;

    CFRelease(mutable_string);
    return utf8;
}

static std::optional<std::string> GetSimpleMask(const std::string &_regexp)
{
    const char *str = _regexp.c_str();
    const size_t str_len = _regexp.size();
    bool simple = false;
    if( str_len > 4 && strncmp(str, ".*\\.", 4) == 0 ) {
        // check that symbols on the right side are english letters in lowercase
        for( size_t i = 4; i < str_len; ++i )
            if( str[i] < 'a' || str[i] > 'z' )
                goto failed;

        simple = true;
    failed:;
    }

    if( !simple )
        return std::nullopt;

    return std::string(str + 3); // store masks like .png if it is simple
}

FileMask::FileMask() noexcept = default;

FileMask::FileMask(const std::string_view _mask, const Type _type) : m_Mask(_mask)
{
    if( _mask.empty() )
        return;

    if( _type == Type::Mask ) {
        auto submasks = sub_masks(_mask);
        for( auto &s : submasks ) {
            if( s.empty() )
                continue;
            if( auto sm = GetSimpleMask(s) ) {
                m_Masks.emplace_back(std::move(*sm));
            }
            else {
                auto regex = std::make_shared<re2::RE2>(string_needs_normalization(s) ? ProduceFormCLowercase(s) : s,
                                                        re2::RE2::Quiet);
                if( regex->ok() )
                    m_Masks.emplace_back(std::move(regex));
            }
        }
    }

    if( _type == Type::RegEx ) {
        auto regex = std::make_shared<re2::RE2>(
            string_needs_normalization(_mask) ? ProduceFormCLowercase(_mask) : _mask, re2::RE2::Quiet);
        if( regex->ok() )
            m_Masks.emplace_back(std::move(regex));
    }
}

bool FileMask::Validate(const std::string_view _mask, const Type _type)
{
    if( _type == Type::RegEx ) {
        re2::RE2 const regex(string_needs_normalization(_mask) ? ProduceFormCLowercase(_mask) : _mask, re2::RE2::Quiet);
        return regex.ok();
    }
    return true;
}

static bool CompareAgainstSimpleMask(const std::string &_mask, std::string_view _name) noexcept
{
    if( _name.length() < _mask.length() )
        return false;

    const char *chars = _name.data();
    const size_t chars_num = _name.length();

    return strincmp2(_mask.c_str(), chars + chars_num - _mask.size(), _mask.size());
}

bool FileMask::MatchName(std::string_view _name) const noexcept
{
    if( m_Masks.empty() || _name.empty() )
        return false;

    const InplaceFormCLowercaseString normalized_name(_name);
    return std::ranges::any_of(m_Masks, [&](auto &m) {
        if( m.index() == 0 ) {
            const auto &re = std::get<std::shared_ptr<const re2::RE2>>(m);
            if( re2::RE2::FullMatch(normalized_name.str(), *re) )
                return true;
        }
        else {
            const auto &simple_mask = std::get<std::string>(m);
            if( CompareAgainstSimpleMask(simple_mask, _name) ) // TODO: why the original string here??
                return true;
        }
        return false;
    });
}

bool FileMask::IsWildCard(const std::string &_mask)
{
    return std::ranges::any_of(_mask, [](char c) { return c == '*' || c == '?'; });
}

static std::string ToWildCard(const std::string &_mask, const bool _for_extension)
{
    if( _mask.empty() )
        return "";

    std::vector<std::string> sub_masks;
    for( const auto mask : std::views::split(std::string_view{_mask}, ',') )
        if( auto trimmed = base::Trim(std::string_view{mask}); !trimmed.empty() )
            sub_masks.emplace_back(trimmed);

    std::string result;
    for( auto &s : sub_masks ) {
        if( FileMask::IsWildCard(s) ) {
            // just use this part as it is
            if( !result.empty() )
                result += ", ";
            result += s;
        }
        else if( !s.empty() ) {

            if( !result.empty() )
                result += ", ";

            if( _for_extension ) {
                // currently simply append "*." prefix and "*" suffix
                result += '*';
                if( s[0] != '.' )
                    result += '.';
                result += s;
            }
            else {
                // currently simply append "*" prefix and "*" suffix
                result += '*';
                result += s;
                result += '*';
            }
        }
    }
    return result;
}

std::string FileMask::ToExtensionWildCard(const std::string &_mask)
{
    return ToWildCard(_mask, true);
}

std::string FileMask::ToFilenameWildCard(const std::string &_mask)
{
    return ToWildCard(_mask, false);
}

const std::string &FileMask::Mask() const noexcept
{
    return m_Mask;
}

bool FileMask::IsEmpty() const noexcept
{
    return m_Masks.empty();
}

bool FileMask::operator==(const FileMask &_rhs) const noexcept
{
    return m_Mask == _rhs.m_Mask;
}

bool FileMask::operator!=(const FileMask &_rhs) const noexcept
{
    return !(*this == _rhs);
}

} // namespace nc::utility
