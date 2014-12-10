//
//  DisplayNamesCache.mm
//  Files
//
//  Created by Michael G. Kazakov on 28.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "DisplayNamesCache.h"

#include "Common.h"

static_assert(sizeof(DisplayNamesCache::DisplayName) == 32, "");

inline static uint64_t FSIDTo64(fsid_t _id)
{
    return *(uint64_t*)&_id;
}

inline static void form_path(char *_buf, const char *_directory, const char *_filename)
{
    size_t s1 = strlen(_directory);
    memcpy(_buf, _directory, s1);
    if(_buf[s1-1] != '/') {
        _buf[s1-1] = '/';
        s1++;
    }
    strcpy(_buf + s1, _filename);
}

DisplayNamesCache& DisplayNamesCache::Instance()
{
    static DisplayNamesCache inst;
    return inst;
}

const DisplayNamesCache::DisplayName &DisplayNamesCache::DisplayNameForNativeFS(fsid_t _fs,
                                                                                uint64_t _inode,
                                                                                const char *_directory,
                                                                                const char *_c_filename,
                                                                                CFStringRef _cf_filename
                                                                                )
{
    static DisplayName dummy;
    if(_inode == 0 || !_directory || !_c_filename || !_cf_filename || !_directory[0] || !_c_filename[0])
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

    if(map.size() >= MaxSize) { // we're too fat, need to wipe info out
        for(auto &i: map)
            if(i.second.str != nullptr)
                CFRelease(i.second.str);
        map.clear();
    }
    
    // get dispay name for file
    DisplayName e;
    e.filename = _c_filename;
    
    char path[MAXPATHLEN];
    form_path(path, _directory, _c_filename);

    NSString *strpath = [NSString stringWithUTF8StringNoCopy:path];
    if(strpath == nil) {
        // can't create string for this path.
        return map.emplace(_inode, move(e)).first->second;
    }
    
    static NSFileManager *filemanager = NSFileManager.defaultManager;
    NSString *display = [filemanager displayNameAtPath:strpath];
    if(display == nil) {
        // something strange has happen
        return map.emplace(_inode, move(e)).first->second;
    }
    
    display = [display decomposedStringWithCanonicalMapping];
    if([display isEqualToString:(__bridge NSString *)_cf_filename]) {
        // just the same
        return map.emplace(_inode, move(e)).first->second;
    }
    else {
        display = [display precomposedStringWithCanonicalMapping];
        e.str = (CFStringRef)CFBridgingRetain(display);
        return map.emplace(_inode, move(e)).first->second;
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

