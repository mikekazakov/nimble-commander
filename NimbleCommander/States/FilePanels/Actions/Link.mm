// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Link.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include "../MainWindowFilePanelState.h"
#include "../../MainWindowController.h"
#include <Operations/Linkage.h>
#include <Operations/CreateSymlinkDialog.h>
#include <Operations/AlterSymlinkDialog.h>
#include <Operations/CreateHardlinkDialog.h>
#include <Utility/PathManip.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::panel::actions {

static PanelController *FindVisibleOppositeController( PanelController *_source );
static void FocusResult( PanelController *_target, const std::string &_path, bool _refresh );
static void Refresh( PanelController *_target );

bool CreateSymlink::Predicate( PanelController *_target ) const
{
    const auto item = _target.view.item;
    if( !item )
        return false;

    const auto opposite = FindVisibleOppositeController(_target);
    if( !opposite )
        return false;
    
    if( !opposite.isUniform )
        return false;
    
    if( opposite.vfs != item.Host() )
        return false;
    
    if( !opposite.vfs->IsWritable() )
        return false;

    return true;
}

void CreateSymlink::Perform( PanelController *_target, id ) const
{
    const auto item = _target.view.item;
    if( !item )
        return;

    const auto opposite = FindVisibleOppositeController(_target);
    if( !opposite )
        return;

    const auto vfs = opposite.vfs;

    const auto source_path = item.Path();
    const auto link_path = opposite.currentDirectoryPath +
        ( item.IsDotDot() ?
            _target.data.DirectoryPathShort() :
            item.Filename() );

    const auto sheet = [[NCOpsCreateSymlinkDialog alloc] initWithSourcePath:source_path
                                                                andDestPath:link_path];

    const auto handler = ^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK || sheet.linkPath.empty() )
            return;
        const auto dest = sheet.linkPath.front() == '/' ?
            sheet.linkPath :
            item.Directory() + sheet.linkPath;
        const auto focus_opposite = sheet.linkPath.front() == '/';
        const auto value = sheet.sourcePath;
        const auto operation = std::make_shared<nc::ops::Linkage>(dest, value, vfs,
                                                             nc::ops::LinkageType::CreateSymlink);
        __weak PanelController *weak_panel = focus_opposite ? opposite : _target;
        const bool force_refresh = !weak_panel.receivesUpdateNotifications;
        operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion,
                                     [weak_panel, dest, force_refresh]{
            FocusResult((PanelController *)weak_panel, dest, force_refresh);
        });
        [_target.mainWindowController enqueueOperation:operation];
    };

    [_target.mainWindowController beginSheet:sheet.window completionHandler:handler];
}

bool AlterSymlink::Predicate( PanelController *_target ) const
{
    const auto item = _target.view.item;
    return item && item.IsSymlink() && item.Host()->IsWritable();
}
    
void AlterSymlink::Perform( PanelController *_target, id ) const
{
    const auto item = _target.view.item;
    if( !item || !item.IsSymlink() )
        return;
    
    const auto sheet = [[NCOpsAlterSymlinkDialog alloc] initWithSourcePath:item.Symlink()
                                                               andLinkName:item.Filename()];
    const auto handler = ^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        const auto dest = item.Path();
        const auto value = sheet.sourcePath;
        const auto operation = std::make_shared<nc::ops::Linkage>(dest, value, item.Host(),
                                                             nc::ops::LinkageType::AlterSymlink);
        const bool force_refresh = !_target.receivesUpdateNotifications;
        if( force_refresh ) {
            __weak PanelController *weak_panel = _target;
            operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [weak_panel]{
                Refresh((PanelController*)weak_panel);
            });
        }
        [_target.mainWindowController enqueueOperation:operation];
    };
    [_target.mainWindowController beginSheet:sheet.window completionHandler:handler];
}

bool CreateHardlink::Predicate( PanelController *_target ) const
{
    const auto item = _target.view.item;
    return item && !item.IsDir() && item.Host()->IsNativeFS();
}

void CreateHardlink::Perform( PanelController *_target, id ) const
{
    if( !Predicate(_target) )
        return;
    
    const auto item = _target.view.item;
    const auto sheet = [[NCOpsCreateHardlinkDialog alloc] initWithSourceName:item.Filename()];
    const auto handler = ^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;

        std::string path = sheet.result;
        if( path.empty() )
            return;
        
        if( path.front() != '/')
            path = item.Directory() + path;
        
        const auto dest = path;
        const auto value = item.Path();
        const auto operation = std::make_shared<nc::ops::Linkage>(dest, value, item.Host(),
                                                             nc::ops::LinkageType::CreateHardlink);
        const bool force_refresh = !_target.receivesUpdateNotifications;
        __weak PanelController *weak_panel = _target;
        operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion,
                                     [weak_panel, dest, force_refresh]{
            FocusResult((PanelController*)weak_panel, dest,force_refresh );
        });

        [_target.mainWindowController enqueueOperation:operation];
    };
    [_target.mainWindowController beginSheet:sheet.window completionHandler:handler];
}

static PanelController *FindVisibleOppositeController( PanelController *_source )
{
    const auto state = _source.state;
    if( !state.bothPanelsAreVisible )
        return nil;
    if( [state isLeftController:_source] )
        return state.rightPanelController;
    if( [state isRightController:_source] )
        return state.leftPanelController;
    return nil;
}

static void FocusResult( PanelController *_target, const std::string &_path, bool _refresh )
{
    if( !_target  )
        return;
    
    if( dispatch_is_main_queue() ) {
        const auto result_path = boost::filesystem::path(_path);
        const auto directory =  EnsureTrailingSlash(result_path.parent_path().native());
        const auto filename = result_path.filename().native();
        if( _target.isUniform && _target.currentDirectoryPath == directory ) {
            if( _refresh )
                [_target refreshPanel];
            nc::panel::DelayedFocusing req;
            req.filename = filename;
            [_target scheduleDelayedFocusing:req];
        }
    }
    else
        dispatch_to_main_queue([_target, _path, _refresh]{
            FocusResult(_target, _path, _refresh);
        });
}

static void Refresh( PanelController *_target )
{
    if( !_target  )
        return;
    
    if( dispatch_is_main_queue() )
        [_target refreshPanel];
    else
        dispatch_to_main_queue([_target]{
            Refresh(_target);
        });
}

}
