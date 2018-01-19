// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <atomic>
#include <mach/mach.h>

#ifndef __OBJC__
typedef void *NSString;
typedef void *NSURL;
typedef void *NSImage;
#else
#include <Foundation/Foundation.h>
#endif

struct NativeFileSystemInfo
{
    /**
     * UNIX path to directory at which filesystem is mounted.
     */
    std::string mounted_at_path;

    /**
     * Filesystem's internal name, like "hfs", "devfs", "autofs", "mtmfs" and others.
     */
    std::string fs_type_name;

    /**
     * Name or which from this volume was mounted. Can be device name, network path or internal driver name.
     */
    string mounted_from_name;

    struct
    {
        /**
         * File system id.
         */
        fsid_t fs_id = {{0, 0}};
        
        /**
         * ID of device, used in stat() syscall
         */
        dev_t dev_id = 0;
        
        /**
         * User that mounted the filesystem.
         */
        uid_t owner = 0;
        
        /**
         * Fundamental file system block size.
         */
        uint32_t block_size = 0;

        /**
         * Optimal transfer block size.
         */
        uint32_t io_size = 0;

        /**
         * Total data blocks in file system.
         */
        mutable std::atomic_ulong total_blocks{0};
    
        /**
         * Free blocks in filesystem.
         */
        mutable std::atomic_ulong free_blocks{0};
    
        /**
         * Free blocks in filesystem available to non-superuser.
         */
        mutable std::atomic_ulong available_blocks{0};
    
        /**
         * Total file nodes in file system.
         */
        uint64_t total_nodes = 0;
    
        /**
         * Free file nodes in file system.
         */
        uint64_t free_nodes = 0;
    
        /**
         * Mount values from fstat.f_flags.
         */
        uint64_t mount_flags = 0;
        
        /**
         * Total data bytes in file system.
         */
        mutable std::atomic_ulong total_bytes{0};
        
        /**
         * Free bytes in filesystem.
         */
        mutable std::atomic_ulong free_bytes{0};
        
        /**
         * Free bytes in filesystem available to non-superuser.
         */
        mutable std::atomic_ulong available_bytes{0};
        
    } basic;
    
    struct {
        /**
         * A read-only filesystem.
         */
        bool read_only = false;
        
        /**
         * File system is written to synchronously.
         */
        bool synchronous = false;
        
        /**
         * Can't exec from filesystem.
         */
        bool no_exec = false;
        
        /**
         * Setuid bits are not honored on this filesystem.
         */
        bool no_suid = false;
        
        /**
         * Don't interpret special files.
         */
        bool no_dev = false;
        
        /**
         * Union with underlying filesystem.
         */
        bool f_union = false;
  
        /**
         * File system written to asynchronously.
         */
        bool asynchronous = false;
  
        /**
         * File system is exported.
         */
        bool exported = false;
        
        /**
         * File system is stored locally.
         */
        bool local = false;
        
        /**
         * Quotas are enabled on this file system.
         */
        bool quota = false;
  
        /**
         * This file system is the root of the file system.
         */
        bool root = false;
  
        /**
         * File system supports volfs.
         */
        bool vol_fs = false;
        
        /**
         * File system is not appropriate path to user data.
         */
        bool dont_browse = false;
        
        /**
         * VFS will ignore ownership information on filesystem objects.
         */
        bool unknown_permissions = false;
        
        /**
         * File system was mounted by automounter.
         */
        bool auto_mounted = false;
  
        /**
         * File system is journaled.
         */
        bool journaled = false;
  
        /**
         * File system should defer writes.
         */
        bool defer_writes = false;
        
        /**
         * MAC support for individual labels.
         */
        bool multi_label = false;
        
        /**
         * File system supports per-file encrypted data protection.
         */
        bool cprotect = false;
        
        /**
         * True if the volume's media is ejectable from the drive mechanism under software control.
         */
        bool ejectable = false;
        
        /**
         * True if the volume's media is removable from the drive mechanism.
         */
        bool removable = false;
        
        /**
         * True if the volume's device is connected to an internal bus, false if connected to an external bus.
         */
        bool internal = false;
        
    } mount_flags;

