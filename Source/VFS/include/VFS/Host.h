// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/Error.h>
#include "VFSError.h"
#include "VFSDeclarations.h"
#include "VFSConfiguration.h"
#include "VFSFactory.h"
#include "../../source/Listing.h"
#include <optional>
#include <string_view>
#include <span>
#include <expected>

namespace nc::vfs {

class HostDirObservationTicket
{
public:
    HostDirObservationTicket() noexcept;
    HostDirObservationTicket(unsigned long _ticket, std::weak_ptr<Host> _host) noexcept;
    HostDirObservationTicket(HostDirObservationTicket &&_rhs) noexcept;
    ~HostDirObservationTicket();

    HostDirObservationTicket &operator=(HostDirObservationTicket &&_rhs) noexcept;
    operator bool() const noexcept;
    bool valid() const noexcept;
    void reset();

private:
    HostDirObservationTicket(const HostDirObservationTicket &_rhs) = delete;
    HostDirObservationTicket &operator=(const HostDirObservationTicket &_rhs) = delete;
    unsigned long m_Ticket;
    std::weak_ptr<Host> m_Host;
};

class FileObservationToken
{
public:
    FileObservationToken() noexcept = default;
    FileObservationToken(unsigned long _token, std::weak_ptr<Host> _host) noexcept;
    FileObservationToken(const FileObservationToken &_rhs) = delete;
    FileObservationToken(FileObservationToken &&_rhs) noexcept;
    ~FileObservationToken();

    FileObservationToken &operator=(const FileObservationToken &_rhs) = delete;
    FileObservationToken &operator=(FileObservationToken &&_rhs) noexcept;

    operator bool() const noexcept;
    void reset() noexcept;

private:
    unsigned long m_Token = 0;
    std::weak_ptr<Host> m_Host;
};

struct HostFeatures {
    enum Features : uint64_t {
        FetchUsers = 1 << 0,
        FetchGroups = 1 << 1,
        SetPermissions = 1 << 2,
        SetFlags = 1 << 3,
        SetOwnership = 1 << 4,
        SetTimes = 1 << 5,
        NonEmptyRmDir = 1 << 6
    };
};

class Host : public std::enable_shared_from_this<Host>
{
public:
    static const char *UniqueTag;
    static const std::shared_ptr<Host> &DummyHost();

    /**
     * junction path and parent can be nil
     */
    Host(std::string_view _junction_path, const std::shared_ptr<Host> &_parent, const char *_fs_tag);
    virtual ~Host();

    /***********************************************************************************************
     * Configuration / meta data
     **********************************************************************************************/

    std::shared_ptr<Host> SharedPtr();
    std::shared_ptr<const Host> SharedPtr() const;

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
    const char *Tag() const noexcept;

    /**
     * Returns a path of the filesystem root.
     * It may be a filepath for archive or network address for remote filesystem
     * or even "" for special virtual filesystems or for native filesystem.
     */
    std::string_view JunctionPath() const noexcept;

    /**
     * Hosted filesystems, like archives, must have a parent vfs.
     */
    const VFSHostPtr &Parent() const noexcept;

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
    void SetDesctructCallback(std::function<void(const VFSHost *)> _callback);

    /**
     * Calculates a hash of a string representation of a hosts stack and the corresponding path.
     * Should not be used for an offline state storing.
     */
    uint64_t FullHashForPath(std::string_view _path) const noexcept;

    std::string MakePathVerbose(std::string_view _path) const;

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
    virtual bool IsWritableAtPath(std::string_view _dir) const;

    /**
     * Tell if VFS differs between "Filename" and "filename" starting from a _dir.
     * In case of error will return "true" as a fallback value.
     */
    virtual bool IsCaseSensitiveAtPath(std::string_view _dir = "/") const;

