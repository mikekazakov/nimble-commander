//
//  VFSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <memory>

#import "VFSError.h"

class VFSListing;
class VFSFile;

class VFSHost : public std::enable_shared_from_this<VFSHost>
{
public:
    VFSHost(const char *_junction_path,         // junction path and parent can be nil
            std::shared_ptr<VFSHost> _parent);
    virtual ~VFSHost();
    
    virtual bool IsWriteable() const;
    // TODO: IsWriteableAtPath
    
    const char *JunctionPath() const;
    std::shared_ptr<VFSHost> Parent() const;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> *_target,
                                      bool (^_cancel_checker)());
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)());

    inline std::shared_ptr<VFSHost> SharedPtr() { return shared_from_this(); }
    inline std::shared_ptr<const VFSHost> SharedPtr() const { return shared_from_this(); }
private:
    std::string m_JunctionPath;         // path in Parent VFS, relative to it's root
    std::shared_ptr<VFSHost> m_Parent;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
};
