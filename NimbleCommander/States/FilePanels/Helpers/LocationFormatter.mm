// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "LocationFormatter.h"
#include "../ListingPromise.h"
#include <compose_visitors.hpp>
#include <VFS/Native.h>
#include <NimbleCommander/Core/NetworkConnectionIconProvider.h>
#include "../PanelDataPersistency.h"
#include <Utility/NativeFSManager.h>

namespace nc::panel::loc_fmt {

static const auto g_IconSize = NSMakeSize(16, 16);
    
static NSImage *ImageForPromiseAndPath(const core::VFSInstancePromise &_promise,
                                       const string& _path );
static NSImage* ImageForLocation(const PersistentLocation &_location,
                                 const NetworkConnectionsManager &_conn_mgr);
static NSImage* ImageForVFSPath(const VFSHost &_vfs,
                                const string &_path);
static NSString *NonNull(NSString *_string);
    
ListingPromiseFormatter::Representation
ListingPromiseFormatter::Render( RenderOptions _options, const ListingPromise &_promise )
{
    Representation rep;
    
    const auto visitor = compose_visitors
    (
     [&](const ListingPromise::UniformListing &l) {
         if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
             const auto title = l.promise.verbose_title() + l.directory;
             rep.menu_title = NonNull([NSString stringWithUTF8StdString:title]);
             rep.menu_tooltip = rep.menu_title;
         }
         if( _options & RenderMenuIcon )
             rep.menu_icon = ImageForPromiseAndPath(l.promise, l.directory);
     },
     [&](const ListingPromise::NonUniformListing &l)
     {
         if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
             static const auto formatter = []{
                 auto fmt = [[NSNumberFormatter alloc] init];
                 fmt.usesGroupingSeparator = true;
                 fmt.groupingSize = 3;
                 return fmt;
             }();
             
             const auto count = [NSNumber numberWithUnsignedInteger:l.EntriesCount()];
             rep.menu_title = [NSString stringWithFormat:@"Temporary Panel (%@)",
                               [formatter stringFromNumber:count]];
             rep.menu_tooltip = rep.menu_title;
         }
     }
     );
    boost::apply_visitor(visitor, _promise.Description());

    return rep;
}

FavoriteLocationFormatter::FavoriteLocationFormatter(const NetworkConnectionsManager &_conn_mgr):
    m_NetworkConnectionsManager(_conn_mgr)
{
}
    
FavoriteLocationFormatter::Representation
FavoriteLocationFormatter::Render(RenderOptions _options,
                                  const FavoriteLocationsStorage::Location &_location )
{
    Representation rep;

    if( _options & RenderMenuTitle )
        rep.menu_title = NonNull([NSString stringWithUTF8StdString:_location.verbose_path]);

    if (_options & RenderMenuTooltip)
        rep.menu_tooltip = NonNull([NSString stringWithUTF8StdString:_location.verbose_path]);
    
    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForLocation(_location.hosts_stack, m_NetworkConnectionsManager);
    
    return rep;
}
    
FavoriteFormatter::FavoriteFormatter(const NetworkConnectionsManager &_conn_mgr):
    m_NetworkConnectionsManager(_conn_mgr)
{
}
    
FavoriteFormatter::Representation
FavoriteFormatter::Render(RenderOptions _options,
                          const FavoriteLocationsStorage::Favorite &_favorite )
{
    Representation rep;
    
    if( _options & RenderMenuTitle ) {
        if( !_favorite.title.empty() )
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:_favorite.title]);
        else
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:
                                      _favorite.location->verbose_path]);
    }
    
    if( _options & RenderMenuTooltip )
        rep.menu_tooltip = NonNull([NSString stringWithUTF8StdString:
                                    _favorite.location->verbose_path]);
    
    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForLocation(_favorite.location->hosts_stack,
                                         m_NetworkConnectionsManager);
    
    return rep;
}
    
NetworkConnectionFormatter::Representation
NetworkConnectionFormatter::Render(RenderOptions _options,
                                   const NetworkConnectionsManager::Connection &_connection )
{
    Representation rep;
    
    if( _options & RenderMenuTitle ) {
        if( !_connection.Title().empty() )
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:_connection.Title()]);
        else {
            const auto path = NetworkConnectionsManager::MakeConnectionPath(_connection);
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:path]);
        }
    }
    
    if( _options & RenderMenuTooltip ) {
        const auto path = NetworkConnectionsManager::MakeConnectionPath(_connection);
        rep.menu_tooltip = NonNull([NSString stringWithUTF8StdString:path]);
    }
    
    if( _options & RenderMenuIcon )
        rep.menu_icon = NetworkConnectionIconProvider{}.Icon16px(_connection);
    
    return rep;
}
    
