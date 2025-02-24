// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/SerialQueue.h>
#include <VFS/Host.h>
#include <VFS/VFSFile.h>

namespace nc::vfs {

class PSHost final : public Host
{
public:
    PSHost();
    ~PSHost();

    static const char *UniqueTag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();

    std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    bool
    IsDirectory(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    bool IsWritable() const override;

    std::expected<VFSStat, Error>
    Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSStatFS, Error> StatFS(std::string_view _path,
                                           const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,
                                                              unsigned long _flags,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    IterateDirectoryListing(std::string_view _path,
                            const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    bool IsDirectoryChangeObservationAvailable(std::string_view _path) override;
    HostDirObservationTicket ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler) override;
    void StopDirChangeObserving(unsigned long _ticket) override;

    /**
     * Since there's no meaning for having more than one of this FS - this is a caching creation.
     * If there's a living fs already - it will return it, if - will create new.
     * It will store a weak ptr and will not extend FS living time.
     */
    static std::shared_ptr<PSHost> GetSharedOrNew();

    std::shared_ptr<const PSHost> SharedPtr() const
    {
        return std::static_pointer_cast<const PSHost>(Host::SharedPtr());
    }
    std::shared_ptr<PSHost> SharedPtr() { return std::static_pointer_cast<PSHost>(Host::SharedPtr()); }

    struct ProcInfo;
    struct Snapshot;

private:
    void UpdateCycle();
    void EnsureUpdateRunning();
    int ProcIndexFromFilepath_Unlocked(std::string_view _filepath);

    static std::vector<ProcInfo> GetProcs();
    void CommitProcs(std::vector<ProcInfo> _procs);
    static std::string ProcInfoIntoFile(const ProcInfo &_info, std::shared_ptr<Snapshot> _data);

    std::mutex m_Lock; // bad and ugly, ok.
    std::shared_ptr<Snapshot> m_Data;
    std::vector<std::pair<unsigned long, std::function<void()>>> m_UpdateHandlers;
    unsigned long m_LastTicket = 1;
    base::SerialQueue m_UpdateQ;
    bool m_UpdateStarted = false;
};

} // namespace nc::vfs