    /**
     * VFS version of stat().
     * Default implementation does nothing, subclasses MUST implement it.
     */
    virtual std::expected<VFSStat, Error> Stat(std::string_view _path,                        //
                                               unsigned long _flags,                          //
                                               const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * VFS version of statfs().
     * Path may be a file path or a directory path.
     */
    virtual std::expected<VFSStatFS, Error> StatFS(std::string_view _path,                        //
                                                   const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Default implementation calls Stat() and then returns (st.mode & S_IFMT) == S_IFDIR.
     * On any errors returns false.
     */
    virtual bool IsDirectory(std::string_view _path,                        //
                             unsigned long _flags,                          //
                             const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Default implementation calls Stat() and then returns (st.mode & S_IFMT) == S_IFLNK.
     * On any errors returns false.
     */
    virtual bool IsSymlink(std::string_view _path,                        //
                           unsigned long _flags,                          //
                           const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Reads the symlink into a string.
     */
    virtual std::expected<std::string, Error> ReadSymlink(std::string_view _symlink_path,                //
                                                          const VFSCancelChecker &_cancel_checker = {}); //

    // Default implementation calls Stat() and returns true if the call was sucessful.
    virtual bool Exists(std::string_view _path,                        //
                        const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Checks if _filenames contains a forbidden symbols and return false if found them.
     * Default implementation forbids ":\\/\r\t\n" chars, overrides may change this behaviour
     */
    virtual bool ValidateFilename(std::string_view _filename) const;

    // Returns size of all items in a directory, recursively.
    // The default implementation uses IterateDirectoryListing() and Stat() to calculate the sizes.
    // Symlinks are not followed.
    virtual std::expected<uint64_t, Error> CalculateDirectorySize(std::string_view _path,                        //
                                                                  const VFSCancelChecker &_cancel_checker = {}); //

    // TODO: describle
    virtual bool ShouldProduceThumbnails() const;

    // Returns a list of known users on this host.
    virtual std::expected<std::vector<VFSUser>, Error> FetchUsers(const VFSCancelChecker &_cancel_checker = {});

    // Returns a list of known user groups on this host.
    virtual std::expected<std::vector<VFSGroup>, Error> FetchGroups(const VFSCancelChecker &_cancel_checker = {});

    /***********************************************************************************************
     * Directories iteration, listings fetching
     **********************************************************************************************/

    // Produces a regular directory listing.
    // An actual host implementation must provide this method.
    virtual std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,                        //
                                                                      unsigned long _flags,                          //
                                                                      const VFSCancelChecker &_cancel_checker = {}); //

    // Produces a regular listing, consisting of a single element.
    // If there's no overriden implementaition in derived class, VFSHost will try to produce this listing with Stat().
    virtual std::expected<VFSListingPtr, Error> FetchSingleItemListing(std::string_view _path_to_item,                //
                                                                       unsigned long _flags,                          //
                                                                       const VFSCancelChecker &_cancel_checker = {}); //

    // IterateDirectoryListing will skip "." and ".." entries if they are present.
    // Do not rely on it to build a directory listing, it's for contents iteration.
    // _handler: return true to allow further iteration, false to stop it.
    virtual std::expected<void, Error>
    IterateDirectoryListing(std::string_view _path,                                         //
                            const std::function<bool(const VFSDirEnt &_dirent)> &_handler); //

    // Fetches a listing of the specified directory and returns an array of items with the specified filenames.
    std::expected<std::vector<VFSListingItem>, Error>
    FetchFlexibleListingItems(const std::string &_directory_path,            //
                              const std::vector<std::string> &_filenames,    //
                              unsigned long _flags,                          //
                              const VFSCancelChecker &_cancel_checker = {}); //

    /***********************************************************************************************
     * Making changes to the filesystem
     **********************************************************************************************/

    // Factory method - creates a VFSFile for this VFS type that points at the specified path.
    // The file object will be in a default non-opened state.
    // This call is not assumed to cause any I/O.
    // A host may refuse to create a file that points to an invalid path location.
    // A host may also refuse if there can't be any item at that path and that's known in advance without I/O.
    virtual std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,                        //
                                                                      const VFSCancelChecker &_cancel_checker = {}); //

    // Creates a directory at the specified path with the specified permissions.
    virtual std::expected<void, Error> CreateDirectory(std::string_view _path,                        //
                                                       int _mode,                                     //
                                                       const VFSCancelChecker &_cancel_checker = {}); //

    /** Return zero upon succes, negative value on error. */
    virtual std::expected<void, Error> CreateSymlink(std::string_view _symlink_path,                //
                                                     std::string_view _symlink_value,               //
                                                     const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Unlinks(deletes) a file. Dont follow last symlink, in case of.
     * Don't delete directories, similar to POSIX.
     */
    virtual std::expected<void, Error> Unlink(std::string_view _path,                        //
                                              const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Deletes an empty directory.
     */
    virtual std::expected<void, Error> RemoveDirectory(std::string_view _path,                        //
                                                       const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Moves an item into trash bin.
     */
    virtual std::expected<void, Error> Trash(std::string_view _path,                        //
                                             const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Change the name of a file.
     */
    virtual std::expected<void, Error> Rename(std::string_view _old_path,                    //
                                              std::string_view _new_path,                    //
                                              const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Adjust file node times.
     */
    virtual std::expected<void, Error> SetTimes(std::string_view _path,                        //
                                                std::optional<time_t> _birth_time,             //
                                                std::optional<time_t> _mod_time,               //
                                                std::optional<time_t> _chg_time,               //
                                                std::optional<time_t> _acc_time,               //
                                                const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Change permissions similarly to chmod().
     */
    virtual std::expected<void, Error> SetPermissions(std::string_view _path,                        //
                                                      uint16_t _mode,                                //
                                                      const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Change flags similarly to chflags().
     * _vfs_options can include F_NoFollow to work akin to lchflags() instead.
     */
    virtual std::expected<void, Error> SetFlags(std::string_view _path,                        //
                                                uint32_t _flags,                               //
                                                uint64_t _vfs_options,                         //
                                                const VFSCancelChecker &_cancel_checker = {}); //

    /**
     * Change ownership similarly to chown().
     */
    virtual std::expected<void, Error> SetOwnership(std::string_view _path,                        //
                                                    unsigned _uid,                                 //
                                                    unsigned _gid,                                 //
                                                    const VFSCancelChecker &_cancel_checker = {}); //

    /***********************************************************************************************
     * Observation of changes
     **********************************************************************************************/

    /**
     * Default implementation doesn't provide any observation functionality.
     */
    virtual bool IsDirectoryChangeObservationAvailable(std::string_view _path);

    /**
     * _handler can be called from any thread
     */
    virtual HostDirObservationTicket ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler);

    /**
     * Will fire _handler whenever a file identified by '_path' is changed.
     * Can return an empty token if observation is unavailable.
     */
    virtual FileObservationToken ObserveFileChanges(std::string_view _path, std::function<void()> _handler);

protected:
    void SetFeatures(uint64_t _features_bitset);
    void AddFeatures(uint64_t _features_bitset);

    virtual void StopDirChangeObserving(unsigned long _ticket);

    virtual void StopObservingFileChanges(unsigned long _token);

private:
    const std::string m_JunctionPath; // path in Parent VFS, relative to it's root
    const std::shared_ptr<Host> m_Parent;
    const char *m_Tag;
    uint64_t m_Features;
    std::function<void(const VFSHost *)> m_OnDesctruct;

    // forbid copying
    Host(const Host &_r) = delete;
    void operator=(const Host &_r) = delete;
    friend class HostDirObservationTicket;
    friend class FileObservationToken;
};

} // namespace nc::vfs
