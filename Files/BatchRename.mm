//
//  BatchRename.cpp
//  Files
//
//  Created by Michael G. Kazakov on 14/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "BatchRename.h"


optional<vector<BatchRename::MaskDecomposition>> BatchRename::DecomposeMaskIntoPlaceholders(NSString *_mask)
{
    static NSCharacterSet *open_br = [NSCharacterSet characterSetWithCharactersInString:@"["];
    static NSCharacterSet *close_br = [NSCharacterSet characterSetWithCharactersInString:@"]"];
    assert(_mask != nil);
    
    vector<BatchRename::MaskDecomposition> result;
    auto length = _mask.length;
    auto range = NSMakeRange(0, length);
    while( range.length > 0 ) {
        
        auto open_r = [_mask rangeOfCharacterFromSet:open_br options:0 range:range];
        if( open_r.location == range.location ) {
            // this part starts with placeholder
            auto close_r = [_mask rangeOfCharacterFromSet:close_br options:0 range:NSMakeRange(range.location+1, range.length-1)];
            if( close_r.location == NSNotFound )
                return nullopt; // invalid mask
            while( close_r.location < length - 1 &&
                  [_mask characterAtIndex:close_r.location+1] == ']')
                close_r.location++;
            
            auto l = close_r.location - (open_r.location+1);
            result.emplace_back( [_mask substringWithRange:NSMakeRange(open_r.location+1, l)], true );
            
            range.location += l+2;
            range.length -= l+2;
        }
        else if( open_r.location == NSNotFound ) {
            // have have no more placeholders
            auto close_r = [_mask rangeOfCharacterFromSet:close_br options:0 range:range];
            if(close_r.location != NSNotFound)
                return nullopt; // invalid mask
            result.emplace_back( [_mask substringWithRange:range], false );
            break;
        }
        else {
            // we have placeholder somewhere further
            auto close_r = [_mask rangeOfCharacterFromSet:close_br options:0 range:range];
            if( close_r.location == NSNotFound ||
               close_r.location < open_r.location )
                return nullopt; // invalid mask
            auto l = open_r.location-range.location;
            result.emplace_back( [_mask substringWithRange:NSMakeRange(range.location,l)], false );
            range.location += l;
            range.length -= l;
        }
    }
    
    return result;
}

bool BatchRename::BuildActionsScript( NSString *_mask )
{
    auto opt_decomposition = DecomposeMaskIntoPlaceholders( _mask );
    if( !opt_decomposition )
        return false;
    auto decomposition = move(opt_decomposition.value());

    bool ok = true;
    
    for(auto &di: decomposition) {
        if( !di.is_placeholder ) {
            m_Steps.emplace_back( ActionType::Static, m_ActionsStatic.size() );
            m_ActionsStatic.emplace_back( di.string );
        }
        else {
            if(!ParsePlaceholder(di.string)) {
                ok = false;
                break;
                
            }
        }
        
        
        
    }
    
    int a = 10;

    // need to clean action on failed parsing
    return ok;
}

bool BatchRename::ParsePlaceholder( NSString *_ph )
{
    const auto length = _ph.length;
    auto position = 0ul;

    while( position < length ) {
        auto c = [_ph characterAtIndex:position];
        switch (c) {
            case ' ':
                position++;
                continue;
            case '[':
                position++;
                m_Steps.emplace_back( ActionType::OpenBracket );
                continue;
            case ']':
                position++;
                m_Steps.emplace_back( ActionType::CloseBracket );
                continue;
            case 'U':
                position++;
                m_Steps.emplace_back( ActionType::Uppercase );
                continue;
            case 'L':
                position++;
                m_Steps.emplace_back( ActionType::Lowercase );
                continue;
            case 'F':
                position++;
                m_Steps.emplace_back( ActionType::Capitalized );
                continue;
            case 'n':
                position++;
                m_Steps.emplace_back( ActionType::UnchangedCase );
                continue;
            case 'A':
                position++;
                m_Steps.emplace_back( ActionType::Filename );
                continue;
            case 'N':
            {
                position++;
                auto v = ParsePlaceholder_TextExtraction(_ph, position);
                if( !v )
                    break;
                AddInsertName(v.value().first);
                position += v.value().second;
                continue;
            }
            case 'E':
            {
                position++;
                auto v = ParsePlaceholder_TextExtraction(_ph, position);
                if( !v )
                    break;
                AddInsertExtension(v.value().first);
                position += v.value().second;
                continue;
            }

        }
        return false;
    }
    
    return true;
}

