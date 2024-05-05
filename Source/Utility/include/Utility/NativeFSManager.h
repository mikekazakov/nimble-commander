// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <vector>
#include <memory>
#include <atomic>
#include <mach/mach.h>

#ifndef __OBJC__
#include "NSCppDeclarations.h"
#else
#include <Foundation/Foundation.h>
#endif

namespace nc::utility {

struct NativeFileSystemInfo {
    NativeFileSystemInfo();
    NativeFileSystemInfo(const NativeFileSystemInfo &) = delete;
    ~NativeFileSystemInfo();
    NativeFileSystemInfo &operator=(const NativeFileSystemInfo &) = delete;

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
    std::string mounted_from_name;

    struct {
        /**
         * File system id.
         */
        fsid_t fs_id = {{0, 0}};

        /**
         * ID of device, used in stat() syscall.
         * As of 10.15, dev_it can *NOT* be used to derive 1:1 correspondense between stat and a fs.
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
        std::atomic_ulong total_blocks{0};

        /**
         * Free blocks in filesystem.
         */
        std::atomic_ulong free_blocks{0};

        /**
         * Free blocks in filesystem available to non-superuser.
         */
        std::atomic_ulong available_blocks{0};

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
        bool read_only : 1 = false;

        /**
         * File system is written to synchronously.
         */
        bool synchronous : 1 = false;

        /**
         * Can't exec from filesystem.
         */
        bool no_exec : 1 = false;

        /**
         * Setuid bits are not honored on this filesystem.
         */
        bool no_suid : 1 = false;

        /**
         * Don't interpret special files.
         */
        bool no_dev : 1 = false;

        /**
         * Union with underlying filesystem.
         */
        bool f_union : 1 = false;

        /**
         * File system written to asynchronously.
         */
        bool asynchronous : 1 = false;

        /**
         * File system is exported.
         */
        bool exported : 1 = false;

        /**
         * File system is stored locally.
         */
        bool local : 1 = false;

        /**
         * Quotas are enabled on this file system.
         */
        bool quota : 1 = false;

        /**
         * This file system is the root of the file system.
         */
        bool root : 1 = false;

        /**
         * File system supports volfs.
         */
        bool vol_fs : 1 = false;

        /**
         * File system is not appropriate path to user data.
         */
        bool dont_browse : 1 = false;

        /**
         * VFS will ignore ownership information on filesystem objects.
         */
        bool unknown_permissions : 1 = false;

        /**
         * File system was mounted by automounter.
         */
        bool auto_mounted : 1 = false;

        /**
         * File system is journaled.
         */
        bool journaled : 1 = false;

        /**
         * File system should defer writes.
         */
        bool defer_writes : 1 = false;

        /**
         * MAC support for individual labels.
         */
        bool multi_label : 1 = false;

        /**
         * File system supports per-file encrypted data protection.
         */
        bool cprotect : 1 = false;

        /**
         * True if the volume's media is ejectable from the drive mechanism under software control.
         */
        bool ejectable : 1 = false;

        /**
         * True if the volume's media is removable from the drive mechanism.
         */
        bool removable : 1 = false;

        /**
         * True if the volume's device is connected to an internal bus, false if connected to an external bus.
         */
        bool internal : 1 = false;
    } mount_flags;

    struct {
        /**
         * When set, the volume has object IDs that are persistent (retain their values even when the volume is
         * unmounted and remounted), and a file or directory can be looked up by ID.  Volumes that support VolFS
         * and can support Carbon File ID references should set this field.
         */
        bool persistent_objects_ids : 1 = false;

        /**
         * When set, the volume supports symbolic links.  The symlink(), readlink(), and lstat()
         * calls all use this symbolic link.
         */
        bool symbolic_links : 1 = false;

        /**
         * When set, the volume supports hard links.
         * The link() call creates hard links.
         */
        bool hard_links : 1 = false;

        /**
         * When set, the volume is capable of supporting a journal used to speed recovery in
         * case of unplanned shutdown (such as a power outage or crash).  This bit does not necessarily
         * mean the volume is actively using a journal for recovery.
         */
        bool journal : 1 = false;

        /**
         * When set, the volume is currently using a journal for use in speeding recovery after an
         * unplanned shutdown. This bit can be set only if "journal" is also set.
         */
        bool journal_active : 1 = false;

        /**
         * When set, the volume format does not store reliable times for the root directory,
         * so you should not depend on them to detect changes, etc.
         */
        bool no_root_times : 1 = false;

        /**
         * When set, the volume supports sparse files.
         * That is, files which can have "holes" that have never been written
         * to, and are not allocated on disk.  Sparse files may have an
         * allocated size that is less than the file's logical length.
         */
        bool sparse_files : 1 = false;