    struct
    {
        /**
         * When set, the volume has object IDs that are persistent (retain their values even when the volume is
         * unmounted and remounted), and a file or directory can be looked up by ID.  Volumes that support VolFS
         * and can support Carbon File ID references should set this field.
         */
        bool persistent_objects_ids = false;
        
        /**
         * When set, the volume supports symbolic links.  The symlink(), readlink(), and lstat()
         * calls all use this symbolic link.
         */
        bool symbolic_links = false;
        
        /**
         * When set, the volume supports hard links.
         * The link() call creates hard links.
         */
        bool hard_links = false;
        
        /** 
         * When set, the volume is capable of supporting a journal used to speed recovery in
         * case of unplanned shutdown (such as a power outage or crash).  This bit does not necessarily
         * mean the volume is actively using a journal for recovery.
         */
        bool journal = false;
        
        /** 
         * When set, the volume is currently using a journal for use in speeding recovery after an
         * unplanned shutdown. This bit can be set only if "journal" is also set.
         */
        bool journal_active = false;
        
        /**
         * When set, the volume format does not store reliable times for the root directory,
         * so you should not depend on them to detect changes, etc.
         */
        bool no_root_times = false;
        
        /**
         * When set, the volume supports sparse files.
         * That is, files which can have "holes" that have never been written
         * to, and are not allocated on disk.  Sparse files may have an
         * allocated size that is less than the file's logical length.
         */
        bool sparse_files = false;
        
        /** 
         * For security reasons, parts of a file (runs)
         * that have never been written to must appear to contain zeroes.  When
         * this bit is set, the volume keeps track of allocated but unwritten
         * runs of a file so that it can substitute zeroes without actually
         * writing zeroes to the media.  This provides performance similar to
         * sparse files, but not the space savings.
         */
        bool zero_runs = false;
        
        /**
         * When set, file and directory names are
         * case sensitive (upper and lower case are different).  When clear,
         * an upper case character is equivalent to a lower case character,
         * and you can't have two names that differ solely in the case of
         * the characters.
         */
        bool case_sensitive = false;
        
        /**
         * When set, file and directory names
         * preserve the difference between upper and lower case.  If clear,
         * the volume may change the case of some characters (typically
         * making them all upper or all lower case).  A volume that sets
         * "case_sensitive" should also set "case_preserving".
         */
        bool case_preserving = false;
        
        /**
         * This bit is used as a hint to upper layers
         * (especially Carbon) that statfs() is fast enough that its results
         * need not be cached by those upper layers.  A volume that caches
         * the statfs information in its in-memory structures should set this bit.
         * A volume that must always read from disk or always perform a network
         * transaction should not set this bit.
         */
        bool fast_statfs = false;
        
        /**
         * If this bit is set the volume format supports
         * file sizes larger than 4GB, and potentially up to 2TB; it does not
         * indicate whether the filesystem supports files larger than that.
         */
        bool filesize_2tb = false;
        
        /**
         * When set, the volume supports open deny
         * modes (e.g. "open for read write, deny write"; effectively, mandatory
         * file locking based on open modes).
         */
        bool open_deny_modes = false;
        
        /**
         * When set, the volume supports the UF_HIDDEN
         * file flag, and the UF_HIDDEN flag is mapped to that volume's native
         * "hidden" or "invisible" bit (which may be the invisible bit from the
         * Finder Info extended attribute).
         */
        bool hidden_files = false;
        
        /**
         * When set, the volume supports the ability
         * to derive a pathname to the root of the file system given only the
         * id of an object.  This also implies that object ids on this file
         * system are persistent and not recycled.  This is a very specialized
         * capability and it is assumed that most file systems will not support
         * it.  Its use is for legacy non-posix APIs like ResolveFileIDRef.
         */
        bool path_from_id = false;
        
        /**
         * When set, the volume does not support
         * returning values for total data blocks, available blocks, or free blocks
         * (as in f_blocks, f_bavail, or f_bfree in "struct statfs").  Historically,
         * those values were set to 0xFFFFFFFF for volumes that did not support them.
         */
        bool no_volume_sizes = false;
        
