//
//  DisplayNamesCache.h
//  Files
//
//  Created by Michael G. Kazakov on 28.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <sys/mount.h>

/**
 * Presumably should be used only on directories.
 * STA design, no internal locks included, but can be locked at whole object level.
 */
class DisplayNamesCache : public mutex
{
public:
    static DisplayNamesCache& Instance();

    struct DisplayName
    {
        string filename = "";
        CFStringRef str = nullptr;
    };
    
    const DisplayName &DisplayNameForNativeFS(fsid_t _fs,
                                              uint64_t _inode,
                                              const char *_directory,
                                              const char *_c_filename,
                                              CFStringRef _cf_filename
                                              );
private:
    map<uint64_t, DisplayName> &ByFSID(uint64_t _id);
    vector< pair<uint64_t, map<uint64_t, DisplayName>>> m_DB;
};
