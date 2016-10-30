#include "PanelListViewDateFormatting.h"

// Finder (10.12) heuristics for min column width:
// Font Size  Long  Medium  Short  Tiny
//    10      166     124    108   >0
//    11      179     132    116   >0
//    12      190     141    122   >0
//    13      202     148    129   >0
//    14      213     156    136   >0
//    15      225     165    143   >0
//    16      236     172    150   >0
// intepolation scale:
//                 ~=/1.35 ~=/1.15

static PanelListViewDateFormatting::Style StyleForWidthHardcodedLikeFinder( int _width, int _font_size )
{
    if( _font_size <= 10 ) {
        if( _width >= 166 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 124 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 108 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else if( _font_size == 11 ) {
        if( _width >= 179 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 132 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 116 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else if( _font_size == 12 ) {
        if( _width >= 190 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 141 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 122 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else if( _font_size == 13 ) {
        if( _width >= 202 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 148 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 129 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else if( _font_size == 14 ) {
        if( _width >= 213 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 156 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 136 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else if( _font_size == 15 ) {
        if( _width >= 225 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 165 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 143 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else if( _font_size == 16 ) {
        if( _width >= 236 )
            return PanelListViewDateFormatting::Style::Long;
        else if( _width >= 172 )
            return PanelListViewDateFormatting::Style::Medium;
        else if( _width >= 150 )
            return PanelListViewDateFormatting::Style::Short;
        else
            return PanelListViewDateFormatting::Style::Tiny;
    }
    else {
        // do some magic calculations here... later
        assert( "write me!!" == 0 );
        return PanelListViewDateFormatting::Style::Long;
    }
}

static bool TimeFormatIsDayFirst()
{
    // month is first overwise
    static const auto day_first = []{
        // a very-very nasty code here - trying to parse Unicode Technical Standard #35 stuff in a quite naive way
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
        
        NSString *format = dateFormatter.dateFormat;
        const char *s = format.UTF8String;
        
        const char *m = strstr(s, "MM");
        if(m == nullptr)
            m = strstr(s, "M");
        
        const char *d = strstr(s, "dd");
        if(d == nullptr)
            d = strstr(s, "d");
        
        if(m < d)
            return false;
        return true;
    }();
    
    return day_first;
}

static NSString *Orthodox( time_t _time )
{
    static const auto formatter = []{
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.dateFormat = TimeFormatIsDayFirst() ? @"dd/LL/yy HH:mm" : @"LL/dd/yy HH:mm";
        return f;
    }();
    
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_time]];
}

static NSString *Long( time_t _time )
{
    static const auto formatter = []{
        auto f =  CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterLongStyle, kCFDateFormatterShortStyle);
        CFDateFormatterSetProperty(f, kCFDateFormatterDoesRelativeDateFormattingKey, kCFBooleanTrue);
        return f;
    }();
    
    CFStringRef str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, formatter, (double)_time - kCFAbsoluteTimeIntervalSince1970);
    return (NSString*)CFBridgingRelease(str);
}

static NSString *Medium( time_t _time )
{
    static const auto formatter = []{
        auto f =  CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterMediumStyle, kCFDateFormatterShortStyle);
        CFDateFormatterSetProperty(f, kCFDateFormatterDoesRelativeDateFormattingKey, kCFBooleanTrue);
        return f;
    }();
    
    CFStringRef str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, formatter, (double)_time - kCFAbsoluteTimeIntervalSince1970);
    return (NSString*)CFBridgingRelease(str);
}

static NSString *Short( time_t _time )
{
    static const auto formatter = []{
        auto f =  CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterShortStyle, kCFDateFormatterShortStyle);
        CFDateFormatterSetProperty(f, kCFDateFormatterDoesRelativeDateFormattingKey, kCFBooleanTrue);
        return f;
    }();
    
    CFStringRef str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, formatter, (double)_time - kCFAbsoluteTimeIntervalSince1970);
    return (NSString*)CFBridgingRelease(str);
}

static NSString *Tiny( time_t _time )
{
    static const auto general = []{
        auto f =  CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterShortStyle, kCFDateFormatterNoStyle);
        CFDateFormatterSetProperty(f, kCFDateFormatterDoesRelativeDateFormattingKey, kCFBooleanTrue);
        return f;
    }();
    static const auto today = []{
        auto f =  CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
        CFDateFormatterSetProperty(f, kCFDateFormatterDoesRelativeDateFormattingKey, kCFBooleanTrue);
        return f;
    }();
    
    const auto is_today = [NSCalendar.currentCalendar isDateInToday:[NSDate dateWithTimeIntervalSince1970:_time]];
    auto str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, is_today ? today : general, (double)_time - kCFAbsoluteTimeIntervalSince1970);
    return (NSString*)CFBridgingRelease(str);
}

NSString *PanelListViewDateFormatting::Format( Style _style, time_t _time )
{
    switch( _style ) {
        case Style::Long:   return Long( _time );
        case Style::Medium: return Medium( _time );
        case Style::Short:  return Short( _time );
        case Style::Tiny:   return Tiny( _time );
        default:            return Orthodox( _time );
    }
}

PanelListViewDateFormatting::Style PanelListViewDateFormatting::SuitableStyleForWidth( int _width, NSFont *_font )
{
    return StyleForWidthHardcodedLikeFinder( _width, _font.pointSize );
}
