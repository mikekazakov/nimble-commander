#include "LaunchServices.h"
#include <sys/stat.h>

namespace nc::core {

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
        return _default;

    T&& val = _pred(*_first);
    _first++;

    while( _first != _last ) {
        if ( _pred(*_first) != val )
            return _default;
        ++_first;
    }
    return val;
}

static string UTIForExtenstion(const string& _extension)
{
    static mutex guard;
    static unordered_map<string, string> extension_to_uti_mapping;
    
    lock_guard<mutex> lock(guard);
    if( auto i = extension_to_uti_mapping.find(_extension); i != end(extension_to_uti_mapping) )
        return i->second;
    
    string uti;
    if( const auto ext = CFStringCreateWithUTF8StdStringNoCopy( _extension ) ) {
        const auto cf_uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                                  ext,
                                                                  nullptr);
        if( cf_uti ) {
            uti = ((__bridge NSString*)cf_uti).UTF8String;
            extension_to_uti_mapping.emplace(_extension, uti);
            CFRelease(cf_uti);
        }
        CFRelease(ext);
    }

    return uti;
}

static string GetDefaultHandlerPathForNativeItem( const string &_path )
{
    string result;
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

static vector<string> GetHandlersPathsForNativeItem( const string &_path )
{
    vector<string> result;
    const auto url = CFURLCreateFromFileSystemRepresentation(0,
                                                             (const UInt8*)_path.c_str(),
                                                             _path.length(),
                                                             false);
    if( url ) {
        auto apps = (NSArray *)CFBridgingRelease( LSCopyApplicationURLsForURL(url, kLSRolesAll) );
        for( NSURL *app_url in apps )
            result.emplace_back( app_url.path.fileSystemRepresentation );
        CFRelease(url);
    }
    return result;
}

LauchServicesHandlers LauchServicesHandlers::GetForItem( const VFSListingItem &_it )
{
    LauchServicesHandlers result;
    
    if( _it.Host()->IsNativeFS() ) {
        if( _it.HasExtension() )
            result.uti = UTIForExtenstion( _it.Extension() );
        
        const auto path = _it.Path();
        result.paths = GetHandlersPathsForNativeItem(path);
        result.default_handler_path = GetDefaultHandlerPathForNativeItem(path);
    }
    else {
        if(_it.IsDir())
            return result;
                
        if( _it.HasExtension() ) {
            CFStringRef ext = CFStringCreateWithUTF8StringNoCopy(_it.Extension());
            if( CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL) ) {
                result.uti = [((__bridge NSString*)UTI) UTF8String];
                NSString *default_bundle = (__bridge_transfer id)LSCopyDefaultRoleHandlerForContentType(UTI,kLSRolesAll);
                
                NSArray *apps = (NSArray *)CFBridgingRelease( LSCopyAllRoleHandlersForContentType(UTI,kLSRolesAll) );
                for (NSString* bundleIdentifier in apps)
                    if( auto nspath = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleIdentifier] ) {
                        result.paths.push_back( nspath.fileSystemRepresentation );
                        if([bundleIdentifier isEqualToString:default_bundle])
                            result.default_handler_path = result.paths.back();
                    }
                
                CFRelease(UTI);
            }
            CFRelease(ext);
        }
    }
    return result;
}

void LauchServicesHandlers::DoMerge(const vector<LauchServicesHandlers>& _input, LauchServicesHandlers& _result)
{
    // empty handler path means that there's no default handler available
    string default_handler = all_equal_or_default(begin(_input), end(_input), [](auto &i){
        return i.default_handler_path; },
        ""s);
    
    // empty default_uti means that uti's are different in _input
    string default_uti = all_equal_or_default(begin(_input), end(_input), [](auto &i){
        return i.uti; },
        ""s);
    
    // maps handler path to usage amount
    // then use only handlers with usage amount == _input.size() (or common ones)
    unordered_map<string, int> handlers_count;
    for( auto &i:_input ) {
        // a very inefficient approach, should be rewritten if will cause lags on UI
        unordered_set<string> inserted;
        for( auto &p:i.paths )
            // here we exclude multiple counting for repeating handlers for one content type
            if( !inserted.count(p) ) {
                handlers_count[p]++;
                inserted.insert(p);
            }
    }
    
    _result.paths.clear();
    _result.uti = default_uti;
    _result.default_handler_path = -1;
    
    for(auto &i:handlers_count)
        if(i.second == _input.size()) {
            _result.paths.emplace_back(i.first);
            if(i.first == default_handler)
                _result.default_handler_path = default_handler;
        }
}

bool LauchServicesHandlers::SetDefaultHandler(const string &_uti, const string &_path)
{
    NSString *path = [NSString stringWithUTF8StdString:_path];
    if(!path)
        return false;
    
    NSString *uti = [NSString stringWithUTF8StdString:_uti];
    if(!uti)
        return false;
    
    NSBundle *handler_bundle = [NSBundle bundleWithPath:path];
    if(!handler_bundle)
        return false;
    
    NSString *bundle_id = [handler_bundle bundleIdentifier];
    if(!bundle_id)
        return false;
    
    
    OSStatus ret = LSSetDefaultRoleHandlerForContentType(
                                                         (__bridge CFStringRef)uti,
                                                         kLSRolesAll,
                                                         (__bridge CFStringRef)bundle_id);

    return ret == 0;
}


struct CachedLaunchServiceHandler
{
    

    string      path;
    time_t      mtime;
    NSString   *name;
    NSImage    *icon;
    NSString   *version;
    NSString   *identifier;
    
    static CachedLaunchServiceHandler GetLaunchHandlerInfo( const string &_handler_path )
    {
        lock_guard<mutex> lock{g_HandlersByPathLock};
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
    static CachedLaunchServiceHandler BuildLaunchHandler( const string &_handler_path )
    {
        NSString *path = [NSString stringWithUTF8StdString:_handler_path];
        if( !path )
            throw domain_error("malformed path");
        
        NSBundle *handler_bundle = [NSBundle bundleWithPath:path];
        if( handler_bundle == nil )
            throw domain_error("can't open NSBundle");
        
        struct stat st;
        if( stat(_handler_path.c_str(), &st) != 0 )
            throw domain_error("stat() failed");
        
        CachedLaunchServiceHandler h;
        h.path = _handler_path;
        h.name = [NSFileManager.defaultManager displayNameAtPath:path];
        h.icon = [NSWorkspace.sharedWorkspace iconForFile:path];
        h.version = [handler_bundle.infoDictionary objectForKey:@"CFBundleVersion"];
        h.mtime = st.st_mtime;
        
        return h;
    }

    static bool IsOutdated( const string &_path, time_t _mtime )
    {
        struct stat st;
        if( stat(_path.c_str(), &st) != 0 )
            return true;
        return _mtime != st.st_mtime;
    }

    static unordered_map<string, CachedLaunchServiceHandler> g_HandlersByPath;
    static mutex g_HandlersByPathLock;
};

unordered_map<string, CachedLaunchServiceHandler> CachedLaunchServiceHandler::g_HandlersByPath;
mutex CachedLaunchServiceHandler::g_HandlersByPathLock;

LaunchServiceHandler::LaunchServiceHandler( const string &_handler_path )
{
    auto handler = CachedLaunchServiceHandler::GetLaunchHandlerInfo(_handler_path);
    m_AppID = handler.identifier;
    m_AppVersion = handler.version;
    m_AppName = handler.name;
    m_AppIcon = handler.icon;
    m_Path = _handler_path;
}

const string &LaunchServiceHandler::Path() const noexcept
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

}
