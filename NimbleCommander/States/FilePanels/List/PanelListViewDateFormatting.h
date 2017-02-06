#pragma once

class PanelListViewDateFormatting
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
    static NSString *Format( Style _style, time_t _time );
    static Style SuitableStyleForWidth( int _width, NSFont *_font );
    
};
