// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MakeNew.h"
#include <NimbleCommander/Core/Alert.h>
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelAux.h"
#include <Panel/PanelData.h>
#include "../PanelView.h"
#include "../../MainWindowController.h"
#include <Operations/DirectoryCreation.h>
#include <Operations/DirectoryCreationDialog.h>
#include <Operations/Copying.h>
#include <Utility/StringExtras.h>
#include <Base/dispatch_cpp.h>

namespace nc::panel::actions {

using namespace std::literals;

[[clang::no_destroy]] static const auto g_InitialFileName = []() -> std::string {
    NSString *const stub = NSLocalizedString(@"untitled.txt", "Name for freshly created file by hotkey");
    if( stub && stub.length )
        return stub.fileSystemRepresentationSafe;

    return "untitled.txt";
}();

[[clang::no_destroy]] static const auto g_InitialFolderName = []() -> std::string {
    NSString *const stub = NSLocalizedString(@"untitled folder", "Name for freshly create folder by hotkey");
    if( stub && stub.length )
        return stub.fileSystemRepresentationSafe;

    return "untitled folder";
}();

[[clang::no_destroy]] static const auto g_InitialFolderWithItemsName = []() -> std::string {
    NSString *const stub =
        NSLocalizedString(@"New Folder with Items", "Name for freshly created folder by hotkey with items");
    if( stub && stub.length )
        return stub.fileSystemRepresentationSafe;

    return "New Folder with Items";
}();

static std::string NextName(const std::string &_initial, int _index)
{
    std::filesystem::path p = _initial;
    if( p.has_extension() ) {
        auto ext = p.extension();
        p.replace_extension();
        return p.native() + " " + std::to_string(_index) + ext.native();
    }
    else
        return p.native() + " " + std::to_string(_index);
}

static bool HasEntry(const std::string &_name, const VFSListing &_listing, bool _case_sensitive)
{
    // naive O(n) implementation, may cause troubles on huge listings
    const unsigned size = _listing.Count();
    if( _case_sensitive ) {
        for( unsigned i = 0; i != size; ++i ) {
            if( _listing.Filename(i) == _name )
                return true;
        }
    }
    else {
        auto name = [NSString stringWithUTF8StdString:_name];
        for( unsigned i = 0; i != size; ++i ) {
            if( [name compare:_listing.FilenameNS(i) options:NSCaseInsensitiveSearch] == NSOrderedSame )
                return true;
        }
    }
    return false;
}

static std::string FindSuitableName(const std::string &_initial, const VFSListing &_listing, bool _case_sensitive)
{
    auto name = _initial;
    if( !HasEntry(name, _listing, _case_sensitive) )
        return name;

    for( int i = 2;; ++i ) {
        name = NextName(_initial, i);
        if( !HasEntry(name, _listing, _case_sensitive) )
            break;
        if( i >= 100 )
            return ""; // we're full of such filenames, no reason to go on
    }
    return name;
}

static void ScheduleRenaming(const std::string &_filename, PanelController *_panel)
{
    __weak PanelController *weak_panel = _panel;
    DelayedFocusing req;
    req.filename = _filename;
    req.timeout = 2s;
    req.done = [=] {
        [static_cast<PanelController *>(weak_panel).view discardFieldEditor];
        [static_cast<PanelController *>(weak_panel).view startFieldEditorRenaming];
    };
    [_panel scheduleDelayedFocusing:req];
}

static void ScheduleFocus(const std::string &_filename, PanelController *_panel)
{
    DelayedFocusing req;
    req.filename = _filename;
    req.timeout = 2s;
    [_panel scheduleDelayedFocusing:req];
}

bool MakeNewFile::Predicate(PanelController *_target) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

void MakeNewFile::Perform(PanelController *_target, id /*_sender*/) const
{
    const std::filesystem::path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const VFSListingPtr listing = _target.data.ListingPtr();
    __weak PanelController *weak_panel = _target;

    dispatch_to_background([=] {
        const bool case_sensitive = vfs->IsCaseSensitiveAtPath(dir.c_str());
        auto name = FindSuitableName(g_InitialFileName, *listing, case_sensitive);
        if( name.empty() )
            return;

        const int ret = VFSEasyCreateEmptyFile((dir / name).c_str(), vfs);
        if( ret != 0 ) {
            dispatch_to_main_queue([=] {
                Alert *const alert = [[Alert alloc] init];
                alert.messageText = NSLocalizedString(@"Failed to create an empty file:",
                                                      "Showing error when trying to create an empty file");
                alert.informativeText = VFSError::ToNSError(ret).localizedDescription;
                [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                [alert runModal];
            });
            return;
        }

        dispatch_to_main_queue([=] {
            if( PanelController *const panel = weak_panel ) {
                [panel hintAboutFilesystemChange];
                ScheduleRenaming(name, panel);
            }
        });
    });
}

bool MakeNewFolder::Predicate(PanelController *_target) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

void MakeNewFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    const std::filesystem::path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const VFSListingPtr listing = _target.data.ListingPtr();
    const bool case_sensitive = vfs->IsCaseSensitiveAtPath(dir.c_str());
    __weak PanelController *weak_panel = _target;

    const auto name = FindSuitableName(g_InitialFolderName, *listing, case_sensitive);
    if( name.empty() )
        return;

    const auto op = std::make_shared<nc::ops::DirectoryCreation>(name, dir.native(), *vfs);
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
        dispatch_to_main_queue([=] {
            if( PanelController *const panel = weak_panel ) {
                [panel hintAboutFilesystemChange];
                ScheduleRenaming(name, panel);
            }
        });
    });

    [_target.mainWindowController enqueueOperation:op];
}

