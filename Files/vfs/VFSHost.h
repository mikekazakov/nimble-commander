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
    inline operator bool() const noexcept { return valid(); }
    bool valid() const noexcept;
    void reset();
    
private:
    VFSHostDirObservationTicket(const VFSHostDirObservationTicket &_rhs) = delete;
    VFSHostDirObservationTicket &operator=(const VFSHostDirObservationTicket &_rhs) = delete;
    unsigned long       m_Ticket;
    weak_ptr<VFSHost>   m_Host;
};

class VFSHost : public enable_shared_from_this<VFSHost>
{
public:
    static const char *Tag;    
    
    VFSHost(const char *_junction_path,         // junction path and parent can be nil
            shared_ptr<VFSHost> _parent,
            const char *_fs_tag);
    virtual ~VFSHost();
    
    virtual bool IsWriteable() const;
    
    /**
     * Default implementation returns IsWriteable();
     */
    virtual bool IsWriteableAtPath(const char *_dir) const;
    
    /**
     * Each virtual file system must return a unique statically allocated identifier string, specified at construction time.
     */
    const char *FSTag() const noexcept;
    
    /** Returns false for any VFS but native filesystem. */
    virtual bool IsNativeFS() const noexcept;
    
    /** Return true if filesystem content does not change while fs is opened. Presumably only archives can be immutable, so we can use some aggressive caching for them on higher layers. */
    virtual bool IsImmutableFS() const noexcept;
    
    /**
     * Returns a path of a filesystem root.
     * It may be a filepath for archive or network address for remote filesystem
     * or even zero thing for special virtual filesystems.
     */
    const char *JunctionPath() const noexcept;
    const VFSHostPtr& Parent() const noexcept;
    
    
    virtual int StatFS(const char *_path, // path may be a file path, or directory path
                       VFSStatFS &_stat,
                       VFSCancelChecker _cancel_checker);
    
    /**
     * Default implementation calls Stat() and then returns (st.mode & S_IFMT) == S_IFDIR.
     * On any errors returns false.
     */
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             VFSCancelChecker _cancel_checker);
    
    /**
     * Default implementation calls Stat() and then returns (st.mode & S_IFMT) == S_IFLNK.
     * On any errors returns false.
     */
    virtual bool IsSymlink(const char *_path,
                           int _flags,
                           VFSCancelChecker _cancel_checker);
    
    virtual int FetchFlexibleListing(const char *_path,
                                      shared_ptr<VFSListing> &_target,
                                      int _flags,
                                      VFSCancelChecker _cancel_checker);
    
    int FetchFlexibleListingItems(const string& _directory_path,
                                  const vector<string> &_filenames,
                                  int _flags,
                                  vector<VFSListingItem> &_result,
                                  VFSCancelChecker _cancel_checker);
    
    /**
     * IterateDirectoryListing will skip "." and ".." entries if they are present.
     * Do not rely on it to build a directory listing, it's for contents iteration.
     */
    virtual int IterateDirectoryListing(
                                    const char *_path,
                                    function<bool(const VFSDirEnt &_dirent)> _handler // return true for allowing iteration, false to stop it
                                    );
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker = nullptr);
    
    virtual int CreateDirectory(const char* _path,
                                int _mode,
                                VFSCancelChecker _cancel_checker
                                );
    
    virtual int CalculateDirectoriesSizes(
                                        const vector<string> &_dirs,
                                        const char* _root_path,
                                        VFSCancelChecker _cancel_checker,
                                        function<void(const char* _dir_sh_name, uint64_t _size)> _completion_handler);
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     VFSCancelChecker _cancel_checker);
    
    /** Actually calls Stat and returns true if return was Ok. */
    virtual bool Exists(const char *_path,
                        VFSCancelChecker _cancel_checker = nullptr
                        );
    
    /** Return zero upon succes, negative value on error. */
    virtual int ReadSymlink(const char *_symlink_path,
                            char *_buffer,
                            size_t _buffer_size,
                            VFSCancelChecker _cancel_checker = nullptr);

    /** Return zero upon succes, negative value on error. */
    virtual int CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              VFSCancelChecker _cancel_checker);
    
    /**
     * Unlinks(deletes) a file. Dont follow last symlink, in case of.
     * Don't delete directories, similar to POSIX.
     */
    virtual int Unlink(const char *_path, VFSCancelChecker _cancel_checker = nullptr);

    /**
     * Deletes an empty directory. Will fail on non-empty ones.
     */
    virtual int RemoveDirectory(const char *_path, VFSCancelChecker _cancel_checker = nullptr);
    
    /**
     * Change the name of a file.
     */
    virtual int Rename(const char *_old_path, const char *_new_path, VFSCancelChecker _cancel_checker = nullptr);
    
    /**
     * Adjust file node times. Any of timespec time pointers can be NULL, so they will be ignored.
     * NoFollow flag can be specified to alter symlink node itself.
     */
    virtual int SetTimes(const char *_path,
                         int _flags,
                         struct timespec *_birth_time,
                         struct timespec *_mod_time,
                         struct timespec *_chg_time,
                         struct timespec *_acc_time,
                         VFSCancelChecker _cancel_checker
                         );
    
    /**
     * DO NOT USE IT. Currently for experimental purposes only.
     * Returns a vector with all xattrs at _path, labeled with it's names.
     * On any error return negative value.
     */
    virtual int GetXAttrs(const char *_path, vector< pair<string, vector<uint8_t>>> &_xattrs);
    
    /**
     * Consequent calls should return the same object if no changes had occured.
     * I.e. Host HAVE to store this Configuration object inside.
     * (hosts with dummy configs can have a global const exemplars)
     */
    virtual VFSConfiguration Configuration() const;
    
    // return value 0 means error or unsupported for this VFS
    virtual bool IsDirChangeObservingAvailable(const char *_path);
    
    // _handler can be called from any thread
    virtual VFSHostDirObservationTicket DirChangeObserve(const char *_path, function<void()> _handler);
    virtual void StopDirChangeObserving(unsigned long _ticket);
    
    virtual bool ShouldProduceThumbnails() const;
    
    /**
     * Checks if _filenames contains a forbidden symbols and return false if found them.
     * Default implementation forbids ":\\/\r\t\n" chars, overrides may change this behaviour
     */
    virtual bool ValidateFilename(const char *_filename) const;
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   VFSCancelChecker _cancel_checker);

    static const shared_ptr<VFSHost> &DummyHost();
    
    inline shared_ptr<VFSHost> SharedPtr() { return shared_from_this(); }
    inline shared_ptr<const VFSHost> SharedPtr() const { return shared_from_this(); }
#define VFS_DECLARE_SHARED_PTR(_cl)\
    shared_ptr<const _cl> SharedPtr() const {return static_pointer_cast<const _cl>(VFSHost::SharedPtr());}\
    shared_ptr<_cl> SharedPtr() {return static_pointer_cast<_cl>(VFSHost::SharedPtr());}

private:
    const string                m_JunctionPath;         // path in Parent VFS, relative to it's root
    const shared_ptr<VFSHost>   m_Parent;
    const char*                 m_Tag;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
};

