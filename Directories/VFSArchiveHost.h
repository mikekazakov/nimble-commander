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
    
    virtual const char *FSTag() const override;
    
    int Open(); // flags will be added later

    
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)()) override;
    
    virtual int Stat(const char *_path, struct stat &_st, int _flags, bool (^_cancel_checker)()) override;    
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)()) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> *_target,
                                      bool (^_cancel_checker)()) override;
    
    virtual int IterateDirectoryListing(const char *_path, bool (^_handler)(dirent &_dirent)) override;
    
    virtual int CalculateDirectoriesSizes(
                                          FlexChainedStringsChunk *_dirs, // transfered ownership
                                          const std::string &_root_path, // relative to current host path
                                          bool (^_cancel_checker)(),
                                          void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                          ) override;
    virtual int CalculateDirectoryDotDotSize( // will pass ".." as _dir_sh_name upon completion
                                             const std::string &_root_path, // relative to current host path
                                             bool (^_cancel_checker)(),
                                             void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                             ) override;
    
    
    
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