        /**
         * When set, the volume supports transparent
         * decompression of compressed files using decmpfs.
         */
        bool decmpfs_compression = false;
        
        /**
         * When set, the volume uses object IDs that
         * are 64-bit. This means that ATTR_CMN_FILEID and ATTR_CMN_PARENTID are the
         * only legitimate attributes for obtaining object IDs from this volume and the
         * 32-bit fid_objno fields of the fsobj_id_t returned by ATTR_CMN_OBJID,
         * ATTR_CMN_OBJPERMID, and ATTR_CMN_PAROBJID are undefined
         */
        bool object_ids_64bit = false;
        

        /**
         * When set, the volume supports directory hard links.
         */
        bool dir_hardlinks = false;

        /**
         * When set, the volume supports document IDs (an ID which persists across object ID
         * changes) for document revisions.
         */
        bool document_id = false;
        
        
        /**
         * When set, the volume supports write generation counts (a count of how many times
         * an object has been modified)
         */
        bool write_generation_count = false;
        

        /**
         * When set, the volume does not support setting the UF_IMMUTABLE flag.
         */
        bool no_immutable_files = false;
        
        /**
         * When set, the volume does not support setting permissions.
         */
        bool no_permissions = false;
    } format;
    
    struct
    {
        /**
         * When set, the volume implements the
         * searchfs() system call (the vnop_searchfs vnode operation).
         */
        bool search_fs = false;
        
        /**
         * When set, the volume implements the
         * getattrlist() and setattrlist() system calls (vnop_getattrlist
         * and vnop_setattrlist vnode operations) for the volume, files,
         * and directories.  The volume may or may not implement the
         * readdirattr() system call.  XXX Is there any minimum set
         * of attributes that should be supported?  To determine the
         * set of supported attributes, get the ATTR_VOL_ATTRIBUTES
         * attribute of the volume.
         */
        bool attr_list = false;
        
        /**
         * When set, the volume implements exporting of NFS volumes.
         */
        bool nfs_export = false;
        
        /**
         * When set, the volume implements the
         * readdirattr() system call (vnop_readdirattr vnode operation)
         */
        bool read_dir_attr = false;
        
        /**
         * When set, the volume implements the
         * exchangedata() system call (VNOP_EXCHANGE vnode operation)
         */
        bool exchange_data = false;
        
        /**
         * When set, the volume implements the
         * VOP_COPYFILE vnode operation.  (XXX There should be a copyfile()
         * system call in <unistd.h>.)
         */
        bool copy_file = false;
        
        /**
         * When set, the volume implements the
         * VNOP_ALLOCATE vnode operation, which means it implements the
         * F_PREALLOCATE selector of fcntl(2).
         */
        bool allocate = false;
        
        /**
         * When set, the volume implements the
         * ATTR_VOL_NAME attribute for both getattrlist() and setattrlist().
         * The volume can be renamed by setting ATTR_VOL_NAME with setattrlist().
         */
        bool vol_rename = false;

        /**
         * When set, the volume implements POSIX style
         * byte range locks via vnop_advlock (accessible from fcntl(2)).
         */
        bool adv_lock = false;
        
        /**
         * When set, the volume implements whole-file flock(2)
         * style locks via vnop_advlock.  This includes the O_EXLOCK and O_SHLOCK
         * flags of the open(2) call.
         */
        bool file_lock = false;
        
        /**
         * When set, the volume implements extended security (ACLs).
         */
        bool extended_security = false;
        
        /**
         * When set, the volume supports the ATTR_CMN_USERACCESS attribute
         * (used to get the user's access mode to the file).
         * Obsolete(?).
         */
        bool user_access = false;
        
        /**
         * When set, the volume supports AFP-style mandatory byte range locks via an ioctl().
         */
        bool mandatory_lock = false;
        
        /**
         * When set, the volume implements native extended attribues.
         */
        bool extended_attr = false;
        
        /**
         * When set, the volume supports native named streams.
         */
        bool named_streams = false;

