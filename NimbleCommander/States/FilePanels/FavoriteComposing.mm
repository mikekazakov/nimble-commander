// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/Native.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include "FavoriteComposing.h"
#include "PanelDataPersistency.h"

namespace nc::panel {

static std::vector<std::pair<std::string, std::string>> GetFindersFavorites();
static std::vector<std::pair<std::string, std::string>> GetDefaultFavorites();

FavoriteComposing::FavoriteComposing(const FavoriteLocationsStorage& _storage):
    m_Storage(_storage)
{
}
    
std::optional< FavoriteLocationsStorage::Favorite > FavoriteComposing::
    FromURL( NSURL *_url )
{
    if( !_url || !_url.fileURL )
        return std::nullopt;
    
    if( !_url.hasDirectoryPath )
        return FromURL( _url.URLByDeletingLastPathComponent );

    auto path = _url.fileSystemRepresentation;
    if( !path )
        return std::nullopt;

    auto f = m_Storage.ComposeFavoriteLocation(*VFSNativeHost::SharedHost(), path);
    if( !f )
        return std::nullopt;
    

    NSString *title;
    [_url getResourceValue:&title forKey:NSURLLocalizedNameKey error:nil];
    if( title ) {
        f->title = title.UTF8String;
    }
    else {
        [_url getResourceValue:&title forKey:NSURLNameKey error:nil];
        if( title )
            f->title = title.UTF8String;
    }
    
    return f;
}

static std::string TitleForItem( const VFSListingItem &_i )
{
    if( _i.IsDir() )
        if( !_i.IsDotDot() )
            return _i.Filename();
    return boost::filesystem::path(_i.Directory()).parent_path().filename().native();
}

std::optional<FavoriteLocationsStorage::Favorite> FavoriteComposing::
    FromListingItem( const VFSListingItem &_i )
{
    if( !_i )
        return std::nullopt;

    auto path = _i.IsDir() ? _i.Path() : _i.Directory();
    auto f = m_Storage.ComposeFavoriteLocation( *_i.Host(), path );
    if( !f )
        return std::nullopt;

    f->title = TitleForItem(_i);

    return f;
}

std::vector<FavoriteLocationsStorage::Favorite> FavoriteComposing::FinderFavorites()
{
    auto ff = GetFindersFavorites();

    std::vector<FavoriteLocationsStorage::Favorite> favorites;
    auto &host = *VFSNativeHost::SharedHost();
    for( auto &f: ff) {
        auto fl = m_Storage.ComposeFavoriteLocation(
            host,
            f.second,
            f.first);

        if( fl )
            favorites.emplace_back( std::move(*fl) );
    }
    return favorites;
}

std::vector<FavoriteLocationsStorage::Favorite> FavoriteComposing::DefaultFavorites()
{
    auto df = GetDefaultFavorites();

    std::vector<FavoriteLocationsStorage::Favorite> favorites;
    auto &host = *VFSNativeHost::SharedHost();
    for( auto &f: df) {
        auto fl = m_Storage.ComposeFavoriteLocation(
            host,
            f.second,
            f.first);

        if( fl )
            favorites.emplace_back( std::move(*fl) );
    }
    return favorites;
}

static std::string StringFromURL( CFURLRef _url )
{
    char path_buf[MAXPATHLEN];
    if( CFURLGetFileSystemRepresentation(_url, true, (UInt8*)path_buf, MAXPATHLEN) )
        return path_buf;
    return {};
}

static std::string TitleForURL( CFURLRef _url )
{
    if( auto url = (__bridge NSURL*)_url ) {
        NSString *title;
        [url getResourceValue:&title forKey:NSURLLocalizedNameKey error:nil];
        if( title ) {
            return title.UTF8String;
        }
        else {
            [url getResourceValue:&title forKey:NSURLNameKey error:nil];
            if( title )
                return title.UTF8String;
        }
    }
    return {};
}

static std::string TitleForPath( const std::string &_path )
{
    auto url = [[NSURL alloc] initFileURLWithFileSystemRepresentation:_path.c_str()
                                                          isDirectory:true
                                                        relativeToURL:nil];
    if( url ) {
        NSString *title;
        [url getResourceValue:&title forKey:NSURLLocalizedNameKey error:nil];
        if( title ) {
            return title.UTF8String;
        }
        else {
            [url getResourceValue:&title forKey:NSURLNameKey error:nil];
            if( title )
                return title.UTF8String;
        }
    }
    return {};
}

static std::string ensure_tr_slash( std::string _str )
{
    if( _str.empty() || _str.back() != '/' )
        _str += '/';
    return _str;
}

static std::vector<std::pair<std::string, std::string>> GetFindersFavorites() // title, path
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    const auto flags = kLSSharedFileListNoUserInteraction|kLSSharedFileListDoNotMountVolumes;
    std::vector<std::pair<std::string, std::string>> paths;
    
    UInt32 seed;
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListFavoriteItems, NULL);
    CFArrayRef snapshot = LSSharedFileListCopySnapshot(list, &seed);
    if( snapshot ) {
        for( int i = 0, e = (int)CFArrayGetCount(snapshot); i != e; ++i ) {
            if( auto item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(snapshot, i) ) {
                CFErrorRef err = nullptr;
                auto url = LSSharedFileListItemCopyResolvedURL(item, flags, &err);
                if( url ) {
                    auto path = StringFromURL( url );
                    if( !path.empty() &&
                        !has_suffix(path, ".cannedSearch") &&
                        !has_suffix(path, ".cannedSearch/") &&
                        !has_suffix(path, ".savedSearch") &&
                        VFSNativeHost::SharedHost()->IsDirectory(path.c_str(), 0) )
                        paths.emplace_back( make_pair(
                            TitleForURL(url),
                            ensure_tr_slash(move(path)))
                            );
                    CFRelease(url);
                }
                if( err ) {
                    if( auto description = CFErrorCopyDescription(err) ) {
                        CFShow(description);
                        CFRelease(description);
                    }
                    if( auto reason = CFErrorCopyFailureReason(err) ) {
                        CFShow(reason);
                        CFRelease(reason);
                    }
                    CFRelease(err);
                }
            }
        }
        CFRelease(snapshot);
    }
    CFRelease(list);
    
    return paths;
#pragma clang diagnostic pop
}

static std::vector<std::pair<std::string, std::string>> GetDefaultFavorites()
{
    return {{
        {TitleForPath(CommonPaths::Home()),         CommonPaths::Home()},
        {TitleForPath(CommonPaths::Desktop()),      CommonPaths::Desktop()},
        {TitleForPath(CommonPaths::Documents()),    CommonPaths::Documents()},
        {TitleForPath(CommonPaths::Downloads()),    CommonPaths::Downloads()},
        {TitleForPath(CommonPaths::Movies()),       CommonPaths::Movies()},
        {TitleForPath(CommonPaths::Music()),        CommonPaths::Music()},
        {TitleForPath(CommonPaths::Pictures()),     CommonPaths::Pictures()}
    }};
}

}
