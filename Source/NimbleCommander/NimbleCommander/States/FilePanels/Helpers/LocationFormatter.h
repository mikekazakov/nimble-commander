// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/NativeFSManager.h>
#include <Utility/Tags.h>
#include <Panel/NetworkConnectionsManager.h>
#include <NimbleCommander/Core/VFSInstancePromise.h>

// TODO: extract favorite and location
#include "../Favorites.h"

namespace nc::panel {
class ListingPromise;
}

namespace nc::panel::loc_fmt {

class Formatter
{
public:
    struct Representation {
        NSString *menu_title;
        NSString *menu_tooltip;
        NSImage *menu_icon;
    };

    enum RenderOptions {
        RenderMenuTitle = 1,
        RenderMenuIcon = 2,
        RenderMenuTooltip = 4,
        RenderEverything = -1,
        RenderNothing = 0
    };
};

class ListingPromiseFormatter : public Formatter
{
public:
    static Representation Render(RenderOptions _options, const ListingPromise &_promise);
};

class FavoriteLocationFormatter : public Formatter
{
public:
    FavoriteLocationFormatter(NetworkConnectionsManager &_conn_mgr);

    Representation Render(RenderOptions _options, const FavoriteLocationsStorage::Location &_location);

private:
    NetworkConnectionsManager &m_NetworkConnectionsManager;
};

class FavoriteFormatter : public Formatter
{
public:
    FavoriteFormatter(NetworkConnectionsManager &_conn_mgr);

    Representation Render(RenderOptions _options, const FavoriteLocationsStorage::Favorite &_favorite);

private:
    NetworkConnectionsManager &m_NetworkConnectionsManager;
};

class NetworkConnectionFormatter : public Formatter
{
public:
    static Representation Render(RenderOptions _options, const NetworkConnectionsManager::Connection &_connection);
};

class VolumeFormatter : public Formatter
{
public:
    static Representation Render(RenderOptions _options, const utility::NativeFileSystemInfo &_volume);
};

class VFSPromiseFormatter : public Formatter
{
public:
    static Representation
    Render(RenderOptions _options, const core::VFSInstancePromise &_promise, const std::string &_path);
};

class VFSPathFormatter : public Formatter
{
public:
    VFSPathFormatter(NetworkConnectionsManager &_conn_mgr);
    Representation Render(RenderOptions _options, const VFSHost &_vfs, const std::string &_path);

private:
    NetworkConnectionsManager &m_NetworkConnectionsManager;
};

class VFSFinderTagsFormatter : public Formatter
{
public:
    static Representation Render(RenderOptions _options, const utility::Tags::Tag &_tag);
};

}; // namespace nc::panel::loc_fmt
