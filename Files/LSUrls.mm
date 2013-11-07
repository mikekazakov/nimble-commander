//
//  LSUrls.m
//  Files
//
//  Created by Michael G. Kazakov on 06.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LSUrls.h"

void LauchServicesHandlers::DoOnItem(const VFSListingItem* _it, std::shared_ptr<VFSHost> _host, const char* _path, LauchServicesHandlers* _result)
{
    _result->paths.clear();
    _result->default_path = -1;
    
    if(_host->IsNativeFS())
    {
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:_path]];
        CFURLRef default_app_url;
        if(LSGetApplicationForURL((__bridge CFURLRef) url, kLSRolesAll, 0, &default_app_url) == 0)
        {
            NSArray *apps = (NSArray *)CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef) url,kLSRolesAll));
    
            int ind = 0;
            for(NSURL *url in apps)
            {
                const char *path = [url fileSystemRepresentation];
                _result->paths.push_back(path);
                if([(__bridge NSURL*)(default_app_url) isEqual: url])
                    _result->default_path = ind;
                
                ++ind;
            }
        }
    }
    else
    {
        if(_it->IsDir())
            return;
                
        if(_it->HasExtension())
        {
            NSString *ext = [NSString stringWithUTF8String:_it->Extension()];
            CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL);
        
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
        }
    }
    
    
}

void LauchServicesHandlers::DoMerge(const std::list<LauchServicesHandlers>* _input, LauchServicesHandlers* _result)
{
    std::string default_handler; // empty handler path means that there's no default handler available
    if(!_input->empty())
    {
        int ind = (*_input->begin()).default_path;
        if(ind >= 0)
            default_handler = (*_input->begin()).paths[ind];
        
        auto i = _input->begin()++;
        auto e = _input->end();
        for(;i!=e;++i)
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
    }
    
    // maps handler path to usage amount
    // then use only handlers with usage amount == _input.size() (or common ones)
    std::map<std::string, int> handlers_count;
    for(auto i1 = _input->begin(), e1 = _input->end(); i1!=e1; ++i1)
        for(auto i2 = (*i1).paths.begin(), e2 = (*i1).paths.end(); i2!=e2; ++i2)
            handlers_count[*i2]++;
    int total_input = (int)_input->size();
    
    _result->paths.clear();
    _result->default_path = -1;
    
    for(auto i = handlers_count.begin(), e = handlers_count.end(); i!=e; ++i)
        if(i->second == total_input)
        {
            _result->paths.push_back(i->first);
            if(i->first == default_handler)
                _result->default_path = (int)_result->paths.size()-1;
        }
}
