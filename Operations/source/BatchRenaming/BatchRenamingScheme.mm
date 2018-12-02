// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BatchRenamingScheme.h"

namespace nc::ops {

std::optional<std::vector<BatchRenamingScheme::MaskDecomposition>>
BatchRenamingScheme::DecomposeMaskIntoPlaceholders(NSString *_mask)
{
    static NSCharacterSet *open_br = [NSCharacterSet characterSetWithCharactersInString:@"["];
    static NSCharacterSet *close_br = [NSCharacterSet characterSetWithCharactersInString:@"]"];
    assert(_mask != nil);
    
    std::vector<BatchRenamingScheme::MaskDecomposition> result;
    auto length = _mask.length;
    auto range = NSMakeRange(0, length);
    while( range.length > 0 ) {
        
        auto open_r = [_mask rangeOfCharacterFromSet:open_br options:0 range:range];
        if( open_r.location == range.location ) {
            // this part starts with placeholder
            auto close_r = [_mask rangeOfCharacterFromSet:close_br options:0 range:NSMakeRange(range.location+1, range.length-1)];
            if( close_r.location == NSNotFound )
                return std::nullopt; // invalid mask
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
                return std::nullopt; // invalid mask
            result.emplace_back( [_mask substringWithRange:range], false );
            break;
        }
        else {
            // we have placeholder somewhere further
            auto close_r = [_mask rangeOfCharacterFromSet:close_br options:0 range:range];
            if( close_r.location == NSNotFound ||
               close_r.location < open_r.location )
                return std::nullopt; // invalid mask
            auto l = open_r.location-range.location;
            result.emplace_back( [_mask substringWithRange:NSMakeRange(range.location,l)], false );
            range.location += l;
            range.length -= l;
        }
    }
    
    return result;
}

bool BatchRenamingScheme::BuildActionsScript( NSString *_mask )
{
    if(!_mask || !_mask.length)
        return false;
    
    auto opt_decomposition = DecomposeMaskIntoPlaceholders( _mask );
    if( !opt_decomposition )
        return false;
    auto decomposition = move(*opt_decomposition);

    bool ok = true;
    
    for(auto &di: decomposition) {
        if( !di.is_placeholder ) {
            AddStaticText(di.string);
        }
        else {
            if(!ParsePlaceholder(di.string)) {
                ok = false;
                break;
                
            }
        }
        
        
        
    }

    // need to clean action on failed parsing
    return ok;
}

bool BatchRenamingScheme::ParsePlaceholder( NSString *_ph )
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
            case 's':
                position++;
                m_Steps.emplace_back( ActionType::TimeSeconds );
                continue;
            case 'm':
                position++;
                m_Steps.emplace_back( ActionType::TimeMinutes );
                continue;
            case 'h':
                position++;
                m_Steps.emplace_back( ActionType::TimeHours );
                continue;
            case 'D':
                position++;
                m_Steps.emplace_back( ActionType::TimeDay );
                continue;
            case 'M':
                position++;
                m_Steps.emplace_back( ActionType::TimeMonth );
                continue;
            case 'y':
                position++;
                m_Steps.emplace_back( ActionType::TimeYear2 );
                continue;
            case 'Y':
                position++;
                m_Steps.emplace_back( ActionType::TimeYear4 );
                continue;
            case 'd':
                position++;
                m_Steps.emplace_back( ActionType::Date );
                continue;
            case 't':
                position++;
                m_Steps.emplace_back( ActionType::Time );
                continue;
            case 'N':
            {
                position++;
                auto v = ParsePlaceholder_TextExtraction(_ph, position);
                if( !v )
                    break;
                AddInsertName(v->first);
                position += v->second;
                continue;
            }
            case 'E':
            {
                position++;
                auto v = ParsePlaceholder_TextExtraction(_ph, position);
                if( !v )
                    break;
                AddInsertExtension(v->first);
                position += v->second;
                continue;
            }
            case 'C':
            {
                position++;
                auto v = ParsePlaceholder_Counter(_ph, position, m_DefaultCounter.start, m_DefaultCounter.step, m_DefaultCounter.width,     m_DefaultCounter.stripe);
                if( !v )
                    break;
                AddInsertCounter(v->first);
                position += v->second;
                continue;
            }
        }
        return false;
    }
    
    return true;
}

