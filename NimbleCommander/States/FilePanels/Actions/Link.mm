#include "Link.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include "../MainWindowFilePanelState.h"
#include "../../MainWindowController.h"
#include <NimbleCommander/Operations/Link/FileLinkNewSymlinkSheetController.h>
#include <Operations/Linkage.h>
#include <Utility/PathManip.h>

namespace nc::panel::actions {

static PanelController *FindVisibleOppositeController( PanelController *_source );
static void FocusResult( PanelController *_target, const string &_path );

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

void CreateSymlink::Perform( PanelController *_target, id _sender ) const
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
            item.Name() );

    FileLinkNewSymlinkSheetController *sheet = [FileLinkNewSymlinkSheetController new];
    const auto handler = ^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK || sheet.linkPath.empty() )
            return;
        const auto dest = sheet.linkPath;
        const auto value = sheet.sourcePath;
        const auto operation = make_shared<nc::ops::Linkage>(dest, value, vfs,
                                                             nc::ops::LinkageType::CreateSymlink);
        __weak PanelController *weak_panel = opposite;
        operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [weak_panel, dest]{
            if( PanelController *panel = weak_panel )
                FocusResult(panel, dest);
        });
        [_target.mainWindowController enqueueOperation:operation];
    };
    
    [sheet showSheetFor:_target.window
             sourcePath:source_path
               linkPath:link_path
      completionHandler:handler];
}

static PanelController *FindVisibleOppositeController( PanelController *_source )
{
    auto state = _source.state;
    if( !state.bothPanelsAreVisible )
        return nil;
    if( [state isLeftController:_source] )
        return state.rightPanelController;
    if( [state isRightController:_source] )
        return state.leftPanelController;
    return nil;
}

static void FocusResult( PanelController *_target, const string &_path )
{
    if( !_target  )
        return;
    
    if( dispatch_is_main_queue() ) {
        const auto result_path = path(_path);
        const auto directory =  EnsureTrailingSlash(result_path.parent_path().native());
        const auto filename = result_path.filename().native();
        if( _target.isUniform && _target.currentDirectoryPath == directory ) {
            [_target refreshPanel];
            nc::panel::DelayedSelection req;
            req.filename = filename;
            [_target ScheduleDelayedSelectionChangeFor:req];
        }
    }
    else
        dispatch_to_main_queue([_target, _path]{
            FocusResult(_target, _path);
        });
}

}
