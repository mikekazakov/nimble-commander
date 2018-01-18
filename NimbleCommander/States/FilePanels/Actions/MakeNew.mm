// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MakeNew.h"
#include <NimbleCommander/Core/Alert.h>
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelAux.h"
#include "../PanelData.h"
#include "../PanelView.h"
#include "../../MainWindowController.h"
#include <Operations/DirectoryCreation.h>
#include <Operations/DirectoryCreationDialog.h>
#include <Operations/Copying.h>

namespace nc::panel::actions {

static const auto g_InitialFileName = []() -> string {
    NSString *stub = NSLocalizedString(@"untitled.txt",
                                       "Name for freshly created file by hotkey");
    if( stub && stub.length  )
        return stub.fileSystemRepresentationSafe;
    
    return "untitled.txt";
}();

static const auto g_InitialFolderName = []() -> string {
    NSString *stub = NSLocalizedString(@"untitled folder",
                                       "Name for freshly create folder by hotkey");
    if( stub && stub.length  )
        return stub.fileSystemRepresentationSafe;
    
    return "untitled folder";
}();

static const auto g_InitialFolderWithItemsName = []() -> string {
    NSString *stub = NSLocalizedString(@"New Folder with Items",
                                       "Name for freshly created folder by hotkey with items");
    if( stub && stub.length  )
        return stub.fileSystemRepresentationSafe;
    
    return "New Folder with Items";
}();

static string NextName( const string& _initial, int _index )
{
    path p = _initial;
    if( p.has_extension() ) {
        auto ext = p.extension();
        p.replace_extension();
        return p.native() + " " + to_string(_index) + ext.native();
    }
    else
        return p.native() + " " + to_string(_index);
}

static bool HasEntry( const string &_name, const VFSListing &_listing )
{
    // naive O(n) implementation, may cause troubles on huge listings
    for( int i = 0, e = _listing.Count(); i != e; ++i )
        if( _listing.Filename(i) == _name )
            return true;
    return false;
}

static string FindSuitableName( const string& _initial, const VFSListing &_listing )
{
    auto name = _initial;
    if( !HasEntry(name, _listing) )
        return name;
    
    for( int i = 2; ; ++i ) {
        name = NextName(_initial, i);
        if( !HasEntry(name, _listing) )
            break;
        if( i >= 100 )
            return ""; // we're full of such filenames, no reason to go on
    }
    return name;
}

static void ScheduleRenaming( const string& _filename, PanelController *_panel )
{
    __weak PanelController *weak_panel = _panel;
    DelayedFocusing req;
    req.filename = _filename;
    req.timeout = 2s;
    req.done = [=]{
        dispatch_to_main_queue([weak_panel]{
            [((PanelController*)weak_panel).view startFieldEditorRenaming];
        });
    };
    [_panel scheduleDelayedFocusing:req];
}

static void ScheduleFocus( const string& _filename, PanelController *_panel )
{
    DelayedFocusing req;
    req.filename = _filename;
    req.timeout = 2s;
    [_panel scheduleDelayedFocusing:req];
}

bool MakeNewFile::Predicate( PanelController *_target ) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

void MakeNewFile::Perform( PanelController *_target, id _sender ) const
{
    const path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const VFSListingPtr listing = _target.data.ListingPtr();
    const bool force_reload = vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *weak_panel = _target;
    
    dispatch_to_background([=]{
        auto name = FindSuitableName(g_InitialFileName, *listing);
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

                ScheduleRenaming(name, panel);
            }
        });
    });
}


bool MakeNewFolder::Predicate( PanelController *_target ) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

void MakeNewFolder::Perform( PanelController *_target, id _sender ) const
{
    const path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const VFSListingPtr listing = _target.data.ListingPtr();
    const bool force_reload = vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *weak_panel = _target;

    const auto name = FindSuitableName(g_InitialFolderName, *listing);
    if( name.empty() )
        return;

    const auto op = make_shared<nc::ops::DirectoryCreation>(name, dir.native(), *vfs);
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
        dispatch_to_main_queue([=]{
            if( PanelController *panel = weak_panel ) {
                if( force_reload )
                    [panel refreshPanel];
                ScheduleRenaming(name, panel);
            }
        });
    });

    [_target.mainWindowController enqueueOperation:op];
}

bool MakeNewFolderWithSelection::Predicate( PanelController *_target ) const
{
    auto item = _target.view.item;
    return _target.isUniform &&
            _target.vfs->IsWritable() &&
            item &&
            (!item.IsDotDot() || _target.data.Stats().selected_entries_amount > 0);
}

void MakeNewFolderWithSelection::Perform( PanelController *_target, id _sender ) const
{
    const path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const VFSListingPtr listing = _target.data.ListingPtr();
    const bool force_reload = vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *weak_panel = _target;
    const auto files = _target.selectedEntriesOrFocusedEntry;
    
    if( files.empty() )
        return;
    
    const auto name = FindSuitableName(g_InitialFolderWithItemsName, *listing);
    if( name.empty() )
        return;
    
    const path destination = dir / name / "/";
    
    const auto options = MakeDefaultFileMoveOptions();
    const auto op = make_shared<nc::ops::Copying>(files, destination.native(), vfs, options);
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=]{
        dispatch_to_main_queue([=]{
            if( PanelController *panel = weak_panel ) {
                if( force_reload )
                    [panel refreshPanel];
                
                ScheduleRenaming(name, panel);
            }
        });
    });
    
    [_target.mainWindowController enqueueOperation:op];
}

bool MakeNewNamedFolder::Predicate( PanelController *_target ) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

static bool ValidateDirectoryInput(const string &_text)
{
    const auto max_len = 256;
    if( _text.empty() || _text.length() > max_len )
        return false;
    static const auto invalid_chars = ":\\\r\t\n";
    return _text.find_first_of(invalid_chars) == string::npos;
}
    
void MakeNewNamedFolder::Perform( PanelController *_target, id _sender ) const
{
    const auto cd = [[NCOpsDirectoryCreationDialog alloc] init];
    if( const auto item = _target.view.item )
        if( !item.IsDotDot() )
            cd.suggestion = item.Filename();

    cd.validationCallback = ValidateDirectoryInput;
    
    [_target.mainWindowController beginSheet:cd.window
                           completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK && !cd.result.empty() ) {
            const string name = cd.result;
            const string dir = _target.currentDirectoryPath;
            const auto vfs = _target.vfs;
            const bool force_reload = vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
            __weak PanelController *weak_panel = _target;
            
            const auto op = make_shared<nc::ops::DirectoryCreation>(name, dir, *vfs);
            const auto weak_op = weak_ptr<nc::ops::DirectoryCreation>{op};
            op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
                const auto &dir_names = weak_op.lock()->DirectoryNames();
                const string to_focus = dir_names.empty() ? ""s : dir_names.front();
                dispatch_to_main_queue([=]{
                    if( PanelController *panel = weak_panel ) {
                        if( force_reload )
                            [panel refreshPanel];
                        
                        ScheduleFocus(to_focus, panel);
                    }
                });
            });
            
            [_target.mainWindowController enqueueOperation:op];
        }
    }];
}

}
