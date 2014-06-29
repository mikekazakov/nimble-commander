//
//  DisplayNamesCache.mm
//  Files
//
//  Created by Michael G. Kazakov on 28.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "DisplayNamesCache.h"

#include "Common.h"

inline static uint64_t FSIDTo64(fsid_t _id)
{
    return *(uint64_t*)&_id;
}

DisplayNamesCache& DisplayNamesCache::Instance()
{
    static dispatch_once_t onceToken;
    static unique_ptr<DisplayNamesCache> inst;
    dispatch_once(&onceToken, ^{
        inst = make_unique<DisplayNamesCache>();
    });
    return *inst;
}

const DisplayNamesCache::DisplayName &DisplayNamesCache::DisplayNameForNativeFS(fsid_t _fs,
                                                                                uint64_t _inode,
                                                                                const char *_directory,
                                                                                const char *_c_filename,
                                                                                CFStringRef _cf_filename
                                                                                )
{
    static DisplayName dummy;
    if(_inode == 0)
        return dummy;
    
    auto &map = ByFSID(FSIDTo64(_fs));
    auto it = map.find(_inode);
    if(it != map.end()) {
        // we have entry with the same inode#

        if(it->second.filename == _c_filename)
            return it->second; // ok, seem to be valid, return it
        else {
            if(it->second.str != nullptr)
                CFRelease(it->second.str);
            map.erase(it); // seems that entry was renamed, need to rebuild information
        }
    }
    
    // get dispay name for file
    DisplayName e;
    e.filename = _c_filename;
    e.str = nullptr;
    
    
    string path = _directory;
    if(path.back() != '/') path += '/';
    path += _c_filename;
    
    NSString *strpath = [NSString stringWithUTF8StdStringNoCopy:path];
    if(strpath == nil) {
        // can't create string for this path.
        return map.emplace(_inode, e).first->second;
    }
    
    static NSFileManager *filemanager = NSFileManager.defaultManager;
    NSString *display = [filemanager displayNameAtPath:strpath];
    if(display == nil) {
        // something strange has happen
        return map.emplace(_inode, e).first->second;
    }
    
    display = [display decomposedStringWithCanonicalMapping];
    if([display isEqualToString:(__bridge NSString *)_cf_filename]) {
        // just the same
        return map.emplace(_inode, e).first->second;
    }
    else {
        display = [display precomposedStringWithCanonicalMapping];
        e.str = (CFStringRef)CFBridgingRetain(display);
        return map.emplace(_inode, e).first->second;
    }
}

map<uint64_t, DisplayNamesCache::DisplayName> &DisplayNamesCache::ByFSID(uint64_t _id)
{
    for(auto &m: m_DB)
        if(m.first == _id)
            return m.second;
    m_DB.emplace_back(_id, map<uint64_t, DisplayName>());
    return m_DB.back().second;
}

