//
//  FileMask.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileMask.h"

FileMask::FileMask():
    m_Mask(nil),
    m_RegExps(nil)
{
}

FileMask::FileMask(NSString *_mask):
    m_Mask(nil),
    m_RegExps(nil)
{
    if([_mask length] == 0) return;

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
    m_RegExps = [NSMutableArray new];
    for(NSString *s: simple_masks)
    {
        NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:s
                                                                             options:NSRegularExpressionCaseInsensitive
                                                                               error:nil];
        if(reg)
           [m_RegExps addObject:reg];
    }
}

FileMask::FileMask(const FileMask&_r):
    m_Mask([_r.m_Mask copy]),
    m_RegExps([_r.m_RegExps copy])
{
}

FileMask::FileMask(FileMask&&_r):
    m_Mask(_r.m_Mask),
    m_RegExps(_r.m_RegExps)
{
    _r.m_Mask = nil;
    _r.m_RegExps = nil;
}

FileMask& FileMask::operator=(const FileMask&_r)
{
    m_Mask = [_r.m_Mask copy];
    m_RegExps = [_r.m_RegExps copy];
    return *this;
}

FileMask& FileMask::operator=(FileMask&&_r)
{
    m_Mask = _r.m_Mask;
    m_RegExps = _r.m_RegExps;
    _r.m_Mask = nil;
    _r.m_RegExps = nil;
    return *this;
}

bool FileMask::MatchName(NSString *_name) const
{
    if(!m_RegExps || !_name)
        return false;

    auto len = _name.length;
    auto range = NSMakeRange(0, len);    
    for(NSRegularExpression *re: m_RegExps)
    {
        NSRange r = [re rangeOfFirstMatchInString:_name
                                          options:0
                                            range:range];
        if(r.length == len)
            return true;
    }
    return false;
}

bool FileMask::MatchName(const char *_name) const
{
    // suboptimal, optimize later:
    return MatchName([NSString stringWithUTF8String:_name]);
}
