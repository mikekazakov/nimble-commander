// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "GoToFolder.h"
#include <Base/CommonPaths.h>
#include <VFS/Native.h>
#include <VFS/NativeSpecialDirectories.h>
#include <VFS/PS.h>
#include "../Views/GoToFolderSheetController.h"
#include "../PanelController.h"
#include <Panel/PanelData.h>
#include <NimbleCommander/States/FilePanels/PanelDataPersistency.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>
#include "NavigateHistory.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>
#include "Helpers.h"
#include <Utility/ObjCpp.h>
#include <Utility/SystemInformation.h>

namespace nc::panel::actions {

using namespace std::literals;

void GoToFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToFolderSheetController *const sheet = [GoToFolderSheetController new];
    sheet.panel = _target;
    [sheet showSheetWithParentWindow:_target.window
                             handler:[=] {
                                 auto c = std::make_shared<DirectoryChangeRequest>();
                                 c->RequestedDirectory = [_target expandPath:sheet.requestedPath];
                                 c->VFS = _target.isUniform ? _target.vfs
                                                            : nc::bootstrap::NativeVFSHostInstance().SharedPtr();
                                 c->PerformAsynchronous = true;
                                 c->InitiatedByUser = true;
                                 c->LoadingResultCallback = [=](const std::expected<void, Error> &_result) {
                                     dispatch_to_main_queue([=] { [sheet tellLoadingResult:_result]; });
                                 };
                                 [_target GoToDirWithContext:c];
                             }];
}

static void GoToNativeDir(const std::string &_path, PanelController *_target)
{
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->RequestedDirectory = _path;
    request->VFS = nc::bootstrap::NativeVFSHostInstance().SharedPtr();
    request->PerformAsynchronous = true;
    request->InitiatedByUser = true;
    [_target GoToDirWithContext:request];
}

void GoToHomeFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToNativeDir(base::CommonPaths::Home(), _target);
}

void GoToDocumentsFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToNativeDir(base::CommonPaths::Documents(), _target);
}

void GoToDesktopFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToNativeDir(base::CommonPaths::Desktop(), _target);
}

void GoToDownloadsFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToNativeDir(base::CommonPaths::Downloads(), _target);
}

void GoToApplicationsFolder::Perform(PanelController *_target, id /*_sender*/) const
{

    auto task = [_target](const std::function<bool()> &_cancelled) {
        const std::expected<VFSListingPtr, Error> listing = vfs::native::FetchUnifiedApplicationsListing(
            nc::bootstrap::NativeVFSHostInstance(), _target.vfsFetchingFlags, _cancelled);
        if( listing ) {
            dispatch_to_main_queue([listing, _target] { [_target loadListing:*listing]; });
        }
    };
    [_target commitCancelableLoadingTask:std::move(task)];
}

void GoToUtilitiesFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    auto task = [_target](const std::function<bool()> &_cancelled) {
        const std::expected<VFSListingPtr, Error> listing = vfs::native::FetchUnifiedUtilitiesListing(
            nc::bootstrap::NativeVFSHostInstance(), _target.vfsFetchingFlags, _cancelled);
        if( listing ) {
            dispatch_to_main_queue([listing, _target] { [_target loadListing:*listing]; });
        }
    };
    [_target commitCancelableLoadingTask:std::move(task)];
}

void GoToLibraryFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToNativeDir(base::CommonPaths::Library(), _target);
}

void GoToRootFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    GoToNativeDir(base::CommonPaths::Root(), _target);
}

void GoToProcessesList::Perform(PanelController *_target, id /*_sender*/) const
{
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->RequestedDirectory = "/";
    request->VFS = vfs::PSHost::GetSharedOrNew();
    request->PerformAsynchronous = true;
    request->InitiatedByUser = true;
    [_target GoToDirWithContext:request];
}

GoToFavoriteLocation::GoToFavoriteLocation(NetworkConnectionsManager &_net_mgr) : m_NetMgr(_net_mgr)
{
}

void GoToFavoriteLocation::Perform(PanelController *_target, id _sender) const
{
    auto menuitem = objc_cast<NSMenuItem>(_sender);
    if( menuitem == nil )
        return;
    auto holder = objc_cast<AnyHolder>(menuitem.representedObject);
    if( holder == nil )
        return;
    auto location = std::any_cast<PersistentLocation>(&holder.any);
    if( location == nil )
        return;

    auto restorer = AsyncPersistentLocationRestorer(_target, _target.vfsInstanceManager, m_NetMgr);
    auto handler = [path = location->path, panel = _target](VFSHostPtr _host) {
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = path;
            request->VFS = _host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [panel GoToDirWithContext:request];
        });
    };
    restorer.Restore(*location, std::move(handler), nullptr);
}

