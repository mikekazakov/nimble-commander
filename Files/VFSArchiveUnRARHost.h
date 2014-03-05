//
//  VFSArchiveUnRARHost.h
//  Files
//
//  Created by Michael G. Kazakov on 02.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <map>
#import <list>
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
    

    int Open(); // flags will be added later
    
    
    // core VFSHost methods
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)()) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        bool (^_handler)(const VFSDirEnt &_dirent)) override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     bool (^_cancel_checker)()) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)()) override;
    
    
    virtual bool ShouldProduceThumbnails() override;    
    
    
    // internal UnRAR stuff
    
    /**
     * Return zero on not found.
     */
    uint32_t ItemUUID(const string& _filename) const;

    /**
     * Return nullptr on not found.
     */
    const VFSArchiveUnRAREntry *FindEntry(const string &_full_path) const;
    
    /**
     * Destructive call - will override currently stored one
     */
//    void CommitSeekCache(shared_ptr<VFSArchiveSeekCache> _sc);
    
    /**
     * if there're no appropriate caches, host will try to open a new RAR handle.
     * If can't satisfy this call - zero ptr is returned.
     */
    unique_ptr<VFSArchiveUnRARSeekCache> SeekCache(uint32_t _requested_item);
    
    shared_ptr<const VFSArchiveUnRARHost> SharedPtr() const {return static_pointer_cast<const VFSArchiveUnRARHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSArchiveUnRARHost> SharedPtr() {return static_pointer_cast<VFSArchiveUnRARHost>(VFSHost::SharedPtr());}

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
    bool                                    m_IsSolidArchive;

    // TODO: int m_FD for exclusive lock?
};
