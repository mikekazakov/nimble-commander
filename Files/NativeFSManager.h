//
//  NativeFSManager.h
//  Files
//
//  Created by Michael G. Kazakov on 22.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#ifndef __OBJC__
typedef void *NSString;
typedef void *NSURL;
typedef void *NSImage;
#endif

struct NativeFileSystemInfo
{
    /**
     * UNIX path to directory at which filesystem is mounted.
     */
    string mounted_at_path;

    /**
     * Filesystem's internal name, like "hfs", "devfs", "autofs", "mtmfs" and others.
     */
    string fs_type_name;

    /**
     * Name or which from this volume was mounted. Can be device name, network path or internal driver name.
     */
    string mounted_from_name;

    struct
    {
        /**
         * File system id.
         */
        fsid_t fs_id;
        
        /**
         * User that mounted the filesystem.
         */
        uid_t owner;
        
        /**
         * Fundamental file system block size.
         */
        uint32_t block_size;

        /**
         * Optimal transfer block size.
         */
        uint32_t io_size;

        /**
         * Total data blocks in file system.
         */
        uint64_t total_blocks;
    
        /**
         * Free blocks in filesystem.
         */
        uint64_t free_blocks;
    
        /**
         * Free blocks in filesystem available to non-superuser.
         */
        uint64_t available_blocks;
    
        /**
         * Total file nodes in file system.
         */
        uint64_t total_nodes;
    
        /**
         * Free file nodes in file system.
         */
        uint64_t free_nodes;
    
        /**
         * Mount values from fstat.f_flags.
         */
        uint64_t mount_flags;
        
        /**
         * Total data bytes in file system.
         */
        uint64_t total_bytes;
        
        /**
         * Free bytes in filesystem.
         */
        uint64_t free_bytes;
        
        /**
         * Free bytes in filesystem available to non-superuser.
         */
        uint64_t available_bytes;
        
    } basic;
    
    struct {
        /**
         * A read-only filesystem.
         */
        bool read_only;
        
        /**
         * File system is written to synchronously.
         */
        bool synchronous;
        
        /**
         * Can't exec from filesystem.
         */
        bool no_exec;
        
        /**
         * Setuid bits are not honored on this filesystem.
         */
        bool no_suid;
        
        /**
         * Don't interpret special files.
         */
        bool no_dev;
        
        /**
         * Union with underlying filesystem.
         */
        bool f_union;
  
        /**
         * File system written to asynchronously.
         */
        bool asynchronous;
  
        /**
         * File system is exported.
         */
        bool exported;
        
        /**
         * File system is stored locally.
         */
        bool local;
        
        /**
         * Quotas are enabled on this file system.
         */
        bool quota;
  
        /**
         * This file system is the root of the file system.
         */
        bool root;
  
        /**
         * File system supports volfs.
         */
        bool vol_fs;
        
        /**
         * File system is not appropriate path to user data.
         */
        bool dont_browse;
        
        /**
         * VFS will ignore ownership information on filesystem objects.
         */
        bool unknown_permissions;
        
        /**
         * File system was mounted by automounter.
         */
        bool auto_mounted;
  
        /**
         * File system is journaled.
         */
        bool journaled;
  
        /**
         * File system should defer writes.
         */
        bool defer_writes;
        
        /**
         * MAC support for individual labels.
         */
        bool multi_label;
        
        /**
         * File system supports per-file encrypted data protection.
         */
        bool cprotect;
        
        /**
         * True if the volume's media is ejectable from the drive mechanism under software control.
         */
        bool ejectable;
        
        /**
         * True if the volume's media is removable from the drive mechanism.
         */
        bool removable;
        
        /**
         * True if the volume's device is connected to an internal bus, false if connected to an external bus.
         */
        bool internal;
        
    } mount_flags;

    struct
    {
        /**
         * When set, the volume has object IDs that are persistent (retain their values even when the volume is
         * unmounted and remounted), and a file or directory can be looked up by ID.  Volumes that support VolFS
         * and can support Carbon File ID references should set this field.
         */
        bool persistent_objects_ids;
        
        /**
         * When set, the volume supports symbolic links.  The symlink(), readlink(), and lstat()
         * calls all use this symbolic link.
         */
        bool symbolic_links;
        
        /**
         * When set, the volume supports hard links.
         * The link() call creates hard links.
         */
        bool hard_links;
        
        /** 
         * When set, the volume is capable of supporting a journal used to speed recovery in
         * case of unplanned shutdown (such as a power outage or crash).  This bit does not necessarily
         * mean the volume is actively using a journal for recovery.
         */
        bool journal;
        
        /** 
         * When set, the volume is currently using a journal for use in speeding recovery after an
         * unplanned shutdown. This bit can be set only if "journal" is also set.
         */
        bool journal_active;
        
        /**
         * When set, the volume format does not store reliable times for the root directory,
         * so you should not depend on them to detect changes, etc.
         */
        bool no_root_times;
        
