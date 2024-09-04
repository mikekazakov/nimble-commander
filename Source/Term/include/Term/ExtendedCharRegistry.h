// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#include <cassert>
#include <compare>
#include <string_view>
#include <vector>
#include <Base/CFPtr.h>
#include <Base/spinlock.h>
#include <ankerl/unordered_dense.h>

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#endif

namespace nc::term {

class ExtendedCharRegistry
{
public:
    ExtendedCharRegistry();

    static ExtendedCharRegistry &SharedInstance();

    struct AppendResult {
        // a new character in place of the previous one. can be either a base character and an extended one.
        char32_t newchar = 0;

        // code units (i.e. utf32 utf16 chars) consumed from the input
        size_t eaten = 0;

        constexpr auto operator<=>(const AppendResult &) const noexcept = default;
    };

    // Composes a grapheme by trying to append characters from '_input' to '_initial'.
    // If '_initial' is zero it is treated as being absent.
    // Returns a new character and the number of characters consumed from '_input'.
    // If the result contains the same '_initial' character and no eaten characters that means the
    // grapheme describled by '_initial' could not be combined with characters from '_input'.
    AppendResult Append(std::u16string_view _input, char32_t _initial = 0);

    // Provides a CFStringRef for an encoded extended char '_code'.
    // If '_code' is a base character this function will return an empty pointer.
    base::CFPtr<CFStringRef> Decode(char32_t _code) const noexcept;

#ifdef __OBJC__
    // Provides a NSString for an encoded extended char '_code'.
    // If '_code' is a base character this function will return nil.
    NSString *DecodeNS(char32_t _code) const noexcept;
#endif

    // Checks if the character (either base or extended) takes two screen spaces.
    // Works for both base and extended characters.
    bool IsDoubleWidth(char32_t _code) const noexcept;

    // Check if the character is a normal Unicode character that can be used as-is
    static constexpr bool IsBase(char32_t _code) noexcept;

    // Check if the character is an artificial extended character that is actually a string that need to be extracted
    // from the registry.
    static constexpr bool IsExtended(char32_t _code) noexcept;

private:
    static constexpr uint32_t ToExtIdx(char32_t _c) noexcept;
    static constexpr char32_t ToExtChar(uint32_t _idx) noexcept;

    uint32_t FindOrAdd_Unlocked(std::u16string_view _str);

    struct ExtendedChar {
        ExtendedChar();
        ExtendedChar(std::u16string_view _str);

        static constexpr uint64_t DoubleWidth = uint64_t(1) << 0;

        std::u16string str; // holds up to 7 characters via SBO, should be optimized
        base::CFPtr<CFStringRef> cf_str;
        uint64_t flags;
    };
    static_assert(sizeof(ExtendedChar) == 40); // silly :-(

    using CharsT = std::vector<ExtendedChar>;

    struct HashEqual {
        using is_transparent = void;
        size_t operator()(uint32_t _idx) const noexcept;
        size_t operator()(std::u16string_view _str) const noexcept;
        bool operator()(std::u16string_view _lhs, std::u16string_view _rhs) const noexcept;
        bool operator()(uint32_t _lhs, std::u16string_view _rhs) const noexcept;
        bool operator()(std::u16string_view _lhs, uint32_t _rhs) const noexcept;
        bool operator()(uint32_t _lhs, uint32_t _rhs) const noexcept;
        const CharsT *chars;
    };

    mutable spinlock m_Lock;
    ankerl::unordered_dense::set<uint32_t, HashEqual, HashEqual> m_Lookup;
    CharsT m_Chars;
};

constexpr bool ExtendedCharRegistry::IsBase(char32_t _c) noexcept
{
    return !(uint32_t(_c) & ((uint32_t(1)) << 31));
}

constexpr bool ExtendedCharRegistry::IsExtended(char32_t _c) noexcept
{
    return uint32_t(_c) & ((uint32_t(1)) << 31);
}

} // namespace nc::term
