#pragma once

namespace nc::term {

struct TranslateMaps {
    enum {
        Lat1    = 0,
        Graph   = 1,
        IBMPC   = 2,
        User    = 3
    };
};
    
extern const unsigned short g_TranslateMaps[4][256];

}
