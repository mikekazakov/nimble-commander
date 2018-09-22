// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>

namespace nc::utility {

class AdaptiveDateFormatting
{
public:
    
    enum class Style : char {
        Orthodox    = 0,
        Long        = 1,
        Medium      = 2,
        Short       = 3,
        Tiny        = 4
    };
    
    /**
     * May return nil!
     */
    NSString *Format( Style _style, time_t _time );

    Style SuitableStyleForWidth( int _width, NSFont *_font );
    
private:
    static Style StyleForWidthHardcodedLikeFinder( int _width, int _font_size );    
    
};

}