bool MakeNewFolderWithSelection::Predicate(PanelController *_target) const
{
    auto item = _target.view.item;
    return _target.isUniform && _target.vfs->IsWritable() && item &&
           (!item.IsDotDot() || _target.data.Stats().selected_entries_amount > 0);
}

void MakeNewFolderWithSelection::Perform(PanelController *_target, id /*_sender*/) const
{
    const std::filesystem::path dir = _target.currentDirectoryPath;
    const VFSHostPtr vfs = _target.vfs;
    const VFSListingPtr listing = _target.data.ListingPtr();
    const bool case_sensitive = vfs->IsCaseSensitiveAtPath(dir.c_str());
    __weak PanelController *weak_panel = _target;
    const auto files = _target.selectedEntriesOrFocusedEntry;

    if( files.empty() )
        return;

    const auto name = FindSuitableName(g_InitialFolderWithItemsName, *listing, case_sensitive);
    if( name.empty() )
        return;

    const std::filesystem::path destination = (dir / name).concat("/");

    const auto options = MakeDefaultFileMoveOptions();
    const auto op = std::make_shared<nc::ops::Copying>(files, destination.native(), vfs, options);
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=] {
        dispatch_to_main_queue([=] {
            if( PanelController *const panel = weak_panel ) {
                [panel hintAboutFilesystemChange];
                ScheduleRenaming(name, panel);
            }
        });
    });

    [_target.mainWindowController enqueueOperation:op];
}

bool MakeNewNamedFolder::Predicate(PanelController *_target) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

static bool ValidateDirectoryInput(const std::string &_text)
{
    const auto max_len = 256;
    if( _text.empty() || _text.length() > max_len )
        return false;
    static const auto invalid_chars = ":\\\r\t\n";
    return _text.find_first_of(invalid_chars) == std::string::npos;
}

void MakeNewNamedFolder::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto cd = [[NCOpsDirectoryCreationDialog alloc] init];
    if( const auto item = _target.view.item )
        if( !item.IsDotDot() )
            cd.suggestion = item.Filename();

    cd.validationCallback = ValidateDirectoryInput;

    [_target.mainWindowController beginSheet:cd.window
                           completionHandler:^(NSModalResponse returnCode) {
                             if( returnCode == NSModalResponseOK && !cd.result.empty() ) {
                                 const std::string name = cd.result;
                                 const std::string dir = _target.currentDirectoryPath;
                                 const auto vfs = _target.vfs;
                                 __weak PanelController *weak_panel = _target;

                                 const auto op = std::make_shared<nc::ops::DirectoryCreation>(name, dir, *vfs);
                                 const auto weak_op = std::weak_ptr<nc::ops::DirectoryCreation>{op};
                                 op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
                                     const auto &dir_names = weak_op.lock()->DirectoryNames();
                                     const std::string to_focus = dir_names.empty() ? ""s : dir_names.front();
                                     dispatch_to_main_queue([=] {
                                         if( PanelController *const panel = weak_panel ) {
                                             [panel hintAboutFilesystemChange];
                                             ScheduleFocus(to_focus, panel);
                                         }
                                     });
                                 });

                                 [_target.mainWindowController enqueueOperation:op];
                             }
                           }];
}

} // namespace nc::panel::actions
