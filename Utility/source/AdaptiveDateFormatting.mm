// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AdaptiveDateFormatting.h"
#include <Cocoa/Cocoa.h>
#include <Habanero/spinlock.h>

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

namespace nc::utility {

AdaptiveDateFormatting::Style
    AdaptiveDateFormatting::StyleForWidthHardcodedLikeFinder( int _width, int _font_size )
{
    if( _font_size <= 10 ) {
        if( _width >= 166 )
            return Style::Long;
        else if( _width >= 124 )
            return Style::Medium;
        else if( _width >= 108 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else if( _font_size == 11 ) {
        if( _width >= 179 )
            return Style::Long;
        else if( _width >= 132 )
            return Style::Medium;
        else if( _width >= 116 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else if( _font_size == 12 ) {
        if( _width >= 190 )
            return Style::Long;
        else if( _width >= 141 )
            return Style::Medium;
        else if( _width >= 122 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else if( _font_size == 13 ) {
        if( _width >= 202 )
            return Style::Long;
        else if( _width >= 148 )
            return Style::Medium;
        else if( _width >= 129 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else if( _font_size == 14 ) {
        if( _width >= 213 )
            return Style::Long;
        else if( _width >= 156 )
            return Style::Medium;
        else if( _width >= 136 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else if( _font_size == 15 ) {
        if( _width >= 225 )
            return Style::Long;
        else if( _width >= 165 )
            return Style::Medium;
        else if( _width >= 143 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else if( _font_size == 16 ) {
        if( _width >= 236 )
            return Style::Long;
        else if( _width >= 172 )
            return Style::Medium;
        else if( _width >= 150 )
            return Style::Short;
        else
            return Style::Tiny;
    }
    else {
        // do some magic calculations here...
        
//    15      225     165    143   >0
//    16      236     172    150   >0
// intepolation scale:
//                 ~=/1.35 ~=/1.15
        const auto s = 236. / 16.;
        const auto v = s * _font_size;
        if( _width >= v )
            return Style::Long;
        else if( _width >= v / 1.35 )
            return Style::Medium;
        else if( _width >= v / (1.35 * 1.15) )
            return Style::Short;
        else
            return Style::Tiny;
    }
}

static bool TimeFormatIsDayFirst()
{
    // month is first overwise
    static const auto day_first = []{
        // a very-very nasty code here - trying to parse 
        // Unicode Technical Standard #35 stuff in a quite naive way
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

// disclaimer: CFDateFormatter is not thread safe, even for read-only usage, thus using spinlocks
// to control access. might need something more scaleable later.
// like having multiple instances (and locks) and choose them according current thread id

static NSString *Long( time_t _time )
{
    static const auto formatter = []{
        auto l = CFLocaleCopyCurrent();
        auto f = CFDateFormatterCreate(kCFAllocatorDefault,
                                       l,
                                       kCFDateFormatterLongStyle,
                                       kCFDateFormatterShortStyle);
        CFRelease(l);
        CFDateFormatterSetProperty(f,
                                   kCFDateFormatterDoesRelativeDateFormattingKey,
                                   kCFBooleanTrue);
        return f;
    }();
    const auto time = (double)_time - kCFAbsoluteTimeIntervalSince1970;    
    static spinlock formatter_lock;
    auto lock = std::lock_guard{formatter_lock};
    CFStringRef str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, formatter, time);
    return (NSString*)CFBridgingRelease(str);
}

static NSString *Medium( time_t _time )
{
    static const auto formatter = []{
        auto l = CFLocaleCopyCurrent();
        auto f = CFDateFormatterCreate(kCFAllocatorDefault,
                                       l,
                                       kCFDateFormatterMediumStyle,
                                       kCFDateFormatterShortStyle);
        CFRelease(l);
        CFDateFormatterSetProperty(f,
                                   kCFDateFormatterDoesRelativeDateFormattingKey,
                                   kCFBooleanTrue);
        return f;
    }();
    const auto time = (double)_time - kCFAbsoluteTimeIntervalSince1970;
    static spinlock formatter_lock;
    auto lock = std::lock_guard{formatter_lock};
    CFStringRef str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, formatter, time);
    return (NSString*)CFBridgingRelease(str);
}

static NSString *Short( time_t _time )
{
    static const auto formatter = []{
        auto l = CFLocaleCopyCurrent();
        auto f = CFDateFormatterCreate(kCFAllocatorDefault,
                                       l,
                                       kCFDateFormatterShortStyle,
                                       kCFDateFormatterShortStyle);
        CFRelease(l);
        CFDateFormatterSetProperty(f,
                                   kCFDateFormatterDoesRelativeDateFormattingKey,
                                   kCFBooleanTrue);
        return f;
    }();
    const auto time = (double)_time - kCFAbsoluteTimeIntervalSince1970;
    static spinlock formatter_lock;
    auto lock = std::lock_guard{formatter_lock};
    CFStringRef str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr, formatter, time);
    return (NSString*)CFBridgingRelease(str);
}

static NSString *Tiny( time_t _time )
{
    static const auto general = []{
        auto l = CFLocaleCopyCurrent();
        auto f = CFDateFormatterCreate(kCFAllocatorDefault,
                                       l,
                                       kCFDateFormatterShortStyle,
                                       kCFDateFormatterNoStyle);
        CFRelease(l);
        CFDateFormatterSetProperty(f,
                                   kCFDateFormatterDoesRelativeDateFormattingKey,
                                   kCFBooleanTrue);
        return f;
    }();
    static const auto today = []{
        auto l = CFLocaleCopyCurrent();
        auto f = CFDateFormatterCreate(kCFAllocatorDefault,
                                       l,
                                       kCFDateFormatterNoStyle,
                                       kCFDateFormatterShortStyle);
        CFRelease(l);
        CFDateFormatterSetProperty(f,
                                   kCFDateFormatterDoesRelativeDateFormattingKey,
                                   kCFBooleanTrue);
        return f;
    }();
    const auto date = [NSDate dateWithTimeIntervalSince1970:_time];
    const auto is_today = [NSCalendar.currentCalendar isDateInToday:date];
    const auto time = (double)_time - kCFAbsoluteTimeIntervalSince1970;
    static spinlock formatter_lock;
    auto lock = std::lock_guard{formatter_lock};
    auto str = CFDateFormatterCreateStringWithAbsoluteTime(nullptr,
                                                           is_today ? today : general,
                                                           time);
    return (NSString*)CFBridgingRelease(str);
}

NSString *AdaptiveDateFormatting::Format( Style _style, time_t _time )
{
    switch( _style ) {
        case Style::Long:   return Long( _time );
        case Style::Medium: return Medium( _time );
        case Style::Short:  return Short( _time );
        case Style::Tiny:   return Tiny( _time );
        default:            return Orthodox( _time );
    }
}

AdaptiveDateFormatting::Style
    AdaptiveDateFormatting::SuitableStyleForWidth( int _width, NSFont *_font )
{
    return StyleForWidthHardcodedLikeFinder( _width, (int)_font.pointSize );
}

}