// parsed short -> characters consumed
static std::optional<std::pair<unsigned short, short>> EatUShort( NSString *s, const unsigned long pos )
{
    const auto l = s.length;
    if( pos == l )
        return std::nullopt;
    auto n = 0ul;
    auto c = [s characterAtIndex:pos+n];
    if(c < '0' || c > '9')
        return std::nullopt;
    
    unsigned short r = 0;
    do {
        c = [s characterAtIndex:pos+n];
        if( c < '0' || c > '9' )
            break;
        r = r*10 + c - '0';
        n++;
    } while( pos+n < l );
    
    return std::make_pair(r, short(n));
}

// parsed short -> characters consumed
static std::optional<std::pair<int, short>> EatInt( NSString *s, const unsigned long pos )
{
    const auto l = s.length;
    if( pos == l )
        return std::nullopt;

    auto n = 0ul;
    bool minus = false;
    
    auto c = [s characterAtIndex:pos+n];
    if( c == '-' ) {
        minus = true;
        n++;
    }

    if( pos+n == l )
        return std::nullopt;
    
    c = [s characterAtIndex:pos+n];
    if(c < '0' || c > '9')
        return std::nullopt;
    
    int r = 0;
    do {
        c = [s characterAtIndex:pos+n];
        if( c < '0' || c > '9' )
            break;
        r = r*10 + c - '0';
        n++;
    } while( pos+n < l );
    
    return std::make_pair(r * (minus ? -1 : 1), short(n));
}

static std::optional<std::pair<int, short>> EatIntWithPreffix( NSString *s, const unsigned long pos, char prefix )
{
    const auto l = s.length;
    auto n = 0;
    if( n+pos == l )
        return std::nullopt;
    
    auto c = [s characterAtIndex:pos + n];
    if( c != prefix )
        return std::nullopt;
    
    n++;
    auto num_if = EatInt( s, pos + n );
    if(!num_if)
        return std::nullopt;
    
    return std::make_pair(num_if->first, short(num_if->second+1));
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
std::optional<std::pair<BatchRenamingScheme::TextExtraction, int>> BatchRenamingScheme::ParsePlaceholder_TextExtraction( NSString *_ph, unsigned long _pos )
{
//    static NSCharacterSet *myc = [NSCharacterSet characterSetWithCharactersInString:@"0123456789,- "];
    const auto l = _ph.length;
    if( l == _pos ) // [N]
        return std::make_pair( TextExtraction(), 0);
    
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
            return std::nullopt;
        return std::make_pair( TextExtraction(), n); // [N
    }
    else { // [N123....
        auto first_num = num_if->first;
        if(first_num < 1)
            return std::nullopt;
        first_num--;
        n += num_if->second;

        if( _pos+n == l ) { //  [N567]
            TextExtraction ins;
            ins.direct_range = Range(first_num, 1);
            return std::make_pair( ins, n);
        }

        c = [_ph characterAtIndex:_pos + n];
        if( !minus_flag ) { //[N5... or [N 5.... or [N05....
            if( c == '-' ) {
                n++;
                TextExtraction ins;
                num_if = EatUShort( _ph, _pos + n );
                if( num_if ) { // [N5-10
                    auto second_num = num_if->first;
                    if(second_num < 1)
                        return std::nullopt;
                    second_num--;
                    n += num_if->second;
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
                                return std::nullopt; // [N5--something <- invalid
                            
                            auto second_num = num_if->first; // [N5--3
                            if(second_num < 1)
                                return std::nullopt;
                            --second_num;
                            n += num_if->second;
                            
                            ins.direct_range = std::nullopt;
                            ins.from_first = first_num;
                            ins.to_last = second_num;
                        }
                    }
                }
                return std::make_pair( ins, n);
            }
            else if( c == ',' ) {
                n++;
                num_if = EatUShort( _ph, _pos + n );
                
                if(!num_if)  // [N5,  <- invalid
                    return std::nullopt;
                
                auto second_num = num_if->first; // [N5,10
                n += num_if->second;
                TextExtraction ins;
                ins.zero_flag = zero_flag;
                ins.space_flag = space_flag;
                ins.direct_range = Range(first_num, second_num);
                return std::make_pair( ins, n);
            }
            else { // [N123something
                TextExtraction ins;
                ins.direct_range = Range(first_num, 1);
                return std::make_pair( ins, n);
            }
        }
        else { // [N-5....
            if( c == '-' ) { // [N-5-...
                n++;
                TextExtraction ins;
                ins.direct_range = std::nullopt;
                
                num_if = EatUShort( _ph, _pos + n );
                if( !num_if ){ // [N-5-something
                    ins.reverse_range = Range(first_num, Range::max_length());
                }
                else { // [N-5-2
                    auto second_num = num_if->first;
                    if(second_num < 1)
                        return std::nullopt;
                    second_num--;
                    n += num_if->second;
                    ins.reverse_range = Range(first_num, second_num <= first_num ? first_num - second_num + 1 : 0);
                }
                return std::make_pair( ins, n);
            }
            else if( c == ',' ) { // [N-5,...
                n++;
                num_if = EatUShort( _ph, _pos + n );
                if(!num_if)
                    return std::nullopt; // [N-5,something <- invalid
                
                auto second_num = num_if->first; // [N-5,4
                n += num_if->second;
                
                TextExtraction ins;
                ins.direct_range = std::nullopt;
                ins.reverse_range = Range(first_num, second_num);
                return std::make_pair( ins, n);
            }
        }
    }
    
    
    return std::nullopt;
}

