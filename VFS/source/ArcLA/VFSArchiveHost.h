//
//  VFSArchiveHost.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../include/VFS/VFSHost.h"
#include "../../include/VFS/VFSFile.h"

struct VFSArchiveMediator;
struct VFSArchiveDir;
struct VFSArchiveDirEntry;
struct VFSArchiveState;

class VFSArchiveHost final : public VFSHost
{
public:
    VFSArchiveHost(const string &_path, const VFSHostPtr &_parent, optional<string> _password = nullopt, VFSCancelChecker _cancel_checker = nullptr); // flags will be added later
    VFSArchiveHost(const VFSHostPtr &_parent, const VFSConfiguration &_config, VFSCancelChecker _cancel_checker = nullptr);
    ~VFSArchiveHost();
    
    static const char *Tag;
    virtual VFSConfiguration Configuration() const override;    
    static VFSMeta Meta();

    
    virtual bool IsImmutableFS() const noexcept override;
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             const VFSCancelChecker &_cancel_checker) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker) override;
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> &_target,
                                      int _flags,
                                      const VFSCancelChecker &_cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path, const function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    
    virtual int ReadSymlink(const char *_symlink_path, char *_buffer, size_t _buffer_size, const VFSCancelChecker &_cancel_checker) override;
    
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
    
    /** return VFSError, not uids returned */
    int ResolvePathIfNeeded(const char *_path, char *_resolved_path, int _flags);
    
    enum class SymlinkState
    {
        /** symlink is ok to use */
        Resolved     = 0,
        /** default value - never tried to resolve */
        Unresolved   = 1,
        /** can't resolve symlink since it point to non-existant file or if some error occured while resolving */
        Invalid      = 2,
        /** symlink resolving resulted in loop, thus symlink can't be used */
        Loop         = 3
    };
    
    struct Symlink
    {
        SymlinkState state  = SymlinkState::Unresolved;
        string       value  = "";
        uint32_t     uid    = 0; // uid of symlink entry itself
        uint32_t     target_uid = 0;   // meaningful only if state == SymlinkState::Resolved
        string       target_path = ""; // meaningful only if state == SymlinkState::Resolved
    };
    
    /** searches for entry in archive without any path resolving */
    const VFSArchiveDirEntry *FindEntry(const char* _path);
    
    /** searches for entry in archive by id */
    const VFSArchiveDirEntry *FindEntry(uint32_t _uid);
    
    /** find symlink and resolves it if not already. returns nullptr on error. */
    const Symlink *ResolvedSymlink(uint32_t _uid);
    
private:
    int DoInit(VFSCancelChecker _cancel_checker);
    const class VFSArchiveHostConfiguration &Config() const;
    
    int ReadArchiveListing();
    VFSArchiveDir* FindOrBuildDir(const char* _path_with_tr_sl);
    
    
    void InsertDummyDirInto(VFSArchiveDir *_parent, const char* _dir_name);
    struct archive* SpawnLibarchive();
    
    /**
     * any positive number - item's uid, good to go.
     * negative number or zero - error
     */
    int ResolvePath(const char *_path, char *_resolved_path);
    
    void ResolveSymlink(uint32_t _uid);
    
    VFSConfiguration                        m_Configuration;
    shared_ptr<VFSFile>                     m_ArFile;
    shared_ptr<VFSArchiveMediator>          m_Mediator;
    struct archive                         *m_Arc = nullptr;
    map<string, VFSArchiveDir>              m_PathToDir;
    uint32_t                                m_TotalFiles = 0;
    uint32_t                                m_TotalDirs = 0;
    uint32_t                                m_TotalRegs = 0;
    uint64_t                                m_ArchiveFileSize = 0;
    uint64_t                                m_ArchivedFilesTotalSize = 0;
    uint32_t                                m_LastItemUID = 0;

    bool                                    m_NeedsPathResolving = false; // true if there are any symlinks present in archive
    map<uint32_t, Symlink>                  m_Symlinks;
    recursive_mutex                         m_SymlinksResolveLock;
    
    vector< pair<VFSArchiveDir*, uint32_t>> m_EntryByUID; // points to directory and entry No inside it
    vector<unique_ptr<VFSArchiveState>>     m_States;
    mutex                                   m_StatesLock;
};