// parsed short -> characters consumed
static optional<pair<unsigned short, short>> EatUShort( NSString *s, const unsigned long pos )
{
    const auto l = s.length;
    if( pos == l )
        return nullopt;
    auto n = 0ul;
    auto c = [s characterAtIndex:pos+n];
    if(c < '0' || c > '9')
        return nullopt;
    
    unsigned short r = 0;
    do {
        c = [s characterAtIndex:pos+n];
        if( c < '0' || c > '9' )
            break;
        r = r*10 + c - '0';
        n++;
    } while( pos+n < l );
    
    return make_pair(r, short(n));
}

//[N] old file name, WITHOUT extension
//[N1] The first character of the original name
//[N2-5] Characters 2 to 5 from the old name (totals to 4 characters). Double byte characters (e.g. Chinese, Japanese) are counted as 1 character! The first letter is accessed with '1'.
//[N2,5] 5 characters starting at character 2
//[N2-] All characters starting at character 2
//[N02-9] Characters 2-9, fill from left with zeroes if name shorter than requested (8 in this example): "abc" -> "000000bc"
//[N 2-9] Characters 2-9, fill from left with spaces if name shorter than requested (8 in this example): "abc" -> "      bc"
//[N-8,5] 5 characters starting at the 8-last character (counted from the end of the name)
//[N-8-5] Characters from the 8th-last to the 5th-last character
//[N-5-] Characters from the 5th-last character to the end of the name
//[N2--5] Characters from the 2nd to the 5th-last character
optional<pair<BatchRename::TextExtraction, int>> BatchRename::ParsePlaceholder_TextExtraction( NSString *_ph, unsigned long _pos )
{
//    static NSCharacterSet *myc = [NSCharacterSet characterSetWithCharactersInString:@"0123456789,- "];
    const auto l = _ph.length;
    if( l == _pos ) { // [N]
//        AddInsertName({});
        return make_pair( TextExtraction(), 0);
    }
    
    auto zero_flag = false, minus_flag = false, space_flag = false;
    
    auto n = 0;
    auto c = [_ph characterAtIndex:_pos + n];

    if( c == '0' ) {
        zero_flag = true;
        n++;
    }
    else if( c == '-' ) {
        minus_flag = true;
        n++;
    }
    else if( c == ' ') {
        space_flag = true;
        n++;
    }
    
    auto num_if = EatUShort( _ph, _pos + n );
    if( !num_if ) {
        if( n!=0 )
            return nullopt;
        return make_pair( TextExtraction(), n); // [N
    }
    else { // [N123....
        auto first_num = num_if.value().first;
        if(first_num < 1)
            return nullopt;
        first_num--;
        n += num_if.value().second;

        if( _pos+n == l ) { //  [N567]
            TextExtraction ins;
            ins.direct_range = Range(first_num, 1);
            return make_pair( ins, n);
        }

        c = [_ph characterAtIndex:_pos + n];
        if( !minus_flag ) { //[N5... or [N 5.... or [N05....
            if( c == '-' ) {
                n++;
                TextExtraction ins;
                num_if = EatUShort( _ph, _pos + n );
                if( num_if ) { // [N5-10
                    auto second_num = num_if.value().first;
                    if(second_num < 1)
                        return nullopt;
                    second_num--;
                    n += num_if.value().second;
                    ins.zero_flag = zero_flag;
                    ins.space_flag = space_flag;
                    ins.direct_range = Range(first_num, second_num >= first_num ? second_num - first_num + 1 : 0);
                }
                else { // [N5-
                    if( _pos+n == l ) { // [N5-]
                        ins.direct_range = Range(first_num, Range::max_length());
                    }
                    else {
                        c = [_ph characterAtIndex:_pos + n];
                        if( c != '-') { // [N5-something
                            ins.direct_range = Range(first_num, Range::max_length());
                        }
                        else { // N[5--
                            n++;
                            num_if = EatUShort( _ph, _pos + n );
                            if( !num_if )
                                return nullopt; // [N5--something <- invalid
                            
                            auto second_num = num_if.value().first; // [N5--3
                            if(second_num < 1)
                                return nullopt;
                            --second_num;
                            n += num_if.value().second;
                            
                            ins.direct_range = nullopt;
                            ins.from_first = first_num;
                            ins.to_last = second_num;
                        }
                    }
                }
                return make_pair( ins, n);
            }
            else if( c == ',' ) {
                n++;
                num_if = EatUShort( _ph, _pos + n );
                
                if(!num_if)  // [N5,  <- invalid
                    return nullopt;
                
                auto second_num = num_if.value().first; // [N5,10
                n += num_if.value().second;
                TextExtraction ins;
                ins.zero_flag = zero_flag;
                ins.space_flag = space_flag;
                ins.direct_range = Range(first_num, second_num);
                return make_pair( ins, n);
            }
            else { // [N123something
                TextExtraction ins;
                ins.direct_range = Range(first_num, 1);
                return make_pair( ins, n);
            }
        }
        else { // [N-5....
            if( c == '-' ) { // [N-5-...
                n++;
                TextExtraction ins;
                ins.direct_range = nullopt;
                
                num_if = EatUShort( _ph, _pos + n );
                if( !num_if ){ // [N-5-something
                    ins.reverse_range = Range(first_num, Range::max_length());
                }
                else { // [N-5-2
                    auto second_num = num_if.value().first;
                    if(second_num < 1)
                        return nullopt;
                    second_num--;
                    n += num_if.value().second;
                    ins.reverse_range = Range(first_num, second_num <= first_num ? first_num - second_num + 1 : 0);
                }
                return make_pair( ins, n);
            }
            else if( c == ',' ) { // [N-5,...
                n++;
                num_if = EatUShort( _ph, _pos + n );
                if(!num_if)
                    return nullopt; // [N-5,something <- invalid
                
                auto second_num = num_if.value().first; // [N-5,4
                n += num_if.value().second;
                
                TextExtraction ins;
                ins.direct_range = nullopt;
                ins.reverse_range = Range(first_num, second_num);
                return make_pair( ins, n);
            }
        }
    }
    
    
    return nullopt;
}


