// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Helpers.h"
#include "../PanelController.h"
#include <NimbleCommander/Core/VFSInstancePromise.h>
#include <Panel/PanelData.h>
#include <Utility/PathManip.h>
#include <Base/dispatch_cpp.h>

namespace nc::panel::actions {

AsyncVFSPromiseRestorer::AsyncVFSPromiseRestorer(PanelController *_panel, nc::core::VFSInstanceManager &_instance_mgr)
    : m_Panel(_panel), m_InstanceManager(_instance_mgr)
{
}

void AsyncVFSPromiseRestorer::Restore(const nc::core::VFSInstanceManager::Promise &_promise,
                                      SuccessHandler _success_handler,
                                      FailureHandler _failure_handler)
{
    auto task = [&manager = m_InstanceManager,
                 promise = _promise,
                 success = std::move(_success_handler),
                 failure = std::move(_failure_handler)](const std::function<bool()> &_is_cancelled) {
        VFSHostPtr host;
        try {

            host = manager.RetrieveVFS(promise, _is_cancelled);

        } catch( ErrorException &ex ) {
            if( failure != nullptr )
                failure(ex.error());
        }

        if( host != nullptr ) {
            if( success != nullptr ) {
                success(host);
            }
        }
    };

    [m_Panel commitCancelableLoadingTask:std::move(task)];
}

AsyncPersistentLocationRestorer::AsyncPersistentLocationRestorer(PanelController *_panel,
                                                                 nc::core::VFSInstanceManager &_instance_mgr,
                                                                 nc::panel::NetworkConnectionsManager &_net_mgr)
    : m_Panel(_panel), m_InstanceManager(_instance_mgr), m_NetConnManager(_net_mgr)
{
}

void AsyncPersistentLocationRestorer::Restore(const nc::panel::PersistentLocation &_location,
                                              SuccessHandler _success_handler,
                                              FailureHandler _failure_handler)
{
    auto task = [&manager = m_InstanceManager,
                 &netmgr = m_NetConnManager,
                 location = _location,
                 success = std::move(_success_handler),
                 failure = std::move(_failure_handler)]([[maybe_unused]] const std::function<bool()> &_is_cancelled) {
        PanelDataPersistency persistency(netmgr);
        const std::expected<VFSHostPtr, Error> exp_host = persistency.CreateVFSFromLocation(location, manager);

        if( !exp_host ) {
            if( failure != nullptr )
                failure(exp_host.error());
            return;
        }

        if( exp_host && *exp_host != nullptr ) {
            if( success != nullptr ) {
                success(*exp_host);
            }
        }
    };

    [m_Panel commitCancelableLoadingTask:std::move(task)];
}

DeselectorViaOpNotification::DeselectorViaOpNotification(PanelController *_pc)
    : m_Cancelled(false), m_Panel(_pc), m_Generation(_pc.dataGeneration)
{
    auto &listing = _pc.data.Listing();
    if( listing.IsUniform() )
        m_ExpectedUniformDirectory = listing.Directory();
}

void DeselectorViaOpNotification::Handle(nc::ops::ItemStateReport _report) const
{
    dispatch_assert_background_queue();
    if( _report.status == nc::ops::ItemStatus::Skipped )
        return;
    if( m_Cancelled )
        return;
    if( !m_ExpectedUniformDirectory.empty() ) {
        // the original listing was uniform so we can check the directory and quickly exit
        // without comming a task on the main thread. this helps to ignore enclosed items located
        // deeper in a file hierarchy.
        const std::string_view parent = utility::PathManip::Parent(_report.path);
        if( m_ExpectedUniformDirectory != parent )
            return;
    }

    auto me = shared_from_this();
    nc::vfs::Host *const host = &_report.host;
    std::string path(_report.path);
    dispatch_to_main_queue([me = std::move(me), path = std::move(path), host] { me->HandleImpl(host, path); });
}

// this method can be triggered for every item processed in the background, which means potentially
// thousands, so it has to be FAST.
// fun fact: _host can be a dangling pointer and is used only as a key.
void DeselectorViaOpNotification::HandleImpl(nc::vfs::Host *_host, const std::string &_path) const
{
    dispatch_assert_main_queue();
    PanelController *const panel = m_Panel;
    if( panel == nil ) {
        m_Cancelled = true;
        return; // stale weak pointer, bail out
    }
    if( panel.dataGeneration != m_Generation ) {
        m_Cancelled = true;
        return; // the panel changed its contents, shouldn't do anything with it anymore
    }

    const auto &data = panel.data;
    const auto &listing = data.Listing();
    if( listing.IsUniform() ) {
        // search for a filename and deselect it
        assert(utility::PathManip::Parent(_path) == listing.Directory());
        const std::string_view filename = utility::PathManip::Filename(_path);
        const int indx = data.SortedIndexForName(filename);
        if( indx >= 0 ) {
            [panel setSelectionForItemAtIndex:indx selected:false];
        }
    }
    else {
        // things are much hairier for non-uniform listings :(, but we can try a few thing to make
        // it reasonably fast.
        // 1. find all entries with a filename from the report - O(logN)
        // 2. check if their hosts are the same as in the report O(M)
        // 3. check if their directories are the same as in the report O(M)
        // 4. if all succedeed - deselect
        const std::string_view filename = utility::PathManip::Filename(_path);
        const std::string_view parent = utility::PathManip::Parent(_path);
        const std::span<const unsigned> raw_indices = data.RawIndicesForName(filename);
        for( const unsigned raw_indx : raw_indices ) {
            if( listing.Directory(raw_indx) != parent )
                continue;
            if( listing.Host(raw_indx).get() != _host )
                continue;

            const int indx = data.SortedIndexForRawIndex(static_cast<int>(raw_indx));
            if( indx >= 0 ) {
                [panel setSelectionForItemAtIndex:indx selected:false];
            }

            // it's hard to imagine a legit situation when parent_path+filename+host wouldn't
            // uniquely identify an item and there will be need to search further. so at this point
            // it should be safe to bail out earlier.
            break;
        }
    }
}

} // namespace nc::panel::actions
