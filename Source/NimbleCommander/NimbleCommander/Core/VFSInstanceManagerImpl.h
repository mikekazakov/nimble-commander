// Copyright (C) 2018-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFSInstanceManager.h"
#include "VFSInstancePromise.h"

namespace nc::core {

class VFSInstanceManagerImpl : public VFSInstanceManager
{
public:
    using ObservationTicket = ObservableBase::ObservationTicket;
    using Promise = VFSInstancePromise;

    VFSInstanceManagerImpl();
    ~VFSInstanceManagerImpl() override;

    /**
     * Will register information about the instance if not yet.
     * Returned promise may be used for later vfs restoration.
     */
    Promise TameVFS(const std::shared_ptr<VFSHost> &_instance) override;

    /**
     * Returns a promise for specified vfs, if the information is available.
     */
    Promise PreserveVFS(const std::weak_ptr<VFSHost> &_instance) override;

    /**
     * Will return and alive instance if it's alive, will try to recreate it (will all upchain) if otherwise.
     * May throw vfs exceptions on vfs rebuilding.
     * May return nullptr on failure.
     */
    std::shared_ptr<VFSHost> RetrieveVFS(const Promise &_promise,
                                         std::function<bool()> _cancel_checker = nullptr) override;

    /**
     * Will find an info for promise and return a corresponding vfs tag.
     */
    const char *GetTag(const Promise &_promise) override;

    /**
     * Will return empty promise if there's no parent vfs, or it was somehow not registered
     */
    Promise GetParentPromise(const Promise &_promise) override;

    /**
     * Will return empty string on any errors.
     */
    std::string GetVerboseVFSTitle(const Promise &_promise) override;

    std::vector<std::weak_ptr<VFSHost>> AliveHosts() override;

    unsigned KnownVFSCount() override;
    Promise GetVFSPromiseByPosition(unsigned _at) override;

    ObservationTicket ObserveAliveVFSListChanged(std::function<void()> _callback) override;
    ObservationTicket ObserveKnownVFSListChanged(std::function<void()> _callback) override;

private:
    static constexpr uint64_t AliveVFSListObservation = 0x0001;
    static constexpr uint64_t KnownVFSListObservation = 0x0002;

    struct Info;

    /**
     * Thread-safe.
     */
    void IncPromiseCount(uint64_t _inst_id) override;

    /**
     * Thread-safe.
     */
    void DecPromiseCount(uint64_t _inst_id) override;

    /**
     * Thread-safe.
     */
    void EnrollAliveHost(const std::shared_ptr<VFSHost> &_inst);

    /**
     * Thread-safe.
     */
    void SweepDeadReferences();

    /**
     * Thread-safe.
     */
    void SweepDeadMemory();

    Promise SpawnPromiseFromInfo_Unlocked(Info &_info);
    Info *InfoFromVFSWeakPtr_Unlocked(const std::weak_ptr<VFSHost> &_ptr);
    Info *InfoFromVFSPtr_Unlocked(const std::shared_ptr<VFSHost> &_ptr);
    Info *InfoFromID_Unlocked(uint64_t _inst_id);

    std::shared_ptr<VFSHost> GetOrRestoreVFS_Unlocked(Info *_info, const std::function<bool()> &_cancel_checker);

    std::vector<Info> m_Memory;
    uint64_t m_MemoryNextID = 1;
    spinlock m_MemoryLock;

    std::vector<std::weak_ptr<VFSHost>> m_AliveHosts;
    spinlock m_AliveHostsLock;
};

} // namespace nc::core
