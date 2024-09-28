// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "LocationFormatter.h"
#include "../ListingPromise.h"
#include <compose_visitors.hpp>
#include <VFS/Native.h>
#include <NimbleCommander/Core/NetworkConnectionIconProvider.h>
#include "../PanelDataPersistency.h"
#include <Utility/NativeFSManager.h>
#include <Utility/StringExtras.h>
#include <Panel/UI/TagsPresentation.h>
#include <iostream>
#include <Cocoa/Cocoa.h>

namespace nc::panel::loc_fmt {

static const auto g_IconSize = NSMakeSize(16, 16);

static NSImage *ImageForPromiseAndPath(const core::VFSInstancePromise &_promise, const std::string &_path);
static NSImage *ImageForLocation(const PersistentLocation &_location, NetworkConnectionsManager &_conn_mgr);
static NSImage *ImageForVFSPath(const VFSHost &_vfs, const std::string &_path);
static NSString *NonNull(NSString *_string);

ListingPromiseFormatter::Representation ListingPromiseFormatter::Render(RenderOptions _options,
                                                                        const ListingPromise &_promise)
{
    Representation rep;

    // yes, i know about std::visit, but libc++ on macOS requires 10.14+ to use it.
    auto visit_uniform_listing = [&](const ListingPromise::UniformListing &l) {
        if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
            const auto title = l.promise.verbose_title() + l.directory;
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:title]);
            rep.menu_tooltip = rep.menu_title;
        }
        if( _options & RenderMenuIcon )
            rep.menu_icon = ImageForPromiseAndPath(l.promise, l.directory);
    };
    auto visit_nonuniform_listing = [&](const ListingPromise::NonUniformListing &l) {
        if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
            static const auto formatter = [] {
                auto fmt = [[NSNumberFormatter alloc] init];
                fmt.usesGroupingSeparator = true;
                fmt.groupingSize = 3;
                return fmt;
            }();

            const auto count = [NSNumber numberWithUnsignedInteger:l.EntriesCount()];
            rep.menu_title = [NSString stringWithFormat:@"Temporary Panel (%@)", [formatter stringFromNumber:count]];
            rep.menu_tooltip = rep.menu_title;
        }
    };

    auto description = &_promise.Description();
    if( auto uniform = std::get_if<ListingPromise::UniformListing>(description) )
        visit_uniform_listing(*uniform);
    else if( auto nonuniform = std::get_if<ListingPromise::NonUniformListing>(description) )
        visit_nonuniform_listing(*nonuniform);
    else
        std::cerr << "ListingPromiseFormatter::Render: unhandled case" << '\n';

    return rep;
}

FavoriteLocationFormatter::FavoriteLocationFormatter(NetworkConnectionsManager &_conn_mgr)
    : m_NetworkConnectionsManager(_conn_mgr)
{
}

FavoriteLocationFormatter::Representation
FavoriteLocationFormatter::Render(RenderOptions _options, const FavoriteLocationsStorage::Location &_location)
{
    Representation rep;

    if( _options & RenderMenuTitle )
        rep.menu_title = NonNull([NSString stringWithUTF8StdString:_location.verbose_path]);

    if( _options & RenderMenuTooltip )
        rep.menu_tooltip = NonNull([NSString stringWithUTF8StdString:_location.verbose_path]);

    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForLocation(_location.hosts_stack, m_NetworkConnectionsManager);

    return rep;
}

FavoriteFormatter::FavoriteFormatter(NetworkConnectionsManager &_conn_mgr) : m_NetworkConnectionsManager(_conn_mgr)
{
}

FavoriteFormatter::Representation FavoriteFormatter::Render(RenderOptions _options,
                                                            const FavoriteLocationsStorage::Favorite &_favorite)
{
    Representation rep;

    if( _options & RenderMenuTitle ) {
        if( !_favorite.title.empty() )
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:_favorite.title]);
        else
            rep.menu_title = NonNull([NSString stringWithUTF8StdString:_favorite.location->verbose_path]);
    }

    if( _options & RenderMenuTooltip )
        rep.menu_tooltip = NonNull([NSString stringWithUTF8StdString:_favorite.location->verbose_path]);

    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForLocation(_favorite.location->hosts_stack, m_NetworkConnectionsManager);

    return rep;
}

NetworkConnectionFormatter::Representation
NetworkConnectionFormatter::Render(RenderOptions _options, const NetworkConnectionsManager::Connection &_connection)
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

VolumeFormatter::Representation VolumeFormatter::Render(RenderOptions _options,
                                                        const utility::NativeFileSystemInfo &_volume)
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
VFSPromiseFormatter::Render(RenderOptions _options, const core::VFSInstancePromise &_promise, const std::string &_path)
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

VFSPathFormatter::VFSPathFormatter(NetworkConnectionsManager &_conn_mgr) : m_NetworkConnectionsManager(_conn_mgr)
{
}

VFSPathFormatter::Representation
VFSPathFormatter::Render(RenderOptions _options, const VFSHost &_vfs, const std::string &_path)
{
    Representation rep;

    if( (_options & RenderMenuTitle) || (_options & RenderMenuTooltip) ) {
        PanelDataPersistency persistency(m_NetworkConnectionsManager);
        auto str = persistency.MakeVerbosePathString(_vfs, _path);
        rep.menu_title = NonNull([NSString stringWithUTF8StdString:str]);
        rep.menu_tooltip = rep.menu_title;
    }

    if( _options & RenderMenuIcon )
        rep.menu_icon = ImageForVFSPath(_vfs, _path);

    return rep;
}

VFSFinderTagsFormatter::Representation VFSFinderTagsFormatter::Render(RenderOptions _options,
                                                                      const utility::Tags::Tag &_tag)
{
    Representation rep;

    if( _options & RenderMenuTitle )
        rep.menu_title = [NSString stringWithUTF8StdString:_tag.Label()];

    if( _options & RenderMenuTooltip )
        rep.menu_tooltip = [NSString
            localizedStringWithFormat:NSLocalizedString(@"Display all items with the tag “%@”",
                                                        "Tooltip for a quick list menu shown for each finder tag"),
                                      [NSString stringWithUTF8StdString:_tag.Label()]];

    if( _options & RenderMenuIcon )
        rep.menu_icon = panel::TagsMenuDisplay::Images().at(std::to_underlying(_tag.Color()));

    return rep;
}

static NSImage *ImageForPromiseAndPath(const core::VFSInstancePromise &_promise, const std::string &_path)
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

    static const auto fallback = [] {
        auto image = [NSImage imageNamed:NSImageNameFolder];
        image.size = g_IconSize;
        return image;
    }();
    return fallback;
}

static NSImage *ImageForVFSPath(const VFSHost &_vfs, const std::string &_path)
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

    static const auto fallback = [] {
        auto image = [NSImage imageNamed:NSImageNameFolder];
        image.size = g_IconSize;
        return image;
    }();
    return fallback;
}

static NSImage *ImageForLocation(const PersistentLocation &_location, NetworkConnectionsManager &_conn_mgr)
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
        auto persistancy = PanelDataPersistency{_conn_mgr};
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

} // namespace nc::panel::loc_fmt
