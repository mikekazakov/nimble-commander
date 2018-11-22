// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../../include/VFS/Host.h"
#include "../../include/VFS/VFSFile.h"
#include <map>
#include <mutex>

namespace nc::vfs {

namespace arc {
struct Mediator;
struct Dir;
struct DirEntry;
struct State;
}

class ArchiveHost final : public Host
{
public:
    ArchiveHost(const std::string &_path,
                const VFSHostPtr &_parent,
                std::optional<std::string> _password = std::nullopt,
                VFSCancelChecker _cancel_checker = nullptr); // flags will be added later
    ArchiveHost(const VFSHostPtr &_parent,
                const VFSConfiguration &_config,
                VFSCancelChecker _cancel_checker = nullptr);
    ~ArchiveHost();
    
    static const char *UniqueTag;
    virtual VFSConfiguration Configuration() const override;    
    static VFSMeta Meta();

    
    virtual bool IsImmutableFS() const noexcept override;
    
    virtual bool IsDirectory(const char *_path,
                             unsigned long _flags,
                             const VFSCancelChecker &_cancel_checker) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker) override;
    virtual int Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    
    virtual int ReadSymlink(const char *_symlink_path, char *_buffer, size_t _buffer_size, const VFSCancelChecker &_cancel_checker) override;
    
    virtual bool ShouldProduceThumbnails() const override;

    inline uint32_t StatTotalFiles() const { return m_TotalFiles; }
    inline uint32_t StatTotalDirs() const { return m_TotalDirs; }
    inline uint32_t StatTotalRegs() const { return m_TotalRegs; }
    
    // Caching section - to reduce seeking overhead:
    
    // return zero on not found
    uint32_t ItemUID(const char* _filename);
    
    std::unique_ptr<arc::State> ClosestState(uint32_t _requested_item);
    void CommitState(std::unique_ptr<arc::State> _state);
    
    // use SeekCache or open a new file and seeks to requested item
    int ArchiveStateForItem(const char *_filename, std::unique_ptr<arc::State> &_target);
    
    std::shared_ptr<const ArchiveHost> SharedPtr() const {return std::static_pointer_cast<const ArchiveHost>(Host::SharedPtr());}
    std::shared_ptr<ArchiveHost> SharedPtr() {return std::static_pointer_cast<ArchiveHost>(Host::SharedPtr());}
    
    /** return VFSError, not uids returned */
    int ResolvePathIfNeeded(const char *_path, char *_resolved_path, unsigned long _flags);
    
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
        std::string  value  = "";
        uint32_t     uid    = 0; // uid of symlink entry itself
        uint32_t     target_uid = 0;   // meaningful only if state == SymlinkState::Resolved
        std::string  target_path = ""; // meaningful only if state == SymlinkState::Resolved
    };
    
    /** searches for entry in archive without any path resolving */
    const arc::DirEntry *FindEntry(const char* _path);
    
    /** searches for entry in archive by id */
    const arc::DirEntry *FindEntry(uint32_t _uid);
    
    /** find symlink and resolves it if not already. returns nullptr on error. */
    const Symlink *ResolvedSymlink(uint32_t _uid);
    
private:
    int DoInit(VFSCancelChecker _cancel_checker);
    const class VFSArchiveHostConfiguration &Config() const;
    
    int ReadArchiveListing();
    uint64_t UpdateDirectorySize( arc::Dir &_directory, const std::string &_path );
    arc::Dir* FindOrBuildDir(const char* _path_with_tr_sl);
    
    
    void InsertDummyDirInto(arc::Dir *_parent, const char* _dir_name);
    struct archive* SpawnLibarchive();
    
    /**
     * any positive number - item's uid, good to go.
     * negative number or zero - error
     */
    int ResolvePath(const char *_path, char *_resolved_path);
    
    void ResolveSymlink(uint32_t _uid);
    
    VFSConfiguration                        m_Configuration;
    std::shared_ptr<VFSFile>                m_ArFile;
    std::shared_ptr<arc::Mediator>          m_Mediator;
    struct archive                         *m_Arc = nullptr;
    std::map<std::string, arc::Dir>         m_PathToDir;
    uint32_t                                m_TotalFiles = 0;
    uint32_t                                m_TotalDirs = 0;
    uint32_t                                m_TotalRegs = 0;
    uint64_t                                m_ArchiveFileSize = 0;
    uint64_t                                m_ArchivedFilesTotalSize = 0;
    uint32_t                                m_LastItemUID = 0;

    bool                                    m_NeedsPathResolving = false; // true if there are any symlinks present in archive
    std::map<uint32_t, Symlink>             m_Symlinks;
    std::recursive_mutex                    m_SymlinksResolveLock;
    
    std::vector<std::pair<arc::Dir*, uint32_t>>m_EntryByUID; // points to directory and entry No inside it
    std::vector<std::unique_ptr<arc::State>>m_States;
    std::mutex                              m_StatesLock;
};

}