// maximum possible construction: [C10+1/15:5]
//[C] Paste counter, as defined in Define counter field
//[C10+5:3] Paste counter, define counter settings directly. In this example, start at 10, step by 5, use 3 digits width.
//Partial definitions like [C10] or [C+5] or [C:3] are also accepted.
//Hint: The fields in Define counter will be ignored if you specify options directly in the [C] field.
//[C+1/100] New: Fractional number: Paste counter, but increase it only every n files (in this example: every 100 files).
//Can be used to move a specific number of files to a subdirectory,e.g. [C+1/100]\[N]

// not yet:
//[Caa+1] Paste counter, define counter settings directly. In this example, start at aa, step 1 letter, use 2 digits (defined by 'aa' width)
//[C:a] Paste counter, determine digits width automatically, depending on the number of files. Combinations like [C10+10:a] are also allowed.
std::optional<std::pair<BatchRenamingScheme::Counter, int>> BatchRenamingScheme::ParsePlaceholder_Counter( NSString *_ph, unsigned long _pos,
                                                                                long _default_start, long _default_step, int _default_width, unsigned _default_stripe)
{
    Counter counter;
    counter.start = _default_start;
    counter.step = _default_step;
    counter.width = _default_width;
    counter.stripe = _default_stripe;
    
    const auto l = _ph.length;
    if( l == _pos ) // [C]
        return std::make_pair( counter, 0);
    
    auto n = 0;
    if( auto start = EatInt(_ph, _pos+n) ) {
        counter.start = start->first;
        n += start->second;
    }
    if( auto step = EatIntWithPreffix(_ph, _pos+n, '+') ) {
        counter.step = step->first;
        n += step->second;
    }
    if( auto stripe = EatIntWithPreffix(_ph, _pos+n, '/') ) {
        counter.stripe = stripe->first;
        n += stripe->second;
    }
    if( auto width = EatIntWithPreffix(_ph, _pos+n, ':') ) {
        counter.width = width->first;
        if(counter.width > 30)
            counter.width = 30;
        n += width->second;
    }
    
    return std::make_pair(counter, n);
}

