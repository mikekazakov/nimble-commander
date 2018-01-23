// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel {
    class ListingPromise;
}

namespace nc::panel::loc_fmt {
    
class Formatter {
public:
    struct Representation {
        NSString    *menu_title;
        NSImage     *menu_icon;
    };

    enum RenderOptions {
        RenderMenuTitle     =  1,
        RenderMenuIcon      =  2,
        RenderEverything    = -1,
        RenderNothing       =  0
    };
};
    
class ListingPromiseFormatter : public Formatter {
public:
    
    Representation Render( RenderOptions _options, const ListingPromise &_promise );
    
};

};
