//
//  FileMask.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileMask.h"

FileMask::FileMask(NSString *_mask):
    m_RegExps(0)
{
    if([_mask length] == 0) return;
        
    NSString *mask = [_mask decomposedStringWithCanonicalMapping];

    // guarding againts regexps operators
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

bool FileMask::MatchName(NSString *_name) const
{
    if(!m_RegExps)
        return false;    

    auto len = [_name length];
    for(NSRegularExpression *re: m_RegExps)
    {
        NSRange r = [re rangeOfFirstMatchInString:_name
                                          options:0
                                            range:NSMakeRange(0, len)];
        if(r.length == len)
            return true;
    }
    return false;
}
