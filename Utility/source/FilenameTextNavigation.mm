// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FilenameTextNavigation.h"

NSCharacterSet * const FilenameTextNavigation::DefaultStopCharacters  =
    [NSCharacterSet characterSetWithCharactersInString:@" .,-_/\\"];

unsigned long FilenameTextNavigation::NavigateToNextWord(NSString *_string,
                                        unsigned long _location,
                                        NSCharacterSet *_stop_chars)
{
    if( _string == nullptr )
        return 0;
    
    const auto length = _string.length;
    if( length == 0 )
        return 0;
    if( _location >= length )
        return _location;
    
    const auto current_character = [_string characterAtIndex:_location];
    while( _location < length ) {
        const auto search_range = NSMakeRange(_location + 1, length - _location - 1);
        const auto result = [_string rangeOfCharacterFromSet:_stop_chars
                                                     options:0
                                                       range:search_range];
        if( result.location == NSNotFound ) {
            return length;
        }
        else {
            if( result.location == _location + 1 &&
               [_string characterAtIndex:result.location] == current_character ) {
                _location++;
                continue;
            }
            return result.location;
        }
    }
    return _location;
}

unsigned long FilenameTextNavigation::NavigateToPreviousWord(NSString *_string,
                                                             unsigned long _location,
                                                             NSCharacterSet *_stop_chars)
{
    if( _string == nullptr )
        return 0;
    
    const auto length = _string.length;
    if( length == 0 )
        return 0;
    
    if( _location == 0 )
        return _location;
    if( _location > length )
        return length;
    
    const auto current_character = [_string characterAtIndex:_location-1];
    while( _location > 0 ) {
        const auto search_range = NSMakeRange(0, _location - 1);
        const auto result = [_string rangeOfCharacterFromSet:_stop_chars
                                                     options:NSBackwardsSearch
                                                       range:search_range];
        if( result.location == NSNotFound ) {
            return 0;
        }
        else {
            if( result.location == _location - 2 &&
               [_string characterAtIndex:result.location] == current_character ) {
                _location--;
                continue;
            }
            return result.location + 1;
        }
    }
    return _location;
}
