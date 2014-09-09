//
//  LSUrls.m
//  Files
//
//  Created by Michael G. Kazakov on 06.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LSUrls.h"
#import "Common.h"

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

LauchServicesHandlers LauchServicesHandlers::GetForItem(const VFSListingItem &_it, const VFSHostPtr &_host, const char* _path)
{
    LauchServicesHandlers result;
    
    if(_host->IsNativeFS())
    {
        if(_it.HasExtension()) {
            if(CFStringRef ext = CFStringCreateWithUTF8StringNoCopy(_it.Extension())) {
                if(CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL)) {
                    result.uti = ((__bridge NSString*)UTI).UTF8String;
                    CFRelease(UTI);
                }
                CFRelease(ext);
            }
        }
        
        if(CFURLRef url = CFURLCreateFromFileSystemRepresentation(0, (const UInt8*)_path, strlen(_path), false))
        {
            CFURLRef default_app_url;
            if(LSGetApplicationForURL(url, kLSRolesAll, 0, &default_app_url) == 0)
            {
                NSArray *apps = (NSArray *)CFBridgingRelease(LSCopyApplicationURLsForURL(url, kLSRolesAll));
                int ind = 0;
                for(NSURL *url in apps)
                {
                    result.paths.push_back(url.path.fileSystemRepresentation);
                    if([(__bridge NSURL*)(default_app_url) isEqual: url])
                        result.default_path = ind;
                    ++ind;
                }
                CFRelease(default_app_url);
            }
            CFRelease(url);
        }
    }
    else
    {
        if(_it.IsDir())
            return move(result);
                
        if(_it.HasExtension())
        {
            CFStringRef ext = CFStringCreateWithUTF8StringNoCopy(_it.Extension());
            CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL);
            CFRelease(ext);
            if(UTI != 0)
            {
                result.uti = [((__bridge NSString*)UTI) UTF8String];
                NSString *default_bundle = (__bridge_transfer id)LSCopyDefaultRoleHandlerForContentType(UTI,kLSRolesAll);
                NSArray *apps = (NSArray *)CFBridgingRelease(LSCopyAllRoleHandlersForContentType(UTI,kLSRolesAll));
                int ind = 0;
                for (NSString* bundleIdentifier in apps)
                {
                    NSString* nspath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: bundleIdentifier];
                    if(nspath)
                    {
                        const char *path = [nspath fileSystemRepresentation];
                        result.paths.push_back(path);
                        if([bundleIdentifier isEqualToString:default_bundle])
                            result.default_path = ind;
                        ++ind;
                    }
                }
                CFRelease(UTI);
            }
        }
    }
    return move(result);
}

void LauchServicesHandlers::DoMerge(const list<LauchServicesHandlers>& _input, LauchServicesHandlers& _result)
{
    // empty handler path means that there's no default handler available
    string default_handler = all_equal_or_default(begin(_input), end(_input), [](auto &i){
        return i.default_path >= 0 ? i.paths[i.default_path] : string(""); }, string(""));
    
    // empty default_uti means that uti's are different in _input
    string default_uti = all_equal_or_default(begin(_input), end(_input), [](auto &i){ return i.uti; }, string(""));
    
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

bool LauchServicesHandlers::SetDefaultHandler(const char *_uti, const char* _path)
{
    assert(_uti != 0 && _path != 0);
    
    NSString *path = [NSString stringWithUTF8String:_path];
    if(!path)
        return false;
    
    NSString *uti = [NSString stringWithUTF8String:_uti];
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
