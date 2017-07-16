//
//  VFSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "VFSError.h"
#include "VFSDeclarations.h"
#include "VFSConfiguration.h"
#include "VFSFactory.h"
#include "VFSListing.h"

class VFSHostDirObservationTicket
{
public:
    VFSHostDirObservationTicket() noexcept;
    VFSHostDirObservationTicket(unsigned long _ticket, weak_ptr<VFSHost> _host) noexcept;
    VFSHostDirObservationTicket(VFSHostDirObservationTicket &&_rhs) noexcept;
    ~VFSHostDirObservationTicket();
    
    VFSHostDirObservationTicket &operator=(VFSHostDirObservationTicket &&_rhs);
    operator bool() const noexcept;
    bool valid() const noexcept;
    void reset();
    
private:
    VFSHostDirObservationTicket(const VFSHostDirObservationTicket &_rhs) = delete;
    VFSHostDirObservationTicket &operator=(const VFSHostDirObservationTicket &_rhs) = delete;
    unsigned long       m_Ticket;
    weak_ptr<VFSHost>   m_Host;
};

struct VFSHostFeatures
{
    enum Features : uint64_t {
        FetchUsers      = 1  <<  0,
        FetchGroups     = 1  <<  1,
        SetPermissions  = 1  <<  2,
        SetFlags        = 1  <<  3,
        SetOwnership    = 1  <<  4,
        SetTimes        = 1  <<  5
    };
};

class VFSHost : public enable_shared_from_this<VFSHost>
{
public:
    static const char *Tag;
    static const shared_ptr<VFSHost> &DummyHost();
    
    /**
     * junction path and parent can be nil
     */
    VFSHost(const char *_junction_path, const shared_ptr<VFSHost> &_parent, const char *_fs_tag);
    virtual ~VFSHost();
    
    
    /***********************************************************************************************
     * Configuration / meta data
     **********************************************************************************************/

    shared_ptr<VFSHost> SharedPtr();
    shared_ptr<const VFSHost> SharedPtr() const;

    /**
     * Consequent calls should return the same object if no changes had occured.
     * I.e. Host HAVE to store this Configuration object inside.
     * (hosts with dummy configs can have a global const exemplars)
     */
    virtual VFSConfiguration Configuration() const;

    /**
     * Each virtual file system must return a unique statically allocated identifier string, 
     * specified at construction time.
     */
    const char *FSTag() const noexcept;
    
    /**
     * Returns a path of a filesystem root.
     * It may be a filepath for archive or network address for remote filesystem
     * or even "" for special virtual filesystems or for native filesystem.
     */
    const char *JunctionPath() const noexcept;

    /**
     * Hosted filesystems, like archives, must have a parent vfs.
     */
    const VFSHostPtr& Parent() const noexcept;
    
    /** 
     * Returns false for any VFS but native filesystem.
     */
    virtual bool IsNativeFS() const noexcept;

    /** Return true if filesystem content does not change while fs is opened. Presumably only 
     * archives can be immutable, so we can use some aggressive caching for them on higher layers.
     */
    virtual bool IsImmutableFS() const noexcept;
    
    /**
     * Get a set of features of this VFSHost implementation.
     * A bitset with it's bits corresponding an enumeration in VFSHostFeatures.
     */
    uint64_t Features() const noexcept;
    
    /**
     * _callback will be exectuded in VFSHost dectructor, just before this instance will die.
     * Do not access VFSHost via pointer parameter, it should be used only for identification.
     */
    void SetDesctructCallback( function<void(const VFSHost*)> _callback );
    
    
    /***********************************************************************************************
     * Probing, information, lookup
     **********************************************************************************************/
    
    /**
     * Check if filesystem can be written to in theory, on any location.
     * By default any VFS is not writable, i.e. read-only.
     */
    virtual bool IsWritable() const;
    
    /**
     * Default implementation returns IsWritable();
     */
    virtual bool IsWritableAtPath(const char *_dir) const;
    
    /**
     * VFS version of stat().
     * Default implementation does nothing, subclass MUST implement it.
     */
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * VFS version of statfs().
     * Path may be a file path or a directory path.
     */
    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Default implementation calls Stat() and then returns (st.mode & S_IFMT) == S_IFDIR.
     * On any errors returns false.
     */
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Default implementation calls Stat() and then returns (st.mode & S_IFMT) == S_IFLNK.
     * On any errors returns false.
     */
    virtual bool IsSymlink(const char *_path,
                           int _flags,
                           const VFSCancelChecker &_cancel_checker = nullptr);
    
    /** Return zero upon succes, negative value on error. */
    virtual int ReadSymlink(const char *_symlink_path,
                            char *_buffer,
                            size_t _buffer_size,
                            const VFSCancelChecker &_cancel_checker = nullptr);
    
