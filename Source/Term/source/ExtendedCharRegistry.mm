// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExtendedCharRegistry.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Base/CFPtr.h>
#include <Base/CFStackAllocator.h>
#include <Utility/ObjCpp.h>
#include <Utility/CharInfo.h>
#include <array>

namespace nc::term {

// allow up to g_MaxGraphemeLen UTF16 code units to be processed atomically
static constexpr size_t g_MaxGraphemeLen = 64;
static constexpr char16_t g_VariationSelectorText = u'\xFE0E';
static constexpr char16_t g_VariationSelectorEmoji = u'\xFE0F';
static bool IsPotentiallyComposableCharacter(char16_t _c) noexcept;

ExtendedCharRegistry::ExtendedCharRegistry() : m_Lookup{0, HashEqual{&m_Chars}, HashEqual{&m_Chars}}
{
}

ExtendedCharRegistry &ExtendedCharRegistry::SharedInstance()
{
    [[clang::no_destroy]] static ExtendedCharRegistry inst;
    return inst;
}

constexpr uint32_t ExtendedCharRegistry::ToExtIdx(char32_t _c) noexcept
{
    assert(IsExtended(_c));
    return uint32_t(_c) & ~((uint32_t(1)) << 31);
}

constexpr char32_t ExtendedCharRegistry::ToExtChar(uint32_t _idx) noexcept
{
    return static_cast<char32_t>(_idx | ((uint32_t(1)) << 31));
}

ExtendedCharRegistry::AppendResult ExtendedCharRegistry::Append(const std::u16string_view _input, char32_t _initial)
{
    // No input
    if( _input.data() == nullptr || _input.empty() ) {
        return {.newchar = _initial, .eaten = 0};
    }

    // Fast path bypassing the heavy machinery of Core Foundation
    if( _input.length() > 1 ) {
        const bool second_potentially_composable = IsPotentiallyComposableCharacter(_input[1]);
        if( !second_potentially_composable ) {
            const bool first_potentially_composable = IsPotentiallyComposableCharacter(_input[0]);
            if( !first_potentially_composable ) {
                // 99.99% of cases should fall into this branch.
                return _initial == 0 ? AppendResult{.newchar = _input[0], .eaten = 1}
                                     : AppendResult{.newchar = _initial, .eaten = 0};
            }
        }
    }
    else if( _input.length() == 1 ) {
        const bool first_potentially_composable = IsPotentiallyComposableCharacter(_input[0]);
        if( !first_potentially_composable ) {
            return _initial == 0 ? AppendResult{.newchar = _input[0], .eaten = 1}
                                 : AppendResult{.newchar = _initial, .eaten = 0};
        }
    }

    // Generic 'heavy' path
    // TODO: investigate using stack-based memory storage for CF objects
    if( _initial == 0 ) {
        // Working without an initial character to try to append to
        const base::CFPtr<CFStringRef> cf_str = base::CFPtr<CFStringRef>::adopt(CFStringCreateWithCharactersNoCopy(
            nullptr, reinterpret_cast<const UniChar *>(_input.data()), _input.length(), kCFAllocatorNull));
        if( !cf_str ) {
            // discard incorrect input
            return {.newchar = _initial, .eaten = _input.length()};
        }

        const CFIndex grapheme_len = CFStringGetRangeOfComposedCharactersAtIndex(cf_str.get(), 0).length;

        if( grapheme_len == 1 ) {
            return {.newchar = _input[0], .eaten = 1};
        }
        else if( grapheme_len == 2 && CFStringIsSurrogateHighCharacter(_input[0]) &&
                 CFStringIsSurrogateLowCharacter(_input[1]) ) {
            const uint32_t utf32 = CFStringGetLongCharacterForSurrogatePair(_input[0], _input[1]);
            return {.newchar = utf32, .eaten = 2};
        }
        else {
            const std::lock_guard lock{m_Lock};
            const uint32_t idx = FindOrAdd_Unlocked(_input.substr(0, grapheme_len));
            return {.newchar = ToExtChar(idx), .eaten = static_cast<size_t>(grapheme_len)};
        }
    }
    else if( IsBase(_initial) ) {
        // Working with an initial character to try to append to, which is a real non-extended character
        uint16_t buf[g_MaxGraphemeLen];
        const size_t initial_len = CFStringGetSurrogatePairForLongCharacter(_initial, buf) ? 2 : 1;
        size_t len = initial_len;
        const size_t input_len = std::min(_input.size(), std::size(buf) - len); // may be truncated
        memcpy(buf + len, _input.data(), input_len * sizeof(char16_t));
        len += input_len;

        const base::CFPtr<CFStringRef> cf_str =
            base::CFPtr<CFStringRef>::adopt(CFStringCreateWithCharactersNoCopy(nullptr, buf, len, kCFAllocatorNull));
        if( !cf_str ) {
            // discard incorrect input
            return {.newchar = _initial, .eaten = _input.length()};
        }

        const CFIndex grapheme_len = CFStringGetRangeOfComposedCharactersAtIndex(cf_str.get(), 0).length;
        assert(static_cast<size_t>(grapheme_len) >= initial_len);
        if( static_cast<size_t>(grapheme_len) == initial_len ) {
            return {.newchar = _initial, .eaten = 0}; // can't be composed with _initial
        }
        else {
            const std::lock_guard lock{m_Lock};
            const uint32_t idx =
                FindOrAdd_Unlocked({reinterpret_cast<const char16_t *>(buf), static_cast<size_t>(grapheme_len)});
            return {.newchar = ToExtChar(idx), .eaten = grapheme_len - initial_len};
        }
    }
    else {
        // Working with an initial character to try to append to, which is an extended character.
        const std::lock_guard lock{m_Lock}; // TODO: this is rather silly and will bottleneck on contention...

        // look up the initial extended character
        const uint32_t initial_ex_idx = ToExtIdx(_initial);
        if( initial_ex_idx >= m_Chars.size() ) {
            return {.newchar = _initial, .eaten = 0}; // corrupted external char? report that we can't
                                                      // compose with it
        }

        uint16_t buf[g_MaxGraphemeLen];
        const size_t initial_len = m_Chars[initial_ex_idx].str.length();
        if( initial_len == g_MaxGraphemeLen ) {
            return {.newchar = _initial, .eaten = 0}; // we're full, can't combine more. don't allow
                                                      // too crazy Zalgo text...
        }

        memcpy(buf, m_Chars[initial_ex_idx].str.data(), initial_len * sizeof(char16_t));
        size_t len = initial_len;
        const size_t input_len = std::min(_input.size(), std::size(buf) - len); // may be truncated
        memcpy(buf + len, _input.data(), input_len * sizeof(char16_t));
        len += input_len;

        const base::CFPtr<CFStringRef> cf_str =
            base::CFPtr<CFStringRef>::adopt(CFStringCreateWithCharactersNoCopy(nullptr, buf, len, kCFAllocatorNull));
        if( !cf_str ) {
            // discard incorrect input
            return {.newchar = _initial, .eaten = _input.length()};
        }

        const CFIndex grapheme_len = CFStringGetRangeOfComposedCharactersAtIndex(cf_str.get(), 0).length;
        assert(static_cast<size_t>(grapheme_len) >= initial_len);
        if( static_cast<size_t>(grapheme_len) == initial_len ) {
            return {.newchar = _initial, .eaten = 0}; // can't be composed with _initial
        }
        else {
            const uint32_t idx =
                FindOrAdd_Unlocked({reinterpret_cast<const char16_t *>(buf), static_cast<size_t>(grapheme_len)});
            return {.newchar = ToExtChar(idx), .eaten = grapheme_len - initial_len};
        }
    }
}

uint32_t ExtendedCharRegistry::FindOrAdd_Unlocked(std::u16string_view _str)
{
    assert(_str.length() > 1);
    auto it = m_Lookup.find(_str); // O(1)
    if( it != m_Lookup.end() )
        return *it;

    const uint32_t idx = static_cast<uint32_t>(m_Chars.size());
    m_Chars.emplace_back(_str); // O(1)
    m_Lookup.emplace(idx);      // O(1)
    return idx;
}

base::CFPtr<CFStringRef> ExtendedCharRegistry::Decode(char32_t _code) const noexcept
{
    if( IsBase(_code) )
        return {};

    const uint32_t idx = ToExtIdx(_code);
    const std::lock_guard lock{m_Lock};
    if( idx >= m_Chars.size() )
        return {};
    return m_Chars[idx].cf_str;
}

NSString *ExtendedCharRegistry::DecodeNS(char32_t _code) const noexcept
{
    if( IsBase(_code) )
        return nil;

    auto str = Decode(_code);
    return objc_bridge_cast<NSString>(str.get()); // should +1 here ???
}

bool ExtendedCharRegistry::IsDoubleWidth(char32_t _code) const noexcept
{
    if( IsBase(_code) ) {
        return utility::CharInfo::WCWidthMin1(_code) == 2;
    }
    else {
        const uint32_t idx = ToExtIdx(_code);
        const std::lock_guard lock{m_Lock};
        if( idx >= m_Chars.size() )
            return false; // treat invalid extended characters as single-space
        return m_Chars[idx].flags & ExtendedChar::DoubleWidth;
    }
}

ExtendedCharRegistry::ExtendedChar::ExtendedChar() = default;

ExtendedCharRegistry::ExtendedChar::ExtendedChar(std::u16string_view _str)
{
    assert(!_str.empty());
    cf_str = base::CFPtr<CFStringRef>::adopt(
        CFStringCreateWithCharacters(nullptr, reinterpret_cast<const UniChar *>(_str.data()), _str.length()));
    str = _str;
    flags = 0;

    // now determine once if this extended character is double-width
    bool is_double_width = false;
    const char16_t *chars = str.data();
    // safe to do this as the string is null-termined, hence [0] and [1] always exist
    if( CFStringIsSurrogateHighCharacter(chars[0]) && CFStringIsSurrogateLowCharacter(chars[1]) ) {
        const uint32_t utf32 = CFStringGetLongCharacterForSurrogatePair(chars[0], chars[1]);
        is_double_width = utility::CharInfo::WCWidthMin1(utf32) == 2;
    }
    else {
        is_double_width = utility::CharInfo::WCWidthMin1(static_cast<uint32_t>(chars[0])) == 2;
    }

    if( !is_double_width ) {
        // also check for presense of variation selectors
        for( const char16_t c : str ) {
            if( c == g_VariationSelectorEmoji ) {
                is_double_width = true;
                break;
            }
            if( c == g_VariationSelectorText ) {
                break;
            }
        }
    }

    if( is_double_width )
        flags |= DoubleWidth;
}

size_t ExtendedCharRegistry::HashEqual::operator()(uint32_t _idx) const noexcept
{
    assert(_idx < (*chars).size());
    const auto &str = (*chars)[_idx].str;
    return this->operator()(str);
}

size_t ExtendedCharRegistry::HashEqual::operator()(std::u16string_view _str) const noexcept
{
    return ankerl::unordered_dense::hash<std::u16string_view>{}(_str);
}

bool ExtendedCharRegistry::HashEqual::operator()(std::u16string_view _lhs, std::u16string_view _rhs) const noexcept
{
    return _lhs == _rhs;
}

bool ExtendedCharRegistry::HashEqual::operator()(uint32_t _lhs, std::u16string_view _rhs) const noexcept
{
    assert(_lhs < (*chars).size());
    return (*chars)[_lhs].str == _rhs;
}

bool ExtendedCharRegistry::HashEqual::operator()(std::u16string_view _lhs, uint32_t _rhs) const noexcept
{
    assert(_rhs < (*chars).size());
    return _lhs == (*chars)[_rhs].str;
}

bool ExtendedCharRegistry::HashEqual::operator()(uint32_t _lhs, uint32_t _rhs) const noexcept
{
    return _lhs == _rhs;
}

static constexpr std::array<uint64_t, 65536 / 64> BuildPotentiallyComposableCharacterTable() noexcept
{
    constexpr size_t sz = 65536 / 64;
    std::array<uint64_t, sz> a;
    a.fill(0);
    auto set = [&a](uint16_t _first, uint16_t _last) {
        for( size_t n = _first; n <= _last; ++n ) {
            a[n / 64] |= (uint64_t(1) << (n % 64));
        }
    };
    set(0x0300, 0x036F); // Combining Diacritical Marks             [U+0300..U+036F]
    set(0x1AB0, 0x1AFF); // Combining Diacritical Marks Extended    [U+1AB0..U+1AFF]
    set(0x1DC0, 0x1DFF); // Phonetic Extensions                     [U+1D00..U+1D7F]
                         // Phonetic Extensions Supplement          [U+1D80..U+1DBF]
                         // Combining Diacritical Marks Supplement  [U+1DC0..U+1DFF]
    set(0x2000, 0x206F); // General Punctuation                     [U+2000..U+206F]
    set(0x20D0, 0x20FF); // Combining Diacritical Marks for Symbols [U+20D0..U+20FF]
    set(0xD800, 0xDFFF); // High Surrogates                         [U+D800..U+DB7F]
                         // High Private Use Surrogates             [U+DB80..U+DBFF]
                         // Low Surrogates                          [U+DC00..U+DFFF]
    set(0xFE00, 0xFE0F); // Variation Selectors                     [U+FE00..U+FE0F]
    set(0xFE20, 0xFE2F); // Combining Half Marks                    [U+FE20..U+FE2F]
    return a;
}

static bool IsPotentiallyComposableCharacter(char16_t _c) noexcept
{
    static constexpr auto flags = BuildPotentiallyComposableCharacterTable();
    return (flags[_c / 64] >> (_c % 64)) & 1;
}

} // namespace nc::term
