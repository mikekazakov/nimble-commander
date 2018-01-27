// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/Core/VFSInstancePromise.h>

// TODO: extract favorite and location
#include "../Favorites.h"

struct NativeFileSystemInfo;

namespace nc::panel {
    class ListingPromise;
}

namespace nc::panel::loc_fmt {
    
class Formatter {
public:
    struct Representation {
        NSString    *menu_title;
        NSString    *menu_tooltip;
        NSImage     *menu_icon;
    };

    enum RenderOptions {
        RenderMenuTitle     =  1,
        RenderMenuIcon      =  2,
        RenderMenuTooltip   =  4,
        RenderEverything    = -1,
        RenderNothing       =  0
    };

};

    
class ListingPromiseFormatter : public Formatter {
public:
    
    Representation Render( RenderOptions _options, const ListingPromise &_promise );
    
};

    
class FavoriteLocationFormatter : public Formatter {
public:
    
    FavoriteLocationFormatter(const NetworkConnectionsManager &_conn_mgr);
    
    Representation Render(RenderOptions _options,
                          const FavoriteLocationsStorage::Location &_location );
    
private:
    const NetworkConnectionsManager &m_NetworkConnectionsManager;
};
    
    
class FavoriteFormatter : public Formatter {
public:
    FavoriteFormatter(const NetworkConnectionsManager &_conn_mgr);
    
    Representation Render(RenderOptions _options,
                          const FavoriteLocationsStorage::Favorite &_favorite );

private:
    const NetworkConnectionsManager &m_NetworkConnectionsManager;
};

    
class NetworkConnectionFormatter : public Formatter {
public:

    Representation Render(RenderOptions _options,
                          const NetworkConnectionsManager::Connection &_connection );
    
};
    

class VolumeFormatter : public Formatter {
public:
  
    Representation Render(RenderOptions _options,
                          const NativeFileSystemInfo &_volume );
    
};

    
class VFSPromiseFormatter : public Formatter {
public:
    
    Representation Render(RenderOptions _options,
                          const core::VFSInstancePromise &_promise,
                          const string &_path);
    
};

    
class VFSPathFormatter : public Formatter {
public:
        
    Representation Render(RenderOptions _options,
                          const VFSHost &_vfs,
                          const string &_path);
        
};
    
};
