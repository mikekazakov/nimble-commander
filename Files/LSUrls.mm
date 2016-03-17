//
//  LSUrls.m
//  Files
//
//  Created by Michael G. Kazakov on 06.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "LSUrls.h"

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
    static vector< pair<string, string> > ext_to_uti;
    
    // TODO: sorting and binary search, O(logN) instead of O(N)
    lock_guard<mutex> lock(guard);
    auto it = find_if( begin(ext_to_uti), end(ext_to_uti), [&](auto &e){ return e.first == _extension; } );
    if( it != end(ext_to_uti) )
        return it->second;
    
    string uti;
    if( CFStringRef ext = CFStringCreateWithUTF8StdStringNoCopy( _extension ) ) {
        if( CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL) ) {
            uti = ((__bridge NSString*)UTI).UTF8String;
            ext_to_uti.emplace_back( _extension, uti );
            CFRelease(UTI);
        }
        CFRelease(ext);
    }

    return uti;
}

LauchServicesHandlers LauchServicesHandlers::GetForItem( const VFSListingItem &_it )
{
    LauchServicesHandlers result;
    
    if( _it.Host()->IsNativeFS() ) {
        if( _it.HasExtension() )
            result.uti = UTIForExtenstion( _it.Extension() );

        string path = _it.Directory() + _it.Filename();
        if( CFURLRef url = CFURLCreateFromFileSystemRepresentation(0, (const UInt8*)path.c_str(), path.length(), false) ) {
            if( CFURLRef default_app_url = LSCopyDefaultApplicationURLForURL(url, kLSRolesAll, nullptr) ) {
                NSArray *apps = (NSArray *)CFBridgingRelease( LSCopyApplicationURLsForURL(url, kLSRolesAll) );
                for( NSURL *url in apps ) {
                    result.paths.emplace_back( url.path.fileSystemRepresentation );
                    if( [(__bridge NSURL*)(default_app_url) isEqual:url] )
                        result.default_path = (int)result.paths.size() - 1;
                }
                CFRelease(default_app_url);
            }
            CFRelease(url);
        }
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
                            result.default_path = (int)result.paths.size() - 1;
                    }
                
                CFRelease(UTI);
            }
            CFRelease(ext);
        }
    }
    return result;
}

void LauchServicesHandlers::DoMerge(const list<LauchServicesHandlers>& _input, LauchServicesHandlers& _result)
{
    // empty handler path means that there's no default handler available
    string default_handler = all_equal_or_default(begin(_input), end(_input), [](auto &i){
        return i.default_path >= 0 ? i.paths[i.default_path] : ""s; }, ""s);
    
    // empty default_uti means that uti's are different in _input
    string default_uti = all_equal_or_default(begin(_input), end(_input), [](auto &i){ return i.uti; }, ""s);
    
    // maps handler path to usage amount
    // then use only handlers with usage amount == _input.size() (or common ones)
    map<string, int> handlers_count;
    for(auto &i:_input) {
        // a very inefficient approach, should be rewritten if will cause lags on UI
        set<string> inserted;
        for(auto &p:i.paths)
            // here we exclude multiple counting for repeating handlers for one content type
            if( !inserted.count(p) ) {
                handlers_count[p]++;
                inserted.insert(p);
            }
    }
    
    _result.paths.clear();
    _result.uti = default_uti;
    _result.default_path = -1;
    
    for(auto &i:handlers_count)
        if(i.second == _input.size()) {
            _result.paths.emplace_back(i.first);
            if(i.first == default_handler)
                _result.default_path = (int)_result.paths.size()-1;
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
