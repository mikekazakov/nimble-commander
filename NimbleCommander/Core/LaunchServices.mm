// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "LaunchServices.h"
#include <sys/stat.h>
#include <VFS/VFS.h>
#include <Utility/StringExtras.h>
#include <Cocoa/Cocoa.h>
#include <unordered_map>
#include <unordered_set>

namespace nc::core {

using namespace std::literals;

/**
 * If container is not empty and has only the equal elements - return it.
 * Otherwise, return _default
 */
template <class InputIterator, class UnaryPredicate, class T>
inline T all_equal_or_default(InputIterator _first,
                      InputIterator _last,
                      UnaryPredicate _pred,
                      T&& _default)
{
    if( _first == _last )
        return std::move(_default);

    T&& val = _pred(*_first);
    _first++;

    while( _first != _last ) {
        if ( _pred(*_first) != val )
            return std::move(_default);
        ++_first;
    }
    return std::move(val);
}

static std::string GetDefaultHandlerPathForNativeItem( const std::string &_path )
{
    std::string result;
    const auto url = CFURLCreateFromFileSystemRepresentation(0,
                                                             (const UInt8*)_path.c_str(),
                                                             _path.length(),
                                                             false);
    if( url ) {
        const auto handler_url = LSCopyDefaultApplicationURLForURL(url, kLSRolesAll, nullptr);
    
        if( handler_url ) {
            result = ((__bridge NSURL*)handler_url).path.fileSystemRepresentation;
            CFRelease(handler_url);
        }
        CFRelease(url);
    }
    return result;
}

static std::vector<std::string> GetHandlersPathsForNativeItem( const std::string &_path )
{
    std::vector<std::string> result;
    const auto url = CFURLCreateFromFileSystemRepresentation(0,
                                                             (const UInt8*)_path.c_str(),
                                                             _path.length(),
                                                             false);
    if( url ) {
        auto apps = (__bridge_transfer NSArray *) LSCopyApplicationURLsForURL(url, kLSRolesAll);
        for( NSURL *app_url in apps )
            result.emplace_back( app_url.path.fileSystemRepresentation );
        CFRelease(url);
    }
    return result;
}

static std::string GetDefaultHandlerPathForUTI( const std::string &_uti )
{
    NSString *uti = [NSString stringWithUTF8StdString:_uti];
    if( !uti )
        return {};
    
    NSString *bundle = (__bridge_transfer NSString*)
        LSCopyDefaultRoleHandlerForContentType((__bridge CFStringRef)uti,
                                               kLSRolesAll);
    auto path = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundle];
    if( path )
        return path.fileSystemRepresentation;
    return "";
}

static std::vector<std::string> GetHandlersPathsForUTI( const std::string &_uti )
{
    NSString *uti = [NSString stringWithUTF8StdString:_uti];
    if( !uti )
        return {};

    NSArray *bundles = (__bridge_transfer NSArray *)
        LSCopyAllRoleHandlersForContentType((__bridge CFStringRef)uti,
                                            kLSRolesAll);
    
    std::vector<std::string> result;
    for( NSString* bundle in bundles )
        if( auto path = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundle] )
            result.emplace_back( path.fileSystemRepresentation );

    return result;
}

LauchServicesHandlers::LauchServicesHandlers()
{
}

LauchServicesHandlers::LauchServicesHandlers( const VFSListingItem &_item,
    const nc::utility::UTIDB &_uti_db  )
{
    if( _item.Host()->IsNativeFS() ) {
        m_UTI = _item.HasExtension() ? _uti_db.UTIForExtension(_item.Extension()) : "public.data";
        const auto path = _item.Path();
        m_Paths = GetHandlersPathsForNativeItem(path);
        m_DefaultHandlerPath = GetDefaultHandlerPathForNativeItem(path);
    }
    else if( !_item.IsDir() && _item.HasExtension() ) {
        m_UTI = _uti_db.UTIForExtension(_item.Extension());
        m_Paths = GetHandlersPathsForUTI(m_UTI);
        m_DefaultHandlerPath = GetDefaultHandlerPathForUTI(m_UTI);
    }
}

LauchServicesHandlers::LauchServicesHandlers
    ( const std::vector<LauchServicesHandlers>& _handlers_to_merge )
{
    // empty handler path means that there's no default handler available
    const auto default_handler = all_equal_or_default(
        begin(_handlers_to_merge),
        end(_handlers_to_merge),
        [](auto &i){ return i.m_DefaultHandlerPath; },
        ""s);
    
    m_UTI = all_equal_or_default(
        begin(_handlers_to_merge),
        end(_handlers_to_merge),
        [](auto &i){ return i.m_UTI; },
        ""s);
    
    // maps handler path to usage amount
    // then use only handlers with usage amount == _input.size() (or common ones)
    std::unordered_map<std::string, int> handlers_count;
    for( auto &i:_handlers_to_merge ) {
        // a very inefficient approach, should be rewritten if will cause lags on UI
        std::unordered_set<std::string> inserted;
        for( auto &p:i.m_Paths )
            // here we exclude multiple counting for repeating handlers for one content type
            if( !inserted.count(p) ) {
                handlers_count[p]++;
                inserted.insert(p);
            }
    }
    
    for( auto &i: handlers_count )
        if( i.second == (int)_handlers_to_merge.size() ) {
            m_Paths.emplace_back(i.first);
            if(i.first == default_handler)
                m_DefaultHandlerPath = default_handler;
        }
}