        /**
         * For security reasons, parts of a file (runs)
         * that have never been written to must appear to contain zeroes.  When
         * this bit is set, the volume keeps track of allocated but unwritten
         * runs of a file so that it can substitute zeroes without actually
         * writing zeroes to the media.  This provides performance similar to
         * sparse files, but not the space savings.
         */
        bool zero_runs : 1 = false;

        /**
         * When set, file and directory names are
         * case sensitive (upper and lower case are different).  When clear,
         * an upper case character is equivalent to a lower case character,
         * and you can't have two names that differ solely in the case of
         * the characters.
         */
        bool case_sensitive : 1 = false;

        /**
         * When set, file and directory names
         * preserve the difference between upper and lower case.  If clear,
         * the volume may change the case of some characters (typically
         * making them all upper or all lower case).  A volume that sets
         * "case_sensitive" should also set "case_preserving".
         */
        bool case_preserving : 1 = false;

        /**
         * This bit is used as a hint to upper layers
         * (especially Carbon) that statfs() is fast enough that its results
         * need not be cached by those upper layers.  A volume that caches
         * the statfs information in its in-memory structures should set this bit.
         * A volume that must always read from disk or always perform a network
         * transaction should not set this bit.
         */
        bool fast_statfs : 1 = false;

        /**
         * If this bit is set the volume format supports
         * file sizes larger than 4GB, and potentially up to 2TB; it does not
         * indicate whether the filesystem supports files larger than that.
         */
        bool filesize_2tb : 1 = false;

        /**
         * When set, the volume supports open deny
         * modes (e.g. "open for read write, deny write"; effectively, mandatory
         * file locking based on open modes).
         */
        bool open_deny_modes : 1 = false;

        /**
         * When set, the volume supports the UF_HIDDEN
         * file flag, and the UF_HIDDEN flag is mapped to that volume's native
         * "hidden" or "invisible" bit (which may be the invisible bit from the
         * Finder Info extended attribute).
         */
        bool hidden_files : 1 = false;

        /**
         * When set, the volume supports the ability
         * to derive a pathname to the root of the file system given only the
         * id of an object.  This also implies that object ids on this file
         * system are persistent and not recycled.  This is a very specialized
         * capability and it is assumed that most file systems will not support
         * it.  Its use is for legacy non-posix APIs like ResolveFileIDRef.
         */
        bool path_from_id : 1 = false;

        /**
         * When set, the volume does not support
         * returning values for total data blocks, available blocks, or free blocks
         * (as in f_blocks, f_bavail, or f_bfree in "struct statfs").  Historically,
         * those values were set to 0xFFFFFFFF for volumes that did not support them.
         */
        bool no_volume_sizes : 1 = false;

        /**
         * When set, the volume supports transparent
         * decompression of compressed files using decmpfs.
         */
        bool decmpfs_compression : 1 = false;

        /**
         * When set, the volume uses object IDs that
         * are 64-bit. This means that ATTR_CMN_FILEID and ATTR_CMN_PARENTID are the
         * only legitimate attributes for obtaining object IDs from this volume and the
         * 32-bit fid_objno fields of the fsobj_id_t returned by ATTR_CMN_OBJID,
         * ATTR_CMN_OBJPERMID, and ATTR_CMN_PAROBJID are undefined
         */
        bool object_ids_64bit : 1 = false;

        /**
         * When set, the volume supports directory hard links.
         */
        bool dir_hardlinks : 1 = false;

        /**
         * When set, the volume supports document IDs (an ID which persists across object ID
         * changes) for document revisions.
         */
        bool document_id : 1 = false;

        /**
         * When set, the volume supports write generation counts (a count of how many times
         * an object has been modified)
         */
        bool write_generation_count : 1 = false;

        /**
         * When set, the volume does not support setting the UF_IMMUTABLE flag.
         */
        bool no_immutable_files : 1 = false;

        /**
         * When set, the volume does not support setting permissions.
         */
        bool no_permissions : 1 = false;

        /**
         * When set, the volume supports sharing space with other filesystems i.e. multiple logical filesystems can
         * exist in the same "partition". An implication of this is that the filesystem which sets this capability
         * treats waitfor arguments to VFS_SYNC as bit flags.
         */
        bool shared_space : 1 = false;

        /**
         * When set, this volume is part of a volume-group that implies multiple volumes must be mounted in order to
         * boot and root the operating system. Typically, this means a read-only system volume and a writable data
         * volume.
         */
        bool volume_groups : 1 = false;

        /**
         * When set, this volume is cryptographically sealed. Any modifications to volume data or metadata will be
         * detected and may render the volume unusable.
         */
        bool sealed : 1 = false;
    } format;

