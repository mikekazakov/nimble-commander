// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "GoToFolder.h"
#include <Habanero/CommonPaths.h>
#include <VFS/Native.h>
#include <VFS/PS.h>
#include "../Views/GoToFolderSheetController.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include <NimbleCommander/States/FilePanels/PanelDataPersistency.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "NavigateHistory.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>
#include "Helpers.h"
#include <Utility/ObjCpp.h>

namespace nc::panel::actions {

using namespace std::literals;
    
void GoToFolder::Perform( PanelController *_target, id ) const
{
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    sheet.panel = _target;
    [sheet showSheetWithParentWindow:_target.window handler:[=]{
        
        auto c = std::make_shared<DirectoryChangeRequest>();
        c->RequestedDirectory = [_target expandPath:sheet.requestedPath];
        c->VFS = _target.isUniform ?
            _target.vfs :
            VFSNativeHost::SharedHost();
        c->PerformAsynchronous = true;
        c->InitiatedByUser = true;
        c->LoadingResultCallback = [=](int _code) {
            dispatch_to_main_queue( [=]{
                [sheet tellLoadingResult:_code];
            });
        };
        [_target GoToDirWithContext:c];
    }];
}

static void GoToNativeDir( const std::string& _path, PanelController *_target )
{
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->RequestedDirectory = _path;
    request->VFS = VFSNativeHost::SharedHost();
    request->PerformAsynchronous = true;
    request->InitiatedByUser = true;
    [_target GoToDirWithContext:request];
}

void GoToHomeFolder::Perform( PanelController *_target, id ) const
{
    GoToNativeDir( CommonPaths::Home(), _target );
}

void GoToDocumentsFolder::Perform( PanelController *_target, id ) const
{
    GoToNativeDir( CommonPaths::Documents(), _target );
}

void GoToDesktopFolder::Perform( PanelController *_target, id ) const
{
    GoToNativeDir( CommonPaths::Desktop(), _target );
}

void GoToDownloadsFolder::Perform( PanelController *_target, id ) const
{
    GoToNativeDir( CommonPaths::Downloads(), _target );
}

void GoToApplicationsFolder::Perform( PanelController *_target, id ) const
{
   GoToNativeDir( CommonPaths::Applications(), _target );
}

void GoToUtilitiesFolder::Perform( PanelController *_target, id ) const
{
   GoToNativeDir( CommonPaths::Utilities(), _target );
}

void GoToLibraryFolder::Perform( PanelController *_target, id ) const
{
   GoToNativeDir( CommonPaths::Library(), _target );
}

void GoToRootFolder::Perform( PanelController *_target, id ) const
{
   GoToNativeDir( CommonPaths::Root(), _target );
}

void GoToProcessesList::Perform( PanelController *_target, id ) const
{
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->RequestedDirectory = "/";
    request->VFS = vfs::PSHost::GetSharedOrNew();
    request->PerformAsynchronous = true;
    request->InitiatedByUser = true;
    [_target GoToDirWithContext:request];
}

void GoToFavoriteLocation::Perform( PanelController *_target, id _sender ) const
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
    
    auto restorer = AsyncPersistentLocationRestorer(_target, _target.vfsInstanceManager);
    auto handler = [path = location->path, panel = _target](VFSHostPtr _host) {
        dispatch_to_main_queue([=]{            
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

bool GoToEnclosingFolder::Predicate( PanelController *_target ) const
{
    static const auto root = "/"s;

    if( _target.isUniform ) {
        if( _target.data.Listing().Directory() != root )
            return true;
        
        return _target.vfs->Parent() != nullptr;
    }
    else
        return GoBack{}.Predicate(_target);
}

void GoToEnclosingFolder::Perform( PanelController *_target, id _sender ) const
{
    if( _target.isUniform  ) {
        auto cur = boost::filesystem::path(_target.data.DirectoryPathWithTrailingSlash());
        if( cur.empty() )
            return;
        
        const auto vfs = _target.vfs;
        
        if( cur == "/" ) {
            if( const auto parent_vfs = vfs->Parent() ) {
                boost::filesystem::path junct = vfs->JunctionPath();
                assert(!junct.empty());
                std::string dir = junct.parent_path().native();
                std::string sel_fn = junct.filename().native();
                                
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
            std::string dir = cur.parent_path().remove_filename().native();
            std::string sel_fn = cur.parent_path().filename().native();
            
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

GoIntoFolder::GoIntoFolder(bool _support_archives, bool _force_checking_for_archive ) :
    m_SupportArchives(_support_archives),
    m_ForceArchivesChecking(_force_checking_for_archive)
{
}

static bool IsItemInArchivesWhitelist( const VFSListingItem &_item ) noexcept
{
    if( _item.IsDir() )
        return false;

    if( !_item.HasExtension() )
        return false;
    
    return IsExtensionInArchivesWhitelist(_item.Extension());
}

bool GoIntoFolder::Predicate( PanelController *_target ) const
{
    const auto item = _target.view.item;
    if( !item )
        return false;
    
    if( item.IsDir() )
        return true;
    
    if( m_SupportArchives == false )
        return false;
    
    if( m_ForceArchivesChecking )
        return true;
    else
        return IsItemInArchivesWhitelist(item);
}

void GoIntoFolder::Perform( PanelController *_target, id ) const
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
    
    if( m_SupportArchives ) {
        const auto eligible_to_check = m_ForceArchivesChecking || IsItemInArchivesWhitelist(item);
        if( eligible_to_check ) {
            
            auto task = [item, _target]( const std::function<bool()> &_cancelled ) {
                auto pwd_ask = [=]{
                    std::string p;
                    return RunAskForPasswordModalWindow(item.Filename(), p) ? p : "";
                };
                
                auto arhost = VFSArchiveProxy::OpenFileAsArchive(item.Path(),
                                                                 item.Host(),
                                                                 pwd_ask,
                                                                 _cancelled
                                                                 );
                
                if( arhost ) {
                    auto request = std::make_shared<DirectoryChangeRequest>();
                    request->RequestedDirectory = "/";
                    request->VFS = arhost;
                    request->PerformAsynchronous = true;
                    request->InitiatedByUser = true;
                    dispatch_to_main_queue([request, _target]{
                        [_target GoToDirWithContext:request];
                    });
                }
            };
            
            [_target commitCancelableLoadingTask:std::move(task)];
        }
    }
}

};
