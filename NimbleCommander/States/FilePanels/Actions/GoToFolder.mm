// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "GoToFolder.h"
#include <Habanero/CommonPaths.h>
#include <VFS/Native.h>
#include <VFS/PS.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include "../Views/GoToFolderSheetController.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include <NimbleCommander/States/FilePanels/PanelDataPersistency.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "NavigateHistory.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>

namespace nc::panel::actions {

void GoToFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    sheet.panel = _target;
    [sheet showSheetWithParentWindow:_target.window handler:[=]{
        
        auto c = make_shared<DirectoryChangeRequest>();
        c->RequestedDirectory = [_target expandPath:sheet.requestedPath];
        c->VFS = _target.isUniform ?
            _target.vfs :
            VFSNativeHost::SharedHost();
        c->PerformAsynchronous = true;
        c->LoadingResultCallback = [=](int _code) {
            dispatch_to_main_queue( [=]{
                [sheet tellLoadingResult:_code];
            });
        };

        bool access_allowed = !c->VFS->IsNativeFS() ||
                                SandboxManager::EnsurePathAccess(c->RequestedDirectory);
        if( access_allowed )
            [_target GoToDirWithContext:c];
    }];
}

static void GoToNativeDir( const string& _path, PanelController *_target )
{
    if( SandboxManager::EnsurePathAccess(_path) )
        [_target GoToDir:_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

void GoToHomeFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Home(), _target );
}

void GoToDocumentsFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Documents(), _target );
}

void GoToDesktopFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Desktop(), _target );
}

void GoToDownloadsFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Downloads(), _target );
}

void GoToApplicationsFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Applications(), _target );
}

void GoToUtilitiesFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Utilities(), _target );
}

void GoToLibraryFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Library(), _target );
}

void GoToRootFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Root(), _target );
}

void GoToProcessesList::Perform( PanelController *_target, id _sender ) const
{
    [_target GoToDir:"/" vfs:vfs::PSHost::GetSharedOrNew() select_entry:"" async:true];
}

void GoToFavoriteLocation::Perform( PanelController *_target, id _sender ) const
{
    if( auto menuitem = objc_cast<NSMenuItem>(_sender) )
        if( auto holder = objc_cast<AnyHolder>(menuitem.representedObject) )
            if( auto location = any_cast<PersistentLocation>(&holder.any) )
                [_target goToPersistentLocation:*location];
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

static bool SandboxAccessDenied( const VFSHost &_host, const string &_path )
{
    return _host.IsNativeFS() && !SandboxManager::EnsurePathAccess(_path);
}

void GoToEnclosingFolder::Perform( PanelController *_target, id _sender ) const
{
    if( _target.isUniform  ) {
        path cur = path(_target.data.DirectoryPathWithTrailingSlash());
        if( cur.empty() )
            return;
        
        const auto vfs = _target.vfs;
        
        if( cur == "/" ) {
            if( const auto parent_vfs = vfs->Parent() ) {
                path junct = vfs->JunctionPath();
                assert(!junct.empty());
                string dir = junct.parent_path().native();
                string sel_fn = junct.filename().native();
                
                if( SandboxAccessDenied(*parent_vfs, dir) )
                    return; // silently reap this command, since user refuses to grant an access
                
                [_target GoToDir:dir
                             vfs:parent_vfs
                    select_entry:sel_fn
               loadPreviousState:true
                           async:true];
            }
        }
        else {
            string dir = cur.parent_path().remove_filename().native();
            string sel_fn = cur.parent_path().filename().native();
            
            if( SandboxAccessDenied(*vfs, dir) )
                return;
            
            [_target GoToDir:dir
                         vfs:vfs
                select_entry:sel_fn
           loadPreviousState:true
                       async:true];
        }
    }
    else if( GoBack{}.Predicate(_target) ) {
        GoBack{}.Perform(_target, _sender);
    }
}

GoIntoFolder::GoIntoFolder( bool _force_checking_for_archive ) :
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
    
    if( !ActivationManager::Instance().HasArchivesBrowsing() )
        return false;
    
    if( m_ForceArchivesChecking )
        return true;
    else
        return IsItemInArchivesWhitelist(item);
}

void GoIntoFolder::Perform( PanelController *_target, id _sender ) const
{
    const auto item = _target.view.item;
    if( !item )
        return;
    
    if( item.IsDir() ) {
        if( item.IsDotDot() )
            actions::GoToEnclosingFolder{}.Perform(_target, _target);
        
        if( SandboxAccessDenied(*item.Host(), item.Path()) )
            return;
        
        [_target GoToDir:item.Path()
                     vfs:item.Host()
            select_entry:""
                   async:true];
    }
    
    if( ActivationManager::Instance().HasArchivesBrowsing() ) {
        const auto eligible_to_check = m_ForceArchivesChecking || IsItemInArchivesWhitelist(item);
        if( eligible_to_check ) {
            
            auto task = [item, _target]( const function<bool()> &_cancelled ) {
                auto pwd_ask = [=]{
                    string p;
                    return RunAskForPasswordModalWindow(item.Filename(), p) ? p : "";
                };
                
                auto arhost = VFSArchiveProxy::OpenFileAsArchive(item.Path(),
                                                                 item.Host(),
                                                                 pwd_ask,
                                                                 _cancelled
                                                                 );
                
                if( arhost )
                    dispatch_to_main_queue([=]{
                        [_target GoToDir:"/"
                                     vfs:arhost
                            select_entry:""
                                   async:true];
                    });
            };
            
            [_target commitCancelableLoadingTask:move(task)];
        }
    }
}

};
