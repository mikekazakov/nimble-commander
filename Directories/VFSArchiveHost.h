//
//  VFSArchiveHost.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <map>
#import "VFSHost.h"
#import "VFSFile.h"


struct VFSArchiveMediator;
struct VFSArchiveDir;

class VFSArchiveHost : public VFSHost
{
public:
    VFSArchiveHost(const char *_junction_path,
                   std::shared_ptr<VFSHost> _parent);
    ~VFSArchiveHost();
    
    int Open(); // flags will be added later

    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)()) override;
    
    std::shared_ptr<VFSFile> ArFile() const;
    
    struct archive* Archive();
    
    std::shared_ptr<const VFSArchiveHost> SharedPtr() const {return std::static_pointer_cast<const VFSArchiveHost>(VFSHost::SharedPtr());}
    std::shared_ptr<VFSArchiveHost> SharedPtr() {return std::static_pointer_cast<VFSArchiveHost>(VFSHost::SharedPtr());}
private:
    int ReadArchiveListing();
    VFSArchiveDir* FindOrBuildDir(const char* _path_with_tr_sl);
    
    void InsertDummyDirInto(VFSArchiveDir *_parent, const char* _dir_name);
    
    std::shared_ptr<VFSFile>                m_ArFile;
    std::shared_ptr<VFSArchiveMediator>     m_Mediator;
    struct archive                         *m_Arc;
    std::map<std::string, VFSArchiveDir*>   m_PathToDir;
    
};