    struct {
        /**
         * When set, the volume implements the
         * searchfs() system call (the vnop_searchfs vnode operation).
         */
        bool search_fs : 1 = false;

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
        bool attr_list : 1 = false;

        /**
         * When set, the volume implements exporting of NFS volumes.
         */
        bool nfs_export : 1 = false;

        /**
         * When set, the volume implements the
         * readdirattr() system call (vnop_readdirattr vnode operation)
         */
        bool read_dir_attr : 1 = false;

        /**
         * When set, the volume implements the
         * exchangedata() system call (VNOP_EXCHANGE vnode operation)
         */
        bool exchange_data : 1 = false;

        /**
         * When set, the volume implements the
         * VOP_COPYFILE vnode operation.  (XXX There should be a copyfile()
         * system call in <unistd.h>.)
         */
        bool copy_file : 1 = false;

        /**
         * When set, the volume implements the
         * VNOP_ALLOCATE vnode operation, which means it implements the
         * F_PREALLOCATE selector of fcntl(2).
         */
        bool allocate : 1 = false;

        /**
         * When set, the volume implements the
         * ATTR_VOL_NAME attribute for both getattrlist() and setattrlist().
         * The volume can be renamed by setting ATTR_VOL_NAME with setattrlist().
         */
        bool vol_rename : 1 = false;

        /**
         * When set, the volume implements POSIX style
         * byte range locks via vnop_advlock (accessible from fcntl(2)).
         */
        bool adv_lock : 1 = false;

        /**
         * When set, the volume implements whole-file flock(2)
         * style locks via vnop_advlock.  This includes the O_EXLOCK and O_SHLOCK
         * flags of the open(2) call.
         */
        bool file_lock : 1 = false;

        /**
         * When set, the volume implements extended security (ACLs).
         */
        bool extended_security : 1 = false;

        /**
         * When set, the volume supports the ATTR_CMN_USERACCESS attribute
         * (used to get the user's access mode to the file).
         * Obsolete(?).
         */
        bool user_access : 1 = false;

        /**
         * When set, the volume supports AFP-style mandatory byte range locks via an ioctl().
         */
        bool mandatory_lock : 1 = false;

        /**
         * When set, the volume implements native extended attribues.
         */
        bool extended_attr : 1 = false;

        /**
         * When set, the volume supports native named streams.
         */
        bool named_streams : 1 = false;

        /**
         * When set, the volume supports clones.
         */
        bool clone : 1 = false;

        /**
         * When set, the volume supports snapshots.
         */
        bool snapshot : 1 = false;

        /**
         * When set, the volume supports swapping file system objects.
         */
        bool rename_swap : 1 = false;

        /**
         * When set, the volume supports an exclusive rename operation.
         */
        bool rename_excl : 1 = false;

        /**
         * True if system can move files to trash for this volume for this user.
         */
        bool has_trash : 1 = false;
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
    using Info = std::shared_ptr<const NativeFileSystemInfo>;

    virtual ~NativeFSManager() = default;

    /**
     * Returns a list of volumes in a system.
     */
    virtual std::vector<Info> Volumes() const = 0;

    /**
     * VolumeFromFD() uses POSIX fstatfs() to get mount point for specified path,
     * and then calls VolumeFromMountPoint() method. Will return nullptr if _path points to invalid file/dir.
     */
    virtual Info VolumeFromFD(int _fd) const noexcept = 0;

    /**
     * VolumeFromPath() uses POSIX statfs() to get mount point for specified path,
     * and then calls VolumeFromMountPoint() method. Will return nullptr if _path points to invalid file/dir.
     */
    virtual Info VolumeFromPath(std::string_view _path) const noexcept = 0;

    /**
     * VolumeFromPathFast() chooses the closest volume to _path, using plain strings comparison.
     * It don't take into consideration invalid paths or symlinks following somewhere in _path,
     * so should be used very carefully only time-critical paths (this method doesn't make any syscalls).
     */
    virtual Info VolumeFromPathFast(std::string_view _path) const noexcept = 0;

    /**
     * VolumeFromMountPoint() searches to a volume mounted at _mount_point using plain strings comparison.
     * Is fast, since dont make any syscalls.
     */
    virtual Info VolumeFromMountPoint(std::string_view _mount_point) const noexcept = 0;

    /**
     * UpdateSpaceInformation() forces to fetch and recalculate space information contained in _volume.
     */
    virtual void UpdateSpaceInformation(const Info &_volume) = 0;

    /**
     * A very simple function with no error feedback.
     */
    virtual void EjectVolumeContainingPath(const std::string &_path) = 0;

    /**
     * Return true is volume can be programmatically ejected. Will return false on any errors.
     */
    virtual bool IsVolumeContainingPathEjectable(const std::string &_path) = 0;
};

} // namespace nc::utility
