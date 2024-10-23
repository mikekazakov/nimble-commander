/* Copyright (c) 2023-2024 Michael G. Kazakov
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
#include "algo.h"

namespace nc::base {

// TODO: unit tests
std::string_view Trim(std::string_view _str) noexcept
{
    while( !_str.empty() && _str.front() == ' ' )
        _str.remove_prefix(1);
    while( !_str.empty() && _str.back() == ' ' )
        _str.remove_suffix(1);
    return _str;
}

// TODO: unit tests
std::string_view Trim(std::string_view _str, char _c) noexcept
{
    while( !_str.empty() && _str.front() == _c )
        _str.remove_prefix(1);
    while( !_str.empty() && _str.back() == _c )
        _str.remove_suffix(1);
    return _str;
}

// TODO: unit tests
std::string_view TrimLeft(std::string_view _str) noexcept
{
    while( !_str.empty() && _str.front() == ' ' )
        _str.remove_prefix(1);
    return _str;
}

// TODO: unit tests
std::string_view TrimLeft(std::string_view _str, char _c) noexcept
{
    while( !_str.empty() && _str.front() == _c )
        _str.remove_prefix(1);
    return _str;
}

// TODO: unit tests
std::string_view TrimRight(std::string_view _str) noexcept
{
    while( !_str.empty() && _str.back() == ' ' )
        _str.remove_suffix(1);
    return _str;
}

// TODO: unit tests
std::string_view TrimRight(std::string_view _str, char _c) noexcept
{
    while( !_str.empty() && _str.back() == _c )
        _str.remove_suffix(1);
    return _str;
}

// TODO: unit tests
std::string ReplaceAll(std::string_view _source, char _what, std::string_view _with) noexcept
{
    std::string result;
    for( auto c : _source ) {
        if( c == _what ) {
            result += _with;
        }
        else {
            result += c;
        }
    }
    return result;
}

std::string ReplaceAll(std::string_view _source, std::string_view _what, std::string_view _with) noexcept
{
    if( _what.empty() )
        return std::string{_source};
    if( _what.length() == 1 )
        return ReplaceAll(_source, _what.front(), _with);

    std::string result;
    for( size_t pos = 0; pos != _source.length(); ) {
        if( const size_t next = _source.find(_what, pos); next == std::string_view::npos ) {
            result.append(_source.substr(pos));
            pos = _source.length();
        }
        else {
            result.append(_source.substr(pos, next - pos));
            result.append(_with);
            pos = next + _what.size();
        }
    }
    return result;
}

std::vector<std::string> SplitByDelimiters(std::string_view _str, std::string_view _delims, bool _compress) noexcept
{
    std::vector<std::string> res;
    std::string next;
    for( auto c : _str ) {
        if( _delims.contains(c) ) {
            if( !next.empty() || !_compress ) {
                res.emplace_back(std::move(next));
                next = {};
            }
        }
        else {
            next += c;
        }
    }

    if( !next.empty() || (!_compress && !_str.empty()) ) {
        res.emplace_back(std::move(next));
    }

    return res;
}

std::vector<std::string> SplitByDelimiter(std::string_view _str, char _delim, bool _compress) noexcept
{
    std::vector<std::string> res;
    std::string next;
    for( auto c : _str ) {
        if( c == _delim ) {
            if( !next.empty() || !_compress ) {
                res.emplace_back(std::move(next));
                next = {};
            }
        }
        else {
            next += c;
        }
    }

    if( !next.empty() || (!_compress && !_str.empty()) ) {
        res.emplace_back(std::move(next));
    }

    return res;
}

} // namespace nc::base
