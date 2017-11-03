// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/param.h>
#include <boost/algorithm/string/replace.hpp>
#include <boost/algorithm/string/split.hpp>
#include <regex>
#include <Habanero/CFStackAllocator.h>
#include "FileMask.h"

static inline bool
strincmp2(const char *s1, const char *s2, size_t _n)
{
    while( _n-- > 0 ) {
        if( *s1 != tolower(*s2++) )
            return false;
        if( *s1++ == '\0' )
            break;
    }
    return true;
}

static string regex_escape(const string& string_to_escape)
{
    // do not escape "?" and "*"
    static const regex escape( "[.^$|()\\[\\]{}+\\\\]" );
    static const string replace( "\\\\&" );
    return regex_replace(string_to_escape,
                         escape,
                         replace,
                         regex_constants::match_default | regex_constants::format_sed);
}

static void trim_leading_whitespaces(string& _str)
{
    auto first = _str.find_first_not_of(' ');
    if( first == string::npos ) {
        _str.clear();
        return;
    }
    if( first == 0 )
        return;
    
    _str.erase( begin(_str), next(begin(_str), first) );
}

static vector<string> sub_masks( const string &_source )
{
    vector<string> masks;
    boost::split( masks, _source, [](char _c){ return _c == ',';} );

    for(auto &s: masks) {
        trim_leading_whitespaces(s);
        s = regex_escape(s);
        boost::replace_all(s, "*", ".*");
        boost::replace_all(s, "?", ".");
    }
    
    return masks;
}

static bool MaskStringNeedsNormalization(string_view _string)
{
    for( unsigned char c: _string )
        if( c > 127 || ( c >= 0x41 && c <= 0x5A ) ) // >= 'A' && <= 'Z'
            return true;
    
    return false;
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

static optional<string> GetSimpleMask( const string &_regexp )
{
    const char *str = _regexp.c_str();
    const int str_len = (int)_regexp.size();
    bool simple = false;
    if(str_len > 4 &&
       strncmp(str, ".*\\.", 4) == 0) {
        // check that symbols on the right side are english letters in lowercase
        for(int i = 4; i < str_len; ++i)
            if( str[i] < 'a' || str[i] > 'z')
                goto failed;
        
        simple = true;
    failed:;
    }
    
    if( !simple )
        return nullopt;
    
    return string( str + 3 ); // store masks like .png if it is simple
}

FileMask::FileMask(const char* _mask):
    FileMask( _mask ? string(_mask) : ""s)
{
}

FileMask::FileMask(const string &_mask):
    m_Mask(_mask)
{
    if( _mask.empty() )
        return;
    
    auto submasks = sub_masks( _mask );
    
    for( auto &s: submasks )
        if( !s.empty() ) {
            if( auto sm = GetSimpleMask(s) ) {
                m_Masks.emplace_back( nullopt, move(sm) );
            }
            else {
                try {
                    m_Masks.emplace_back(
                        regex( MaskStringNeedsNormalization(s) ? ProduceFormCLowercase(s) : s ),
                        nullopt
                        );
                }
                catch(...) {
                }
            }
        }
}

static bool CompareAgainstSimpleMask(const string& _mask, string_view _name) noexcept
{
    if( _name.length() < _mask.length() )
        return false;
    
    const char *chars = _name.data();
    size_t chars_num = _name.length();
    
    return strincmp2(_mask.c_str(), chars + chars_num - _mask.size(), _mask.size());
}

bool FileMask::MatchName(const string &_name) const
{
    return MatchName( _name.c_str() );
}

bool FileMask::MatchName(const char *_name) const
{
    if( m_Masks.empty() || !_name )
        return false;
    
    optional<string> normalized_name;
    for( auto &m: m_Masks )
        if( m.first ) {
            if( !normalized_name )
                normalized_name = ProduceFormCLowercase(_name);
            if( regex_match(*normalized_name, *m.first) )
                return true;
        }
        else if( m.second ) {
            if( CompareAgainstSimpleMask( *m.second, _name ) )
                return true;
        }
    
    return false;
}

bool FileMask::IsWildCard(const string &_mask)
{
    return any_of( begin(_mask), end(_mask), [](char c){ return c == '*' || c == '?'; } );
}

static string ToWildCard(const string &_mask, const bool _for_extension)
{
    if( _mask.empty() )
        return "";
    
    vector<string> sub_masks;
    boost::split( sub_masks, _mask, [](char _c){ return _c == ','; } );
    
    string result;
    for( auto &s: sub_masks ) {
        trim_leading_whitespaces(s);
        
        if( FileMask::IsWildCard(s) ) {
            // just use this part as it is
            if( !result.empty() )
                result += ", ";
            result += s;
        }
        else if( !s.empty() ){
            
            if( !result.empty() )
                result += ", ";
            
            if( _for_extension ) {
                // currently simply append "*." prefix and "*" suffix
                result += '*';
                if( s[0] != '.')
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

string FileMask::ToExtensionWildCard(const string& _mask)
{
    return ToWildCard(_mask, true);
}

string FileMask::ToFilenameWildCard(const string& _mask)
{
    return ToWildCard(_mask, false);
}

const string& FileMask::Mask() const
{
    return m_Mask;
}

bool FileMask::IsEmpty() const
{
    return m_Masks.empty();
}

bool FileMask::operator ==(const FileMask&_rhs) const noexcept
{
    return m_Mask == _rhs.m_Mask;
}

bool FileMask::operator !=(const FileMask&_rhs) const noexcept
{
    return !(*this == _rhs);
}