bool GoToEnclosingFolder::Predicate(PanelController *_target) const
{
    [[clang::no_destroy]] static const auto root = "/"s;

    if( _target.isUniform ) {
        if( _target.data.Listing().Directory() != root )
            return true;

        return _target.vfs->Parent() != nullptr;
    }
    else
        return GoBack{}.Predicate(_target);
}

void GoToEnclosingFolder::Perform(PanelController *_target, id _sender) const
{
    if( _target.isUniform ) {
        auto cur = std::filesystem::path(_target.data.DirectoryPathWithTrailingSlash());
        if( cur.empty() )
            return;

        const auto vfs = _target.vfs;

        if( cur == "/" ) {
            if( const auto parent_vfs = vfs->Parent() ) {
                const std::filesystem::path junct = vfs->JunctionPath();
                assert(!junct.empty());
                const std::string dir = junct.parent_path();
                const std::string sel_fn = junct.filename();

                auto request = std::make_shared<DirectoryChangeRequest>();
                request->RequestedDirectory = dir;
                request->VFS = parent_vfs;
                request->RequestFocusedEntry = sel_fn;
                request->LoadPreviousViewState = true;
                request->PerformAsynchronous = true;
                request->InitiatedByUser = true;
                [_target GoToDirWithContext:request];
            }
        }
        else {
            const std::string dir = cur.parent_path().remove_filename();
            const std::string sel_fn = cur.parent_path().filename();

            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = dir;
            request->VFS = vfs;
            request->RequestFocusedEntry = sel_fn;
            request->LoadPreviousViewState = true;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [_target GoToDirWithContext:request];
        }
    }
    else if( GoBack{}.Predicate(_target) ) {
        GoBack{}.Perform(_target, _sender);
    }
}

GoIntoFolder::GoIntoFolder(bool _force_checking_for_archive) : m_ForceArchivesChecking(_force_checking_for_archive)
{
}

static bool IsItemInArchivesWhitelist(const VFSListingItem &_item) noexcept
{
    if( _item.IsDir() )
        return false;

    if( !_item.HasExtension() )
        return false;

    return IsExtensionInArchivesWhitelist(_item.Extension());
}

bool GoIntoFolder::Predicate(PanelController *_target) const
{
    const auto item = _target.view.item;
    if( !item )
        return false;

    if( item.IsDir() )
        return true;

    if( m_ForceArchivesChecking )
        return true;
    else
        return IsItemInArchivesWhitelist(item);
}

bool GoIntoFolder::ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const
{
    if( auto vfs_item = _target.view.item ) {
        _item.title = [NSString
            stringWithFormat:NSLocalizedString(@"Enter \u201c%@\u201d", "Enter a directory"), vfs_item.DisplayNameNS()];
    }

    return Predicate(_target);
}

void GoIntoFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto item = _target.view.item;
    if( !item )
        return;

    if( item.IsDir() ) {
        if( item.IsDotDot() )
            actions::GoToEnclosingFolder{}.Perform(_target, _target);

        auto request = std::make_shared<DirectoryChangeRequest>();
        request->RequestedDirectory = item.Path();
        request->VFS = item.Host();
        request->PerformAsynchronous = true;
        request->InitiatedByUser = true;
        [_target GoToDirWithContext:request];
        return;
    }

    const auto eligible_to_check = m_ForceArchivesChecking || IsItemInArchivesWhitelist(item);
    if( eligible_to_check ) {

        auto task = [item, _target](const std::function<bool()> &_cancelled) {
            auto pwd_ask = [=] {
                std::string p;
                return RunAskForPasswordModalWindow(item.Filename(), p) ? p : "";
            };

            auto arhost = VFSArchiveProxy::OpenFileAsArchive(item.Path(), item.Host(), pwd_ask, _cancelled);

            if( arhost ) {
                auto request = std::make_shared<DirectoryChangeRequest>();
                request->RequestedDirectory = "/";
                request->VFS = arhost;
                request->PerformAsynchronous = true;
                request->InitiatedByUser = true;
                dispatch_to_main_queue([request, _target] { [_target GoToDirWithContext:request]; });
            }
        };

        [_target commitCancelableLoadingTask:std::move(task)];
    }
}

}; // namespace nc::panel::actions
