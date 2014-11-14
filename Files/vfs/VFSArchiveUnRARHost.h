//
//  VFSArchiveUnRARHost.h
//  Files
//
//  Created by Michael G. Kazakov on 02.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSHost.h"
#import "VFSFile.h"
#import "DispatchQueue.h"

struct VFSArchiveUnRAREntry;
struct VFSArchiveUnRARDirectory;
struct VFSArchiveUnRARSeekCache;

class VFSArchiveUnRARHost : public VFSHost
{
public:
    static const char *Tag;
    VFSArchiveUnRARHost(const char *_junction_path);
    ~VFSArchiveUnRARHost();
    
    virtual const char *FSTag() const override;
    virtual bool IsImmutableFS() const noexcept override;

    static bool IsRarArchive(const char *_archive_native_path);
    int Open(); // flags will be added later
    
    
    // core VFSHost methods
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      VFSCancelChecker _cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        function<bool(const VFSDirEnt &_dirent)> _handler) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     VFSCancelChecker _cancel_checker) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;
    
    
    virtual bool ShouldProduceThumbnails() const override;
    
    
    // internal UnRAR stuff
    
    /**
     * Return zero on not found.
     */
    uint32_t ItemUUID(const string& _filename) const;

    /**
     * Returns UUID of a last item in archive.
     */
    uint32_t LastItemUUID() const;

    /**
     * Return nullptr on not found.
     */
    const VFSArchiveUnRAREntry *FindEntry(const string &_full_path) const;
    
    /**
     * Inserts opened rar handle into host's seek cache.
     */
    void CommitSeekCache(unique_ptr<VFSArchiveUnRARSeekCache> _sc);
    
    /**
     * if there're no appropriate caches, host will try to open a new RAR handle.
     * If can't satisfy this call - zero ptr is returned.
     */
    unique_ptr<VFSArchiveUnRARSeekCache> SeekCache(uint32_t _requested_item);
    
    
    VFS_DECLARE_SHARED_PTR(VFSArchiveUnRARHost);
private:
    
    int InitialReadFileList(void *_rar_handle);

    VFSArchiveUnRARDirectory *FindOrBuildDirectory(const string& _path_with_tr_sl);
    const VFSArchiveUnRARDirectory *FindDirectory(const string& _path) const;
    
    map<string, VFSArchiveUnRARDirectory>   m_PathToDir; // path to dir with trailing slash -> directory contents
    uint32_t                                m_LastItemUID = 0;
    list<unique_ptr<VFSArchiveUnRARSeekCache>> m_SeekCaches;
    dispatch_queue_t                           m_SeekCacheControl;
    uint64_t                                m_PackedItemsSize = 0;
    uint64_t                                m_UnpackedItemsSize = 0;
    bool                                    m_IsSolidArchive = false;
    struct stat                             m_ArchiveFileStat;

    // TODO: int m_FD for exclusive lock?
};
