// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

/*
class QLVFSThumbnailsCache
{
public:
    static QLVFSThumbnailsCache &Instance() noexcept;
    
    // return pair: <did found?, value>
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


*/


namespace nc::utility {
    
class QLVFSThumbnailsCache
{
public:
    virtual ~QLVFSThumbnailsCache() = default;
    
    virtual NSImage *ProduceFileThumbnail(const std::string &_file_path,
                                          VFSHost &_host,
                                          int _px_size) = 0;
    
    virtual NSImage *ProduceBundleThumbnail(const std::string &_file_path,
                                            VFSHost &_host,
                                            int _px_size) = 0;
    

//    virtual NSImage *ProduceThumbnail(const std::string &_file_path,
//                                      int _px_size) = 0;    
    
};

}
