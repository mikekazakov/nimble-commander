// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Helpers.h"
#include "../PanelController.h"
#include <NimbleCommander/Core/VFSInstancePromise.h>

namespace nc::panel::actions {

AsyncVFSPromiseRestorer::AsyncVFSPromiseRestorer(PanelController *_panel,
                                                 nc::core::VFSInstanceManager &_instance_mgr):
    m_Panel(_panel),
    m_InstanceManager(_instance_mgr)
{            
}

void AsyncVFSPromiseRestorer::Restore(const nc::core::VFSInstanceManager::Promise &_promise,
                                      SuccessHandler _success_handler, 
                                      FailureHandler _failure_handler)
{ 
    auto task = [&manager = m_InstanceManager,
                 promise = _promise,
                 success = std::move(_success_handler),
                 failure = std::move(_failure_handler)]
            (const std::function<bool()> &_is_cancelled)
    {
        VFSHostPtr host;
        try {
            
            host = manager.RetrieveVFS( promise, _is_cancelled );
            
        } catch (VFSErrorException &ex) {
            if( failure != nullptr )
                failure( ex.code() );
        }        

        if( host != nullptr ) {
            if( success != nullptr ) {
                success( host );
            }
        }
    };
    
    [m_Panel commitCancelableLoadingTask:std::move(task)]; 
}


AsyncPersistentLocationRestorer::
    AsyncPersistentLocationRestorer(PanelController *_panel,
                                    nc::core::VFSInstanceManager &_instance_mgr):
    m_Panel(_panel),
    m_InstanceManager(_instance_mgr)
{
}
    
void AsyncPersistentLocationRestorer::Restore(const nc::panel::PersistentLocation &_location,
                                              SuccessHandler _success_handler, 
                                              FailureHandler _failure_handler)
{
    auto task = [&manager = m_InstanceManager,
                 location = _location,
                 success = std::move(_success_handler),
                 failure = std::move(_failure_handler)]
            (const std::function<bool()> &_is_cancelled)
    {
        VFSHostPtr host;        
        const auto rc = PanelDataPersisency::CreateVFSFromLocation(location, host, manager);
        
        if( rc != VFSError::Ok ) {            
            if( failure != nullptr )
                failure( rc );
            return;
        }

        if( host != nullptr ) {
            if( success != nullptr ) {
                success( host );
            }
        }
    };
    
    [m_Panel commitCancelableLoadingTask:std::move(task)];         
}

}
