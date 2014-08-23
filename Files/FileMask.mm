//
//  FileMask.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileMask.h"

static inline bool
stricmp2(const char *s1, const char *s2)
{
    do {
        if (*s1 != tolower(*s2++))
            return false;
        if (*s1++ == '\0')
            break;
    } while (true);
    return true;
}

FileMask::FileMask():
    m_Mask(nil),
    m_RegExps(nil)
{
}

FileMask::FileMask(NSString *_mask):
    m_Mask(nil),
    m_RegExps(nil)
{
    if(_mask == nil || _mask.length == 0) return;

    m_Mask = _mask.copy;
    
    NSString *mask = [_mask decomposedStringWithCanonicalMapping];

    // guarding againts regexps operators
    // suboptimal, optimize later:
//    Quotes the following character. Characters that must be quoted to be treated as literals
//    are * ? + [ ( ) { } ^ $ | \ . /
    mask = [mask stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]; // not sure if this is nesessary
    mask = [mask stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
    mask = [mask stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
    mask = [mask stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
    mask = [mask stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
    mask = [mask stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
    mask = [mask stringByReplacingOccurrencesOfString:@"}" withString:@"\\}"];
    mask = [mask stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    mask = [mask stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
    mask = [mask stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
    mask = [mask stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
    mask = [mask stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
    mask = [mask stringByReplacingOccurrencesOfString:@"*" withString:@".*"];
    mask = [mask stringByReplacingOccurrencesOfString:@"?" withString:@"."]; // use '?' for single-character wildcard

    // convert from "mask1,    mask2" to "mask1,mask2"
    for(;;) {
        NSString *new_mask = [mask stringByReplacingOccurrencesOfString:@", " withString:@","];
        if([new_mask isEqualToString:mask]) break;
        mask = new_mask;
    }
    
    NSArray *simple_masks = [mask componentsSeparatedByString:@","];
    for(NSString *s: simple_masks) {
        NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:s
                                                                             options:NSRegularExpressionCaseInsensitive
                                                                               error:nil];
        if(reg) {
            // check if current regexp is 'simple'
            // simple mask has a form of ".*\.ext"
            const char *str = s.UTF8String;
            size_t str_len = strlen(str);
            bool simple = false;
            if(str_len > 4 &&
               strncmp(str, ".*\\.", 4) == 0) {
                // check that symbols on the right side are english letters in lowercase
                for(int i = 4; i < str_len; ++i)
                    if( str[i] < 'a' && str[i] > 'z')
                        goto failed;
                
                simple = true;
                failed:;
            }

            m_RegExps.emplace_back(reg, simple ? str + 3 : ""); // store masks like .png if it is simple
        }
    }
}

FileMask::FileMask(const FileMask&_r):
    m_Mask([_r.m_Mask copy]),
    m_RegExps(_r.m_RegExps)
{
}

FileMask::FileMask(FileMask&&_r):
    m_Mask(_r.m_Mask),
    m_RegExps(move(_r.m_RegExps))
{
    _r.m_Mask = nil;
}

FileMask& FileMask::operator=(const FileMask&_r)
{
    m_Mask = [_r.m_Mask copy];
    m_RegExps = _r.m_RegExps;
    return *this;
}

FileMask& FileMask::operator=(FileMask&&_r)
{
    m_Mask = _r.m_Mask;
    m_RegExps = move(_r.m_RegExps);
    _r.m_Mask = nil;
    return *this;
}

bool FileMask::CompareAgainstSimpleMask(const string& _mask, NSString *_name)
{
    if(_name.length <= _mask.length())
        return false;
    
    const char *chars = _name.UTF8String;
    size_t chars_num = strlen(chars);
    assert(chars_num > _mask.length());
    
    return stricmp2(_mask.c_str(), chars + chars_num - _mask.size());
}

bool FileMask::MatchName(NSString *_name) const
{
    if(m_RegExps.empty() || !_name || _name.length == 0)
        return false;

    assert(_name != nil && _name.length > 0);
    
    auto len = _name.length;
    auto range = NSMakeRange(0, len);

    for(auto &rx: m_RegExps) {
        if (!rx.second.empty())
            // can compare with simple mask
            if(CompareAgainstSimpleMask(rx.second, _name))
                return true;
        
        // perform full-weight matching
        NSRange r = [rx.first rangeOfFirstMatchInString:_name
                                                options:0
                                                  range:range];
        if(r.length == len)
            return true;
    }
    return false;
}

bool FileMask::MatchName(const char *_name) const
{
    if(_name == nullptr ||
       _name[0] == 0)
        return false;
    
    CFStringRef name = CFStringCreateWithBytesNoCopy(0,
                                                     (UInt8*)_name,
                                                     strlen(_name),
                                                     kCFStringEncodingUTF8,
                                                     false,
                                                     kCFAllocatorNull);
    if(name == nullptr)
        return false;
    
    bool result = MatchName( (__bridge NSString*) name );
    
    CFRelease(name);
    
    return result;
}