        /**
         * When set, the volume supports clones.
         */
        bool clone = false;

        /**
         * When set, the volume supports swapping file system objects.
         */
        bool rename_swap = false;
        
        /**
         * When set, the volume supports an exclusive rename operation.
         */
        bool rename_excl = false;
        
        /**
         * True if system can move files to trash for this volume for this user.
         */
        bool has_trash = false;
    } interfaces;

    
    struct {
        /**
         * UNIX path to directory at which filesystem is mounted, in NSString form.
         */
        NSString *mounted_at_path = nullptr;
        
        /**
         * UNIX path to directory at which filesystem is mounted, in NSURL form.
         */
        NSURL *url = nullptr;
        
        /**
         * The name of the volume (settable if NSURLVolumeSupportsRenamingKey is YES).
         */
        NSString *name = nullptr;
        
        /**
         * The user-presentable name of the volume.
         */
        NSString *localized_name = nullptr;
        
        /**
         * The icon normally displayed for the resource.
         */
        NSImage *icon = nullptr;
        
    } verbose;
};

class NativeFSManager
{
public:
    static NativeFSManager &Instance();
    
    using Info = std::shared_ptr<const NativeFileSystemInfo>;
    
    /**
     * Returns a list of volumes in a system.
     */
    std::vector<Info> Volumes() const;
    
    Info VolumeFromFD(int _fd) const;
    Info VolumeFromDevID(dev_t _dev_id) const;
    
    /**
     * VolumeFromPath() uses POSIX statfs() to get mount point for specified path,
     * and then calls VolumeFromMountPoint() method. Will return nullptr if _path points to invalid file/dir.
     */
    Info VolumeFromPath(const string &_path) const;
    
    /**
     * VolumeFromPath() uses POSIX statfs() to get mount point for specified path,
     * and then calls VolumeFromMountPoint() method. Will return nullptr if _path points to invalid file/dir.
     */
    Info VolumeFromPath(const char* _path) const;
    
    /**
     * VolumeFromPathFast() chooses the closest volume to _path, using plain strings comparison.
     * It don't take into consideration invalid paths or symlinks following somewhere in _path,
     * so should be used very carefully only time-critical paths (this method dont make any syscalls).
     */
    Info VolumeFromPathFast(const string &_path) const;
    
    /**
     * VolumeFromMountPoint() searches to a volume mounted at _mount_point using plain strings comparison.
     * Is fast, since dont make any syscalls.
     */
    Info VolumeFromMountPoint(const string &_mount_point) const;

    /**
     * VolumeFromMountPoint() searches to a volume mounted at _mount_point using plain strings comparison.
     * Is fast, since dont make any syscalls.
     */
    Info VolumeFromMountPoint(const char *_mount_point) const;
    
    /**
     * UpdateSpaceInformation() forces to fetch and recalculate space information contained in _volume.
     */
    void UpdateSpaceInformation(const Info &_volume);
    
    /**
     * A very simple function with no error feedback.
     */
    void EjectVolumeContainingPath(const std::string &_path);
    
    /**
     * Return true is volume can be programmatically ejected. Will return false on any errors.
     */
    bool IsVolumeContainingPathEjectable(const std::string &_path);
    
private:
    NativeFSManager();
    NativeFSManager(const NativeFSManager&) = delete;
    void operator=(const NativeFSManager&) = delete;
        
    void OnDidMount(const std::string &_on_path);
    void OnWillUnmount(const std::string &_on_path);
    void OnDidUnmount(const std::string &_on_path);
    void OnDidRename(const std::string &_old_path, const std::string &_new_path);
    Info VolumeFromDevID_Unlocked(dev_t _dev_id) const;
    Info VolumeFromMountPoint_Unlocked(const char *_mount_point) const;
    Info VolumeFromPathFast_Unlocked(const string &_path) const;
    void InsertNewVolume_Unlocked( const shared_ptr<NativeFileSystemInfo> &_volume );
    
    mutable std::mutex m_Lock;
    std::vector<std::shared_ptr<NativeFileSystemInfo>> m_Volumes;
    
    friend struct NativeFSManagerProxy2;
};
