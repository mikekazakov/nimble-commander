// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSDeclarations.h>
#include <Operations/Operation.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include <Panel/NetworkConnectionsManager.h>
#include "../PanelDataPersistency.h"
#include <memory>

@class PanelController;

namespace nc::panel::actions {

/**
 * Provides a wrapper which allows to asynchronously retrieve a VFS from its promise.
 * This operation will be executed in a panel's background loading thread.
 * The callbacks will be called from the background thread too.
 */
class AsyncVFSPromiseRestorer
{
public:
    AsyncVFSPromiseRestorer(PanelController *_panel, nc::core::VFSInstanceManager &_instance_mgr);

    using SuccessHandler = std::function<void(VFSHostPtr)>;
    using FailureHandler = std::function<void(Error)>;
    void Restore(const nc::core::VFSInstanceManager::Promise &_promise,
                 SuccessHandler _success_handler,
                 FailureHandler _failure_handler);

private:
    PanelController *m_Panel = nil;
    nc::core::VFSInstanceManager &m_InstanceManager;
};

/**
 * As AsyncVFSPromiseRestorer, but works with PersistentLocations.
 *
 * NB! This class lies
 * PanelDataPersisency::CreateVFSFromLocation implicitly pulls the NetworkManager under the hood.
 * This class will need an additional dependency later.
 */
class AsyncPersistentLocationRestorer
{
public:
    AsyncPersistentLocationRestorer(PanelController *_panel,
                                    nc::core::VFSInstanceManager &_instance_mgr,
                                    nc::panel::NetworkConnectionsManager &_net_mgr);

    using SuccessHandler = std::function<void(VFSHostPtr)>;
    using FailureHandler = std::function<void(Error)>;
    void Restore(const nc::panel::PersistentLocation &_location,
                 SuccessHandler _success_handler,
                 FailureHandler _failure_handler);

private:
    PanelController *m_Panel = nil;
    nc::core::VFSInstanceManager &m_InstanceManager;
    nc::panel::NetworkConnectionsManager &m_NetConnManager;
};

// Actions that trigger operations can spawn these objects and hook them up with the operation.
// The deselectors should be allocated via std::make_shared.
// They are immutable.
// The public handler should be called from the background job thread, it then will send a message
// to the main thread and process it there.
class DeselectorViaOpNotification : public std::enable_shared_from_this<DeselectorViaOpNotification>
{
public:
    DeselectorViaOpNotification(PanelController *_pc);

    void Handle(nc::ops::ItemStateReport _report) const;

private:
    void HandleImpl([[maybe_unused]] nc::vfs::Host *_host, const std::string &_path) const;

    mutable std::atomic_bool m_Cancelled;
    std::string m_ExpectedUniformDirectory;
    __weak PanelController *m_Panel;
    unsigned long m_Generation;
};

} // namespace nc::panel::actions