const std::vector<std::string> &LauchServicesHandlers::HandlersPaths() const noexcept
{
    return m_Paths;
}

const std::string &LauchServicesHandlers::DefaultHandlerPath() const noexcept
{
    return m_DefaultHandlerPath;
}

const std::string &LauchServicesHandlers::CommonUTI() const noexcept
{
    return m_UTI;
}

struct CachedLaunchServiceHandler
{
    std::string path;
    time_t      mtime;
    NSString   *name;
    NSImage    *icon;
    NSString   *version;
    NSString   *identifier;
    
    static CachedLaunchServiceHandler GetLaunchHandlerInfo( const std::string &_handler_path )
    {
        std::lock_guard<std::mutex> lock{g_HandlersByPathLock};
        if( auto i = g_HandlersByPath.find(_handler_path);
           i != end(g_HandlersByPath) && !IsOutdated(i->second.path, i->second.mtime) ) {
            return i->second;
        }
        else {
            auto h = BuildLaunchHandler( _handler_path );
            g_HandlersByPath[_handler_path] = h;
            return h;
        }
    }

private:
    static CachedLaunchServiceHandler BuildLaunchHandler( const std::string &_handler_path )
    {
        NSString *path = [NSString stringWithUTF8StdString:_handler_path];
        if( !path )
            throw std::domain_error("malformed path");
        
        NSBundle *handler_bundle = [NSBundle bundleWithPath:path];
        if( handler_bundle == nil )
            throw std::domain_error("can't open NSBundle");
        
        struct stat st;
        if( stat(_handler_path.c_str(), &st) != 0 )
            throw std::domain_error("stat() failed");
        
        CachedLaunchServiceHandler h;
        h.path = _handler_path;
        h.name = [NSFileManager.defaultManager displayNameAtPath:path];
        h.icon = CropHiResRepresentations([NSWorkspace.sharedWorkspace iconForFile:path]);
        h.version = [handler_bundle.infoDictionary objectForKey:@"CFBundleVersion"];
        h.identifier = handler_bundle.bundleIdentifier;
        h.mtime = st.st_mtime;
        
        return h;
    }

    static bool IsOutdated( const std::string &_path, time_t _mtime )
    {
        struct stat st;
        if( stat(_path.c_str(), &st) != 0 )
            return true;
        return _mtime != st.st_mtime;
    }
    
    static NSImage *CropHiResRepresentations( NSImage *_image )
    {
        const auto representations = _image.representations;
        std::vector<NSImageRep*> to_remove;
        for( NSImageRep *representation in representations )
            if( representation.pixelsHigh > 32 && representation.pixelsWide > 32 )
                to_remove.emplace_back(representation);
        for( NSImageRep *representation: to_remove )
            [_image removeRepresentation:representation];
        return _image;
    }

    static std::unordered_map<std::string, CachedLaunchServiceHandler> g_HandlersByPath;
    static std::mutex g_HandlersByPathLock;
};

std::unordered_map<std::string, CachedLaunchServiceHandler> CachedLaunchServiceHandler::g_HandlersByPath;
std::mutex CachedLaunchServiceHandler::g_HandlersByPathLock;

LaunchServiceHandler::LaunchServiceHandler( const std::string &_handler_path )
{
    auto handler = CachedLaunchServiceHandler::GetLaunchHandlerInfo(_handler_path);
    m_AppID = handler.identifier;
    m_AppVersion = handler.version;
    m_AppName = handler.name;
    m_AppIcon = handler.icon;
    m_Path = _handler_path;
}

const std::string &LaunchServiceHandler::Path() const noexcept
{
    return m_Path;
}

NSString *LaunchServiceHandler::Name() const noexcept
{
    return m_AppName;
}

NSImage *LaunchServiceHandler::Icon() const noexcept
{
    return m_AppIcon;
}

NSString *LaunchServiceHandler::Version() const noexcept
{
    return m_AppVersion;
}

NSString *LaunchServiceHandler::Identifier() const noexcept
{
    return m_AppID;
}

bool LaunchServiceHandler::SetAsDefaultHandlerForUTI(const std::string &_uti) const
{
    if( _uti.empty() )
        return false;
    
    NSString *uti = [NSString stringWithUTF8StdString:_uti];
    if( !uti )
        return false;
    
    OSStatus ret = LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)uti,
                                                         kLSRolesAll,
                                                         (__bridge CFStringRef)m_AppID);
    return ret == noErr;
}

}
