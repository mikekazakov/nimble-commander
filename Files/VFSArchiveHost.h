//
//  VFSArchiveHost.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSHost.h"
#import "VFSFile.h"

struct VFSArchiveMediator;
struct VFSArchiveDir;
struct VFSArchiveDirEntry;
struct VFSArchiveState;

class VFSArchiveHost : public VFSHost
{
public:
    VFSArchiveHost(const char *_junction_path,
                   shared_ptr<VFSHost> _parent);
    ~VFSArchiveHost();
    
    static const char *Tag;
    virtual const char *FSTag() const override;
    
    int Open(); // flags will be added later

    
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             VFSCancelChecker _cancel_checker) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker) override;
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,                                      
                                      VFSCancelChecker _cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler) override;
    
    virtual bool ShouldProduceThumbnails() const override;

    inline uint32_t StatTotalFiles() const { return m_TotalFiles; }
    inline uint32_t StatTotalDirs() const { return m_TotalDirs; }
    inline uint32_t StatTotalRegs() const { return m_TotalRegs; }
    
    // Caching section - to reduce seeking overhead:
    
    // return zero on not found
    uint32_t ItemUID(const char* _filename);
    
    unique_ptr<VFSArchiveState> ClosestState(uint32_t _requested_item);
    void CommitState(unique_ptr<VFSArchiveState> _state);
    
    // use SeekCache or open a new file and seeks to requested item
    int ArchiveStateForItem(const char *_filename, unique_ptr<VFSArchiveState> &_target);
    
    shared_ptr<const VFSArchiveHost> SharedPtr() const {return static_pointer_cast<const VFSArchiveHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSArchiveHost> SharedPtr() {return static_pointer_cast<VFSArchiveHost>(VFSHost::SharedPtr());}
private:
    int ReadArchiveListing();
    VFSArchiveDir* FindOrBuildDir(const char* _path_with_tr_sl);
    const VFSArchiveDirEntry *FindEntry(const char* _path);
    
    void InsertDummyDirInto(VFSArchiveDir *_parent, const char* _dir_name);
    struct archive* SpawnLibarchive();
    
    shared_ptr<VFSFile>                m_ArFile;
    shared_ptr<VFSArchiveMediator>     m_Mediator;
    struct archive                         *m_Arc;
    
    
// TODO: change this to map<string, VFSArchiveDir>
    map<string, VFSArchiveDir*>   m_PathToDir;
    uint32_t                                m_TotalFiles = 0;
    uint32_t                                m_TotalDirs = 0;
    uint32_t                                m_TotalRegs = 0;
    uint64_t                                m_ArchiveFileSize = 0;
    uint64_t                                m_ArchivedFilesTotalSize = 0;
    uint32_t                                m_LastItemUID = 0;
    
    list<unique_ptr<VFSArchiveState>>       m_States;
    mutex                                   m_StatesLock;
};
