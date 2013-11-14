//
//  LSUrls.m
//  Files
//
//  Created by Michael G. Kazakov on 06.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <set>
#import "LSUrls.h"
#import "Common.h"

void LauchServicesHandlers::DoOnItem(const VFSListingItem* _it, std::shared_ptr<VFSHost> _host, const char* _path, LauchServicesHandlers* _result)
{
    _result->uti.clear();
    _result->paths.clear();
    _result->default_path = -1;
    
    if(_host->IsNativeFS())
    {
        if(_it->HasExtension()) {
            if(CFStringRef ext = CFStringCreateWithUTF8StringNoCopy(_it->Extension())) {
                if(CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL)) {
                    _result->uti = [((__bridge NSString*)UTI) UTF8String];
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
                    _result->paths.push_back([[url path] fileSystemRepresentation]);
                    if([(__bridge NSURL*)(default_app_url) isEqual: url])
                        _result->default_path = ind;
                    ++ind;
                }
                CFRelease(default_app_url);
            }
            CFRelease(url);
        }
    }
    else
    {
        if(_it->IsDir())
            return;
                
        if(_it->HasExtension())
        {
            CFStringRef ext = CFStringCreateWithUTF8StringNoCopy(_it->Extension());
            CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL);
            CFRelease(ext);
            if(UTI != 0)
            {
                _result->uti = [((__bridge NSString*)UTI) UTF8String];
                NSString *default_bundle = (__bridge_transfer id)LSCopyDefaultRoleHandlerForContentType(UTI,kLSRolesAll);
                NSArray *apps = (NSArray *)CFBridgingRelease(LSCopyAllRoleHandlersForContentType(UTI,kLSRolesAll));
                int ind = 0;
                for (NSString* bundleIdentifier in apps)
                {
                    NSString* nspath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: bundleIdentifier];
                    if(nspath)
                    {
                        const char *path = [nspath fileSystemRepresentation];
                        _result->paths.push_back(path);
                        if([bundleIdentifier isEqualToString:default_bundle])
                            _result->default_path = ind;
                        ++ind;
                    }
                }
                CFRelease(UTI);
            }
        }
    }
}

void LauchServicesHandlers::DoMerge(const std::list<LauchServicesHandlers>* _input, LauchServicesHandlers* _result)
{
    std::string default_handler; // empty handler path means that there's no default handler available
    std::string default_uti; // -""-
    if(!_input->empty())
    {
        int ind = (*_input->begin()).default_path;
        if(ind >= 0)
            default_handler = (*_input->begin()).paths[ind];
        
        for(auto i = _input->begin()++, e = _input->end(); i!=e ; ++i)
        {
            int nind = (*i).default_path;
            if(ind < 0)
            {
                default_handler = "";
                break;
            }
            
            const std::string &ndefault_handler = (*i).paths[nind];
            if(ndefault_handler != default_handler)
            {
                default_handler = "";
                break;
            }
        }
        
        default_uti = (*_input->begin()).uti;
        for(auto i = _input->begin()++, e = _input->end(); i!=e ; ++i)
            if((*i).uti != default_uti)
            {
                default_uti = "";
                break;
            }
    }
    
    // maps handler path to usage amount
    // then use only handlers with usage amount == _input.size() (or common ones)
    std::map<std::string, int> handlers_count;
    
    for(auto i1 = _input->begin(), e1 = _input->end(); i1!=e1; ++i1)
    {
        std::set<std::string> inserted; // a very inefficient approach, should be rewritten if will cause lags on UI
        for(auto i2 = (*i1).paths.begin(), e2 = (*i1).paths.end(); i2!=e2; ++i2)
            if(inserted.find(*i2) == inserted.end()) // here we exclude multiple counting for repeating handlers for one content type
            {
                handlers_count[*i2]++;
                inserted.insert(*i2);
            }
    }
    int total_input = (int)_input->size();
    
    _result->paths.clear();
    _result->uti = default_uti;
    _result->default_path = -1;
    
    for(auto i = handlers_count.begin(), e = handlers_count.end(); i!=e; ++i)
        if(i->second == total_input)
        {
            _result->paths.push_back(i->first);
            if(i->first == default_handler)
                _result->default_path = (int)_result->paths.size()-1;
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