        /**
         * When set, the volume supports sparse files.
         * That is, files which can have "holes" that have never been written
         * to, and are not allocated on disk.  Sparse files may have an
         * allocated size that is less than the file's logical length.
         */
        bool sparse_files;
        
        /** 
         * For security reasons, parts of a file (runs)
         * that have never been written to must appear to contain zeroes.  When
         * this bit is set, the volume keeps track of allocated but unwritten
         * runs of a file so that it can substitute zeroes without actually
         * writing zeroes to the media.  This provides performance similar to
         * sparse files, but not the space savings.
         */
        bool zero_runs;
        
        /**
         * When set, file and directory names are
         * case sensitive (upper and lower case are different).  When clear,
         * an upper case character is equivalent to a lower case character,
         * and you can't have two names that differ solely in the case of
         * the characters.
         */
        bool case_sensitive;
        
        /**
         * When set, file and directory names
         * preserve the difference between upper and lower case.  If clear,
         * the volume may change the case of some characters (typically
         * making them all upper or all lower case).  A volume that sets
         * "case_sensitive" should also set "case_preserving".
         */
        bool case_preserving;
        
        /**
         * This bit is used as a hint to upper layers
         * (especially Carbon) that statfs() is fast enough that its results
         * need not be cached by those upper layers.  A volume that caches
         * the statfs information in its in-memory structures should set this bit.
         * A volume that must always read from disk or always perform a network
         * transaction should not set this bit.
         */
        bool fast_statfs;
        
        /**
         * If this bit is set the volume format supports
         * file sizes larger than 4GB, and potentially up to 2TB; it does not
         * indicate whether the filesystem supports files larger than that.
         */
        bool filesize_2tb;
        
        /**
         * When set, the volume supports open deny
         * modes (e.g. "open for read write, deny write"; effectively, mandatory
         * file locking based on open modes).
         */
        bool open_deny_modes;
        
        /**
         * When set, the volume supports the UF_HIDDEN
         * file flag, and the UF_HIDDEN flag is mapped to that volume's native
         * "hidden" or "invisible" bit (which may be the invisible bit from the
         * Finder Info extended attribute).
         */
        bool hidden_files;
        
        /**
         * When set, the volume supports the ability
         * to derive a pathname to the root of the file system given only the
         * id of an object.  This also implies that object ids on this file
         * system are persistent and not recycled.  This is a very specialized
         * capability and it is assumed that most file systems will not support
         * it.  Its use is for legacy non-posix APIs like ResolveFileIDRef.
         */
        bool path_from_id;
        
        /**
         * When set, the volume does not support
         * returning values for total data blocks, available blocks, or free blocks
         * (as in f_blocks, f_bavail, or f_bfree in "struct statfs").  Historically,
         * those values were set to 0xFFFFFFFF for volumes that did not support them.
         */
        bool no_volume_sizes;
        
        /**
         * When set, the volume supports transparent
         * decompression of compressed files using decmpfs.
         */
        bool decmpfs_compression;
        
        /**
         * When set, the volume uses object IDs that
         * are 64-bit. This means that ATTR_CMN_FILEID and ATTR_CMN_PARENTID are the
         * only legitimate attributes for obtaining object IDs from this volume and the
         * 32-bit fid_objno fields of the fsobj_id_t returned by ATTR_CMN_OBJID,
         * ATTR_CMN_OBJPERMID, and ATTR_CMN_PAROBJID are undefined
         */
        bool object_ids_64bit;
        
    } format;
    
    struct
    {
        /**
         * When set, the volume implements the
         * searchfs() system call (the vnop_searchfs vnode operation).
         */
        bool search_fs;
        
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
        bool attr_list;
        
        /**
         * When set, the volume implements exporting of NFS volumes.
         */
        bool nfs_export;
        
        /**
         * When set, the volume implements the
         * readdirattr() system call (vnop_readdirattr vnode operation)
         */
        bool read_dir_attr;
        
        /**
         * When set, the volume implements the
         * exchangedata() system call (VNOP_EXCHANGE vnode operation)
         */
        bool exchange_data;
        
        /**
         * When set, the volume implements the
         * VOP_COPYFILE vnode operation.  (XXX There should be a copyfile()
         * system call in <unistd.h>.)
         */
        bool copy_file;
        
        /**
         * When set, the volume implements the
         * VNOP_ALLOCATE vnode operation, which means it implements the
         * F_PREALLOCATE selector of fcntl(2).
         */
        bool allocate;
        
        /**
         * When set, the volume implements the
         * ATTR_VOL_NAME attribute for both getattrlist() and setattrlist().
         * The volume can be renamed by setting ATTR_VOL_NAME with setattrlist().
         */
        bool vol_rename;

        /**
         * When set, the volume implements POSIX style
         * byte range locks via vnop_advlock (accessible from fcntl(2)).
         */
        bool adv_lock;
        