VolumeFormatter::Representation
VolumeFormatter::Render(RenderOptions _options,
                        const NativeFileSystemInfo &_volume )
{
    Representation rep;
    
    if( _options & RenderMenuTitle )
        rep.menu_title = NonNull(_volume.verbose.name);
    
    if( _options & RenderMenuTooltip ) {
        auto tooltip = _volume.mounted_at_path + "\n" + _volume.mounted_from_name;
        rep.menu_tooltip = NonNull([NSString stringWithUTF8StdString:tooltip]);
    }
    
    if( _options & RenderMenuIcon ) {
        rep.menu_icon = [_volume.verbose.icon copy];
        rep.menu_icon.size = g_IconSize;
    }

    return rep;
}

VFSPromiseFormatter::Representation
VFSPromiseFormatter::Render(RenderOptions _options,
                            const core::VFSInstancePromise &_promise,
                            const string &_path)
{
    Representation rep;
    
    if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
        auto str = _promise.verbose_title() + _path;
        rep.menu_title = NonNull([NSString stringWithUTF8StdString:str]);
        rep.menu_tooltip = rep.menu_title;
    }
    
    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForPromiseAndPath(_promise, _path);
    
    return rep;
}
    
VFSPathFormatter::Representation
VFSPathFormatter::Render(RenderOptions _options,
                         const VFSHost &_vfs,
                         const string &_path)
{
    Representation rep;
    
    if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
        auto str = PanelDataPersisency::MakeVerbosePathString(_vfs, _path);
        rep.menu_title = NonNull([NSString stringWithUTF8StdString:str]);
        rep.menu_tooltip = rep.menu_title;
    }
    
    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForVFSPath(_vfs, _path);
    
    return rep;
}

static NSImage *ImageForPromiseAndPath(const core::VFSInstancePromise &_promise,
                                       const string& _path )
{
    if( _promise.tag() == VFSNativeHost::UniqueTag ) {
        static const auto workspace = NSWorkspace.sharedWorkspace;
        if( auto image = [workspace iconForFile:[NSString stringWithUTF8StdString:_path]] ) {
            image.size = g_IconSize;
            return image;
        }
    }
    
    if( auto image = NetworkConnectionIconProvider{}.Icon16px(_promise) )
        return image;
    
    static const auto fallback = []{
        auto image = [NSImage imageNamed:NSImageNameFolder];
        image.size = g_IconSize;
        return image;
    }();
    return fallback;
}
    
static NSImage* ImageForVFSPath(const VFSHost &_vfs,
                                const string &_path)
{
    if( _vfs.IsNativeFS() ) {
        static const auto workspace = NSWorkspace.sharedWorkspace;
        if( auto image = [workspace iconForFile:[NSString stringWithUTF8StdString:_path]] ) {
            image.size = g_IconSize;
            return image;
        }
    }
        
    if( auto image = NetworkConnectionIconProvider{}.Icon16px(_vfs) )
        return image;
    
    static const auto fallback = []{
        auto image = [NSImage imageNamed:NSImageNameFolder];
        image.size = g_IconSize;
        return image;
    }();
    return fallback;
}
    
static NSImage* ImageForLocation(const PersistentLocation &_location,
                                 const NetworkConnectionsManager &_conn_mgr)
{
    if( _location.is_native() ) {
        auto url = [[NSURL alloc] initFileURLWithFileSystemRepresentation:_location.path.c_str()
                                                              isDirectory:true
                                                            relativeToURL:nil];
        if( url ) {
            NSImage *img;
            [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:nil];
            if( img != nil ) {
                img.size = g_IconSize;
                return img;
            }
        }
    }
    else if( _location.is_network() ) {
        auto persistancy = PanelDataPersisency{_conn_mgr};
        if( auto connection = persistancy.ExtractConnectionFromLocation(_location) )
            return NetworkConnectionIconProvider{}.Icon16px(*connection);
        else {
            auto img = [NSImage imageNamed:NSImageNameNetwork];
            img.size = g_IconSize;
            return img;
        }
    }
    
    auto img = [NSImage imageNamed:NSImageNameFolder];
    img.size = g_IconSize;
    return img;
}
    
static NSString *NonNull(NSString *_string)
{
    return _string ? _string : @"";
}
    
}
