//
//  QLVFSThumbnailsCache.h
//  Files
//
//  Created by Michael G. Kazakov on 14/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "vfs/VFS.h"

class QLVFSThumbnailsCache
{
public:
    static QLVFSThumbnailsCache &Instance() noexcept;
    
    /** return pair: <did found?, value> */
    pair<bool, NSImage*> Get(const string& _path, const VFSHostPtr &_host);
    void        Put(const string& _path, const VFSHostPtr &_host, NSImage *_img);
    
private:
    void Purge();
    struct Cache
    {
        VFSHost                 *host_raw;
        weak_ptr<VFSHost>        host_weak;
        map<string, NSImage*>    images;
    };
    
    list<Cache> m_Caches;
    mutex       m_Lock;
    atomic_bool m_PurgeScheduled{false};
};