NSString *BatchRename::ExtractText(NSString *_from, const TextExtraction &_te)
{
    auto length = (unsigned short) _from.length;
    if( length == 0)
        return @"";
    
    if( _te.direct_range ) {
        auto rr = _te.direct_range.value();
        auto sr = Range(0, length);
        if( !sr.intersects( rr ) )
            return @"";
        
        auto res = sr.intersection( rr );
        auto str = [_from substringWithRange:res.toNSRange()];
        if((_te.zero_flag || _te.space_flag) &&
           rr.length != Range::max_length() &&
           str.length < rr.length) {
            auto insufficient = rr.length - str.length;
            if(insufficient > 300) insufficient = 300;
            
            auto padding = [@"" stringByPaddingToLength:insufficient withString:(_te.zero_flag ? @"0" : @" ") startingAtIndex:0];
            return [padding stringByAppendingString:str];
        }
        else {
            return str;
        }
    }
    else if( _te.reverse_range ) {
        auto rr = _te.reverse_range.value();
        auto sr = Range(0, length);
        if(rr.location + 1 > sr.length)
            rr.location = 0;
        else
            rr.location = sr.length - rr.location - 1;

        if( !sr.intersects(rr) )
            return @"";
        
        auto res = sr.intersection(rr);
        return [_from substringWithRange:res.toNSRange()];
    }
    else {
        if(_te.to_last + 1 >= length)
            return @"";
        unsigned start = _te.from_first;
        unsigned end = length - _te.to_last - 1;
        if(start > end)
            return @"";
        
        auto res = Range(start, end - start + 1);
        return [_from substringWithRange:res.toNSRange()];
    }
    
    return nil;
}

static inline NSString *StringByTransform(NSString *_s, BatchRename::CaseTransform _ct)
{
    switch (_ct) {
        case BatchRename::CaseTransform::Uppercase:
            return _s.uppercaseString;
        case BatchRename::CaseTransform::Lowercase:
            return _s.lowercaseString;
        case BatchRename::CaseTransform::Capitalized:
            return _s.capitalizedString;
        default:
            return _s;
    };
}

NSString *BatchRename::Rename( const FileInfo &_fi, int _number ) const
{
    NSMutableString *str = [[NSMutableString alloc] initWithCapacity:64];
    
    CaseTransform case_transform = CaseTransform::Unchanged;
    
    
    for(auto step: m_Steps) {
        NSString *next = nil;
        switch (step.type) {
            case ActionType::Static:
                next = m_ActionsStatic[step.index];
                break;
            case ActionType::Name:
                next = ExtractText(_fi.name, m_ActionsName[step.index]);
                break;
            case ActionType::Extension:
                next = ExtractText(_fi.extension, m_ActionsExtension[step.index]);
                break;
            case ActionType::OpenBracket:
                next = @"[";
                break;
            case ActionType::CloseBracket:
                next = @"]";
                break;
            case ActionType::Filename:
                next = _fi.filename;
                break;
            case ActionType::UnchangedCase:
                case_transform = CaseTransform::Unchanged;
                break;
            case ActionType::Uppercase:
                case_transform = CaseTransform::Uppercase;
                break;
            case ActionType::Lowercase:
                case_transform = CaseTransform::Lowercase;
                break;
            case ActionType::Capitalized:
                case_transform = CaseTransform::Capitalized;
                
            default:
                break;
        }
        
        if(next && next.length > 0) {
            next = StringByTransform(next, case_transform);
            [str appendString:next];
        }
    }
    
    return str;
}
