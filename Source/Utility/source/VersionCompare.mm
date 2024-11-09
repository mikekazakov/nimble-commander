// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/VersionCompare.h>
#include <optional>
#include <variant>
#include <charconv>

namespace nc::utility {

namespace {

struct SeparatorTag {
};

using Token = std::variant<std::uint64_t, std::string_view, SeparatorTag>;

struct ParseResult {
    std::optional<Token> token;
    std::string_view left;
};

} // namespace

static bool IsSpace(char _c) noexcept;
static bool IsSeparator(char _c) noexcept;
static bool IsAlpha(char _c) noexcept;
static ParseResult ParseNext(std::string_view _string) noexcept;

int VersionCompare::Compare(std::string_view _lhs, std::string_view _rhs) noexcept
{
    while( true ) {
        const auto left = ParseNext(_lhs);
        const auto right = ParseNext(_rhs);

        if( left.token == std::nullopt && right.token == std::nullopt )
            return 0;

        if( left.token == std::nullopt && right.token != std::nullopt ) {
            if( std::holds_alternative<std::string_view>(*right.token) )
                return 1;
            else
                return -1;
        }

        if( left.token != std::nullopt && right.token == std::nullopt ) {
            if( std::holds_alternative<std::string_view>(*left.token) )
                return -1;
            else
                return 1;
        }

        const auto left_token = *left.token;
        const auto right_token = *right.token;
        _lhs = left.left;
        _rhs = right.left;

        if( left_token.index() == right_token.index() ) {
            // same part
            if( std::holds_alternative<std::uint64_t>(left_token) ) {
                const auto left_number = std::get<std::uint64_t>(left_token);
                const auto right_number = std::get<std::uint64_t>(right_token);
                if( left_number < right_number )
                    return -1;
                if( left_number > right_number )
                    return 1;
            }
            else if( std::holds_alternative<SeparatorTag>(left_token) ) {
                // silently eat separators
            }
            else if( std::holds_alternative<std::string_view>(left_token) ) {
                const auto left_string = std::get<std::string_view>(left_token);
                const auto right_string = std::get<std::string_view>(right_token);
                const auto cmp = left_string.compare(right_string);
                if( cmp < 0 )
                    return -1;
                if( cmp > 0 )
                    return 1;
            }
        }
        else {
            // different part
            if( std::holds_alternative<std::string_view>(left_token) &&
                !std::holds_alternative<std::string_view>(right_token) ) {
                return -1;
            }
            if( !std::holds_alternative<std::string_view>(left_token) &&
                std::holds_alternative<std::string_view>(right_token) ) {
                return 1;
            }
            if( std::holds_alternative<std::uint64_t>(left_token) ) {
                return -1;
            }
            return 1;
        }
    }
}

int VersionCompare::Compare(NSString *_lhs, NSString *_rhs) noexcept
{
    return Compare(_lhs.UTF8String, _rhs.UTF8String);
}

static bool IsSpace(char _c) noexcept
{
    // as in https://en.wikipedia.org/wiki/Whitespace_character#Unicode
    // except that anything above 7F is ignored
    switch( _c ) {
        case 0x09:
        case 0x0A:
        case 0x0B:
        case 0x0C:
        case 0x0D:
        case 0x20:
            return true;
        default:
            return false;
    }
}

static bool IsSeparator(char _c) noexcept
{
    switch( _c ) {
        case '!':
        case '\"':
        case '#':
        case '$':
        case '%':
        case '&':
        case '\'':
        case '(':
        case ')':
        case '*':
        case ',':
        case '-':
        case '.':
        case '/':
        case ';':
        case '<':
        case '=':
        case '?':
        case '@':
        case '[':
        case '\\':
        case ']':
        case '^':
        case '_':
        case '`':
        case '{':
        case '|':
        case '~':
            return true;
        default:
            return false;
    }
}

static bool IsAlpha(char _c) noexcept
{
    return (_c >= 'A' && _c <= 'Z') || (_c >= 'a' && _c <= 'z');
}

static ParseResult ParseNext(std::string_view _string) noexcept
{
    // 0th - remove all whitespaces
    while( !_string.empty() && IsSpace(_string.front()) ) {
        _string.remove_prefix(1);
    }

    // 1st - check if there's nothing to do
    if( _string.empty() ) {
        return {};
    }

    // 2st - try to consume as std::uint64_t
    {
        std::uint64_t value = 0;
        const std::from_chars_result res = std::from_chars(_string.data(), _string.data() + _string.length(), value);
        if( res.ec == std::errc() ) {
            // good, got something
            ParseResult pr;
            pr.token = value;
            pr.left = std::string_view(res.ptr, _string.data() + _string.length() - res.ptr);
            return pr;
        }
    }

    // 3rd - consume separator(s) if any
    if( IsSeparator(_string.front()) ) {
        while( !_string.empty() && IsSeparator(_string.front()) )
            _string.remove_prefix(1);
        ParseResult pr;
        pr.token = SeparatorTag{};
        pr.left = _string;
        return pr;
    }

    // 4th - consume characters if any
    if( IsAlpha(_string.front()) ) {
        const char *const first = _string.data();
        while( !_string.empty() && IsAlpha(_string.front()) )
            _string.remove_prefix(1);
        const char *const last = _string.data();
        ParseResult pr;
        pr.token = std::string_view(first, last - first);
        pr.left = _string;
        return pr;
    }

    // wtf?
    return {};
}

} // namespace nc::utility
