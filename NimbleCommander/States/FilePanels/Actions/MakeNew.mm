#include "MakeNew.h"
#include <NimbleCommander/Core/Alert.h>
#include "../PanelController.h"

namespace panel::actions {

static const auto g_InitialName = []() -> string {
    NSString *stub = NSLocalizedString(@"untitled.txt",
                                       "Name for freshly created file by hotkey");
    if( stub && stub.length  )
        return stub.fileSystemRepresentationSafe;
    
    return "untitled.txt";
}();

static string NextName( int _index )
{
    path p = g_InitialName;
    if( p.has_extension() ) {
        auto ext = p.extension();
        p.replace_extension();
        return p.native() + " " + to_string(_index) + ext.native();
    }
    else
        return p.native() + " " + to_string(_index);
}

static string FindSuitableName( const path &_directory, VFSHost &_host )
{
    auto name = g_InitialName;
    if( !_host.Exists((_directory/name).c_str()) )
        return name;
    
    for( int i = 2; ; ++i ) {
        name = NextName(i);
        if( !_host.Exists( (_directory/name).c_str() ) )
            break;
        if( i >= 100 )
            return ""; // we're full of such filenames, no reason to go on
    }
    return name;
}

bool MakeNewFile::Predicate( PanelController *_target )
{
    return _target.isUniform && _target.vfs->IsWritable();
}

bool MakeNewFile::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate(_target);
}

void MakeNewFile::Perform( PanelController *_target, id _sender )
{
    const path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const bool force_reload = vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *weak_panel = _target;
    
    dispatch_to_background([=]{
        auto name = FindSuitableName(dir, *vfs);
        if( name.empty() )
            return;
        
        int ret = VFSEasyCreateEmptyFile( (dir / name).c_str(), vfs );
        if( ret != 0)
            return dispatch_to_main_queue([=]{
                Alert *alert = [[Alert alloc] init];
                alert.messageText = NSLocalizedString(@"Failed to create an empty file:",
                    "Showing error when trying to create an empty file");
                alert.informativeText = VFSError::ToNSError(ret).localizedDescription;
                [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                [alert runModal];
            });
        
        dispatch_to_main_queue([=]{
            if( PanelController *panel = weak_panel ) {
                if( force_reload )
                    [panel refreshPanel];
                
                PanelControllerDelayedSelection req;
                req.filename = name;
                req.timeout = 2s;
                req.done = [=]{
                    dispatch_to_main_queue([=]{
                        [((PanelController*)weak_panel).view startFieldEditorRenaming];
                    });
                };
                [panel ScheduleDelayedSelectionChangeFor:req];
            }
        });
    });
}

}
