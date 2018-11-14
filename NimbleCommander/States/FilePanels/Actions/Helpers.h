// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSDeclarations.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include "../PanelDataPersistency.h"
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
    using FailureHandler = std::function<void(int)>;
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
                                    nc::core::VFSInstanceManager &_instance_mgr);

    using SuccessHandler = std::function<void(VFSHostPtr)>;
    using FailureHandler = std::function<void(int)>;
    void Restore(const nc::panel::PersistentLocation &_location,
                 SuccessHandler _success_handler, 
                 FailureHandler _failure_handler);
    
private:
    PanelController *m_Panel = nil; 
    nc::core::VFSInstanceManager &m_InstanceManager;    
};

}
