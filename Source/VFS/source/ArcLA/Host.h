// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../../include/VFS/Host.h"
#include "../../include/VFS/VFSFile.h"
#include <memory>
#include <filesystem>

namespace nc::vfs {

namespace arc {
struct Mediator;
struct Dir;
struct DirEntry;
struct State;
} // namespace arc

class ArchiveHost final : public Host
{
public:
    // Creates an archive host out of raw input
    ArchiveHost(std::string_view _path,
                const VFSHostPtr &_parent,
                std::optional<std::string> _password = std::nullopt,
                VFSCancelChecker _cancel_checker = nullptr); // flags will be added later

    // Creates an archive host out of a configuration of a previously existed host
    ArchiveHost(const VFSHostPtr &_parent, const VFSConfiguration &_config, VFSCancelChecker _cancel_checker = {});

    // Destructor
    ~ArchiveHost();

    // The fixed tag identifying this VFS class
    static const char *const UniqueTag;

    // Type-erased configuration that contains data to restore this VFS
    VFSConfiguration Configuration() const override;

    static VFSMeta Meta();

    bool IsImmutableFS() const noexcept override;

    bool
    IsDirectory(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSStatFS, Error> StatFS(std::string_view _path,
                                           const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSStat, Error>
    Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,
                                                              unsigned long _flags,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    IterateDirectoryListing(std::string_view _path,
                            const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    std::expected<std::string, Error> ReadSymlink(std::string_view _symlink_path,
                                                  const VFSCancelChecker &_cancel_checker = {}) override;

    bool ShouldProduceThumbnails() const override;

    uint32_t StatTotalFiles() const;
    uint32_t StatTotalDirs() const;
    uint32_t StatTotalRegs() const;

    // Caching section - to reduce seeking overhead:

    // return zero on not found
    uint32_t ItemUID(const char *_filename);

    std::unique_ptr<arc::State> ClosestState(uint32_t _requested_item);
    void CommitState(std::unique_ptr<arc::State> _state);

    // use SeekCache or open a new file and seeks to requested item
    int ArchiveStateForItem(const char *_filename, std::unique_ptr<arc::State> &_target);

    std::shared_ptr<const ArchiveHost> SharedPtr() const;

    std::shared_ptr<ArchiveHost> SharedPtr();

    /** return VFSError, not uids returned */
    int ResolvePathIfNeeded(std::string_view _path, std::pmr::string &_resolved_path, unsigned long _flags);

    enum class SymlinkState : uint8_t {
        /// symlink is ok to use
        Resolved,
        /// default value - never tried to resolve
        Unresolved,
        /// in-flight state used during the symlink resolution process
        CurrentlyResolving,
        /// can't resolve symlink since it point to non-existant file or if some error occured while resolving
        Invalid,
        /// symlink resolving resulted in loop, thus symlink can't be used
        Loop
    };

    struct Symlink {
        std::filesystem::path value;       // the value stored in the symlink
        std::filesystem::path target_path; // meaningful only if state == SymlinkState::Resolved
        uint32_t uid = 0;                  // uid of symlink entry itself
        uint32_t target_uid = 0;           // meaningful only if state == SymlinkState::Resolved
        SymlinkState state = SymlinkState::Unresolved;
    };

    /** searches for entry in archive without any path resolving */
    const arc::DirEntry *FindEntry(std::string_view _path);

    /** searches for entry in archive by id */
    const arc::DirEntry *FindEntry(uint32_t _uid);

    /** find symlink and resolves it if not already. returns nullptr on error. */
    const Symlink *ResolvedSymlink(uint32_t _uid);

private:
    struct Impl;

    std::expected<void, Error> DoInit(const VFSCancelChecker &_cancel_checker);
    const class VFSArchiveHostConfiguration &Config() const;

    int ReadArchiveListing();
    uint64_t UpdateDirectorySize(arc::Dir &_directory, const std::string &_path);
    arc::Dir *FindOrBuildDir(std::string_view _path_with_tr_sl);

    void InsertDummyDirInto(arc::Dir *_parent, std::string_view _dir_name);
    struct archive *SpawnLibarchive();

    // Returns a VFSError
    int ResolvePath(std::string_view _path, std::pmr::string &_resolved_path);

    void ResolveSymlink(uint32_t _uid);

    std::unique_ptr<Impl> I;
    VFSConfiguration m_Configuration; // TODO: move into I
};

} // namespace nc::vfs