    /** 
     * Default implementation calls Stat() and returns true if return was Ok.
     */
    virtual bool Exists(const char *_path,
                        const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Checks if _filenames contains a forbidden symbols and return false if found them.
     * Default implementation forbids ":\\/\r\t\n" chars, overrides may change this behaviour
     */
    virtual bool ValidateFilename(const char *_filename) const;
    
    /**
     * DO NOT USE IT. Currently for experimental purposes only.
     * Returns a vector with all xattrs at _path, labeled with it's names.
     * On any error return negative value.
     */
    virtual int GetXAttrs(const char *_path, vector< pair<string, vector<uint8_t>>> &_xattrs);
    
    virtual ssize_t CalculateDirectorySize(const char *_path,
                                           const VFSCancelChecker &_cancel_checker = nullptr);
    
    virtual bool ShouldProduceThumbnails() const;
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   const VFSCancelChecker &_cancel_checker = nullptr);

    virtual int FetchUsers(vector<VFSUser> &_target,
                                 const VFSCancelChecker &_cancel_checker = nullptr);

    virtual int FetchGroups(vector<VFSGroup> &_target,
                                  const VFSCancelChecker &_cancel_checker = nullptr);
    
    /***********************************************************************************************
     * Directories iteration, listings fetching
     **********************************************************************************************/
    
    /**
     * Produce a regular directory listing.
     */
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> &_target,
                                      int _flags,
                                      const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Produce a regular listing, consisting of a single element.
     * If there's no overriden implementaition in derived class, VFSHost will try to produce
     * this listing with Stat().
     */
    virtual int FetchSingleItemListing(const char *_path_to_item,
                                       shared_ptr<VFSListing> &_target,
                                       int _flags,
                                       const VFSCancelChecker &_cancel_checker = nullptr);

    /**
     * IterateDirectoryListing will skip "." and ".." entries if they are present.
     * Do not rely on it to build a directory listing, it's for contents iteration.
     * _handler: return true to allow further iteration, false to stop it.
     */
    virtual int IterateDirectoryListing(const char *_path,
                                        const function<bool(const VFSDirEnt &_dirent)> &_handler);
    
    int FetchFlexibleListingItems(const string& _directory_path,
                                  const vector<string> &_filenames,
                                  int _flags,
                                  vector<VFSListingItem> &_result,
                                  const VFSCancelChecker &_cancel_checker);

    
    /***********************************************************************************************
     * Making changes to the filesystem
     **********************************************************************************************/
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker = nullptr);
    
    virtual int CreateDirectory(const char* _path,
                                int _mode,
                                const VFSCancelChecker &_cancel_checker = nullptr);
    
    /** Return zero upon succes, negative value on error. */
    virtual int CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Unlinks(deletes) a file. Dont follow last symlink, in case of.
     * Don't delete directories, similar to POSIX.
     */
    virtual int Unlink(const char *_path,
                       const VFSCancelChecker &_cancel_checker = nullptr);

    /**
     * Deletes an empty directory. Will fail on non-empty ones.
     */
    virtual int RemoveDirectory(const char *_path,
                                const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Moves an item into trash bin.
     */
    virtual int Trash(const char *_path,
                      const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Change the name of a file.
     */
    virtual int Rename(const char *_old_path,
                       const char *_new_path,
                       const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Adjust file node times.
     * NoFollow flag can be specified to alter symlink node itself.
     */
    virtual int SetTimes(const char *_path,
                         optional<time_t> _birth_time,
                         optional<time_t> _mod_time,
                         optional<time_t> _chg_time,
                         optional<time_t> _acc_time,
                         const VFSCancelChecker &_cancel_checker = nullptr);
    
    /**
     * Change permissions similarly to chmod().
     */
    virtual int SetPermissions(const char *_path,
                               uint16_t _mode,
                               const VFSCancelChecker &_cancel_checker = nullptr);

    /**
     * Change flags similarly to chflags().
     */
    virtual int SetFlags(const char *_path,
                         uint32_t _flags,
                         const VFSCancelChecker &_cancel_checker = nullptr);

    /**
     * Change ownership similarly to chown().
     */
    virtual int SetOwnership(const char *_path,
                             unsigned _uid,
                             unsigned _gid,
                             const VFSCancelChecker &_cancel_checker = nullptr);
    
    /***********************************************************************************************
     * Observation of changes
     **********************************************************************************************/

    /**
     * Default implementation doesn't provide any observation functionality.
     */
    virtual bool IsDirChangeObservingAvailable(const char *_path);
    
    /**
     * _handler can be called from any thread
     */
    virtual VFSHostDirObservationTicket DirChangeObserve(const char *_path,
                                                         function<void()> _handler);
    
protected:
    void SetFeatures( uint64_t _features_bitset );
    void AddFeatures( uint64_t _features_bitset );
    
private:
    virtual void StopDirChangeObserving(unsigned long _ticket);

    const string                    m_JunctionPath; // path in Parent VFS, relative to it's root
    const shared_ptr<VFSHost>       m_Parent;
    const char*                     m_Tag;
    uint64_t                        m_Features;
    function<void(const VFSHost*)>  m_OnDesctruct;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
    friend class VFSHostDirObservationTicket;
};