        /**
         * When set, the volume implements whole-file flock(2)
         * style locks via vnop_advlock.  This includes the O_EXLOCK and O_SHLOCK
         * flags of the open(2) call.
         */
        bool file_lock;
        
        /**
         * When set, the volume implements extended security (ACLs).
         */
        bool extended_security;
        
        /**
         * When set, the volume supports the ATTR_CMN_USERACCESS attribute
         * (used to get the user's access mode to the file).
         * Obsolete(?).
         */
        bool user_access;
        
        /**
         * When set, the volume supports AFP-style mandatory byte range locks via an ioctl().
         */
        bool mandatory_lock;
        
        /**
         * When set, the volume implements native extended attribues.
         */
        bool extended_attr;
        
        /**
         * When set, the volume supports native named streams.
         */
        bool named_streams;
        
        /**
         * True if system can move files to trash for this volume for this user.
         * NB! need to check this on AFP servers (however, AFP is dead now).
         */
        bool has_trash;
    } interfaces;

    
    struct {
        /**
         * UNIX path to directory at which filesystem is mounted, in NSString form.
         */
        NSString *mounted_at_path;
        
        /**
         * UNIX path to directory at which filesystem is mounted, in NSURL form.
         */
        NSURL *url;
        
        /**
         * The name of the volume (settable if NSURLVolumeSupportsRenamingKey is YES).
         */
        NSString *name;
        
        /**
         * The user-presentable name of the volume.
         */
        NSString *localized_name;
        
        /**
         * The icon normally displayed for the resource.
         */
        NSImage *icon;
        
    } verbose;
};


// TODO: return volumes by shared_ptr<const ...> so clients can't modify it in theory


class NativeFSManager
{
public:
    static NativeFSManager &Instance();
    
    /**
     * Returns a list of volumes in a system.
     */
    vector<shared_ptr<NativeFileSystemInfo>> Volumes() const;
    
    
    /**
     * VolumeFromPath() uses POSIX statfs() to get mount point for specified path,
     * and then calls VolumeFromMountPoint() method. Will return nullptr if _path points to invalid file/dir.
     */
    shared_ptr<NativeFileSystemInfo> VolumeFromPath(const string &_path) const;
    
    /**
     * VolumeFromPath() uses POSIX statfs() to get mount point for specified path,
     * and then calls VolumeFromMountPoint() method. Will return nullptr if _path points to invalid file/dir.
     */
    shared_ptr<NativeFileSystemInfo> VolumeFromPath(const char* _path) const;
    
    /**
     * VolumeFromPathFast() chooses the closest volume to _path, using plain strings comparison.
     * It don't take into consideration invalid paths or symlinks following somewhere in _path,
     * so should be used very carefully only time-critical paths (this method dont make any syscalls).
     */
    shared_ptr<NativeFileSystemInfo> VolumeFromPathFast(const string &_path) const;
    
    /**
     * VolumeFromMountPoint() searches to a volume mounted at _mount_point using plain strings comparison.
     * Is fast, since dont make any syscalls.
     */
    shared_ptr<NativeFileSystemInfo> VolumeFromMountPoint(const string &_mount_point) const;

    /**
     * VolumeFromMountPoint() searches to a volume mounted at _mount_point using plain strings comparison.
     * Is fast, since dont make any syscalls.
     */
    shared_ptr<NativeFileSystemInfo> VolumeFromMountPoint(const char *_mount_point) const;
    
    /**
     * UpdateSpaceInformation() forces to fetch and recalculate space information contained in _volume.
     */
    void UpdateSpaceInformation(const shared_ptr<NativeFileSystemInfo> &_volume);
    
    /**
     * A very simple function with no error feedback.
     */
    void EjectVolumeContainingPath(const string &_path);
    
    /**
     * Return true is volume can be programmatically ejected. Will return false on any errors.
     */
    bool IsVolumeContainingPathEjectable(const string &_path);
    
private:
    NativeFSManager();
    
    static void GetAllInfos(NativeFileSystemInfo &_volume);
    static bool GetBasicInfo(NativeFileSystemInfo &_volume);
    static bool GetFormatInfo(NativeFileSystemInfo &_volume);
    static bool GetInterfacesInfo(NativeFileSystemInfo &_volume);
    static bool GetVerboseInfo(NativeFileSystemInfo &_volume);
    static bool UpdateSpaceInfo(NativeFileSystemInfo &_volume);
    static bool VolumeHasTrash(const string &_volume_path);
    
    void OnDidMount(string _on_path);
    void OnWillUnmount(string _on_path);
    void OnDidUnmount(string _on_path);
    void OnDidRename(string _old_path, string _new_path);
    
    mutable recursive_mutex                  m_Lock;
    vector<shared_ptr<NativeFileSystemInfo>> m_Volumes;
    
    friend struct NativeFSManagerProxy2;
};