NSString *BatchRenamingScheme::ExtractText(NSString *_from, const TextExtraction &_te)
{
    auto length = (unsigned short) _from.length;
    if( length == 0)
        return @"";
    
    if( _te.direct_range ) {
        auto rr = *_te.direct_range;
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
        auto rr = *_te.reverse_range;
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

NSString *BatchRenamingScheme::FormatCounter(const Counter &_c, int _file_number)
{
    if(_c.stripe == 0)
        return @"";
    
    char *buf = (char*)alloca(_c.width + 32); // no heap allocs, for great justice!
    if(!buf)
        return @"";
    
    sprintf( buf, "%0*ld", _c.width,  _c.start + _c.step*(_file_number / _c.stripe) );
    return [NSString stringWithUTF8String:buf];
}

void BatchRenamingScheme::SetReplacingOptions( NSString *_search_for, NSString *_replace_with, bool _case_sensitive, bool _only_first, bool _search_in_ext, bool _use_regexp)
{
    m_SearchReplace.search_for = _search_for;
    m_SearchReplace.replace_with = _replace_with;
    m_SearchReplace.case_sensitive = _case_sensitive;
    m_SearchReplace.only_first = _only_first;
    m_SearchReplace.search_in_ext = _search_in_ext;
    m_SearchReplace.use_regexp = _use_regexp;
}

void BatchRenamingScheme::SetDefaultCounter(long _start, long _step, unsigned _stripe, unsigned _width)
{
    m_DefaultCounter.start = _start;
    m_DefaultCounter.step = _step;
    m_DefaultCounter.stripe = _stripe;
    m_DefaultCounter.width = _width;
}

void BatchRenamingScheme::SetCaseTransform(CaseTransform _ct, bool _apply_to_ext)
{
    m_CaseTransform = _ct;
    m_CaseTransformWithExt = _apply_to_ext;
}

static inline NSString *StringByTransform(NSString *_s, BatchRenamingScheme::CaseTransform _ct)
{
    switch (_ct) {
        case BatchRenamingScheme::CaseTransform::Uppercase:
            return _s.uppercaseString;
        case BatchRenamingScheme::CaseTransform::Lowercase:
            return _s.lowercaseString;
        case BatchRenamingScheme::CaseTransform::Capitalized:
            return _s.capitalizedString;
        default:
            return _s;
    };
}

static NSString *StringByTransform(NSString *_s, BatchRenamingScheme::CaseTransform _ct, bool _apply_to_ext)
{
    if(_apply_to_ext)
        return StringByTransform(_s, _ct);
    
    if(_ct == BatchRenamingScheme::CaseTransform::Unchanged)
        return _s;
    
    static auto cs = [NSCharacterSet characterSetWithCharactersInString:@"."];
    auto r = [_s rangeOfCharacterFromSet:cs options:NSBackwardsSearch];
    bool has_ext = (r.location != NSNotFound && r.location != 0 && r.location != _s.length - 1);
    if(!has_ext)
        return StringByTransform(_s, _ct);
    
    NSString *name = [_s substringWithRange:NSMakeRange(0, r.location)];
    NSString *extension = [_s substringWithRange:NSMakeRange(r.location, _s.length - r.location)];
  
    return [StringByTransform(name, _ct) stringByAppendingString:extension];
}

static NSString* FormatTimeSeconds(const struct tm &_t)
{
    char buf[16];
    sprintf(buf, "%2.2d", _t.tm_sec);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatTimeMinutes(const struct tm &_t)
{
    char buf[16];
    sprintf(buf, "%2.2d", _t.tm_min);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatTimeHours(const struct tm &_t)
{
    char buf[16];
    sprintf(buf, "%2.2d", _t.tm_hour);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatTimeDay(const struct tm &_t)
{
    char buf[16];
    sprintf(buf, "%2.2d", _t.tm_mday);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatTimeMonth(const struct tm &_t)
{
    char buf[16];
    sprintf(buf, "%2.2d", _t.tm_mon + 1);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatTimeYear2(const struct tm &_t)
{
    char buf[16];
    if(_t.tm_year >= 100)
        sprintf(buf, "%2.2d", _t.tm_year - 100);
    else
        sprintf(buf, "%2.2d", _t.tm_year);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatTimeYear4(const struct tm &_t)
{
    char buf[16];
    sprintf(buf, "%4.4d", _t.tm_year + 1900);
    return [NSString stringWithUTF8String:buf];
}

static NSString* FormatDate(time_t _t)
{
    static auto formatter = []() {
        NSDateFormatter *fmt = [NSDateFormatter new];
        fmt.dateStyle = NSDateFormatterShortStyle;
        fmt.timeStyle = NSDateFormatterNoStyle;
        return fmt;
    }();
    
    NSMutableString *str = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_t]].mutableCopy;
    [str replaceOccurrencesOfString:@"/" withString:@"-" options:0 range:NSMakeRange(0,str.length)];
    [str replaceOccurrencesOfString:@"\\" withString:@"-" options:0 range:NSMakeRange(0,str.length)];
    [str replaceOccurrencesOfString:@":" withString:@"-" options:0 range:NSMakeRange(0,str.length)];
    return str;
}

static NSString* FormatTime(time_t _t)
{
    static auto formatter = []() {
        NSDateFormatter *fmt = [NSDateFormatter new];
        fmt.dateStyle = NSDateFormatterNoStyle;
        fmt.timeStyle = NSDateFormatterShortStyle;
        return fmt;
    }();
    
    NSMutableString *str = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_t]].mutableCopy;
    [str replaceOccurrencesOfString:@"/" withString:@"." options:0 range:NSMakeRange(0,str.length)];
    [str replaceOccurrencesOfString:@"\\" withString:@"." options:0 range:NSMakeRange(0,str.length)];
    [str replaceOccurrencesOfString:@":" withString:@"." options:0 range:NSMakeRange(0,str.length)];
    return str;
}

NSString *BatchRenamingScheme::DoSearchReplace(const ReplaceOptions &_opts, NSString *_source)
{
    if(_opts.search_for == nil || _opts.search_for.length == 0 || _opts.replace_with == nil )
        return _source;
    
    NSStringCompareOptions opts = 0;
    
    if(!_opts.case_sensitive) opts |= NSCaseInsensitiveSearch;
    if(_opts.use_regexp)      opts |= NSRegularExpressionSearch;
    
    NSRange range = NSMakeRange(0, _source.length);
    if(!_opts.search_in_ext) {
        static auto cs = [NSCharacterSet characterSetWithCharactersInString:@"."];
        auto r = [_source rangeOfCharacterFromSet:cs options:NSBackwardsSearch];
        bool has_ext = (r.location != NSNotFound && r.location != 0 && r.location != _source.length - 1);
        if(has_ext)
            range = NSMakeRange(0, r.location);
    }
    
    
    NSString *result = _source;
    if(!_opts.only_first) {
        result = [_source stringByReplacingOccurrencesOfString:_opts.search_for
                                                    withString:_opts.replace_with
                                                       options:opts
                                                         range:range];
    }
    else {
        auto r = [_source rangeOfString:_opts.search_for options:opts range:range];
        if(r.location != NSNotFound)
            result = [_source stringByReplacingCharactersInRange:r withString:_opts.replace_with];
    }
    
    return result;
}

NSString *BatchRenamingScheme::Rename( const FileInfo &_fi, int _number ) const
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
            case ActionType::Counter:
                next = FormatCounter(m_ActionsCounter[step.index], _number);
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
            case ActionType::TimeSeconds:
                next = FormatTimeSeconds(_fi.mod_time_tm);
                break;
            case ActionType::TimeMinutes:
                next = FormatTimeMinutes(_fi.mod_time_tm);
                break;
            case ActionType::TimeHours:
                next = FormatTimeHours(_fi.mod_time_tm);
                break;
            case ActionType::TimeDay:
                next = FormatTimeDay(_fi.mod_time_tm);
                break;
            case ActionType::TimeMonth:
                next = FormatTimeMonth(_fi.mod_time_tm);
                break;
            case ActionType::TimeYear2:
                next = FormatTimeYear2(_fi.mod_time_tm);
                break;
            case ActionType::TimeYear4:
                next = FormatTimeYear4(_fi.mod_time_tm);
                break;
            case ActionType::Date:
                next = FormatDate(_fi.mod_time);
                break;
            case ActionType::Time:
                next = FormatTime(_fi.mod_time);
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
    
    NSString *after_replacing = DoSearchReplace(m_SearchReplace, str);
    NSString *after_case_trans= StringByTransform(after_replacing, m_CaseTransform, m_CaseTransformWithExt);
    return after_case_trans;
}

}
