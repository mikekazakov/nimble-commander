// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Duplicate.h"
#include "../PanelController.h"
#include <VFS/VFS.h>
#include <Habanero/CFStackAllocator.h>
#include "../PanelData.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include "../../MainWindowController.h"
#include <Operations/Copying.h>

namespace nc::panel::actions {

static const auto g_Suffix = "copy"s; // TODO: localize

static unordered_set<string> ExtractFilenames( const VFSListing &_listing );
static string ProduceFormCLowercase(string_view _string);
static string FindFreeFilenameToDuplicateIn(const VFSListingItem& _item,
                                            const unordered_set<string> &_filenames);
static void CommonPerform(PanelController *_target, const vector<VFSListingItem> &_items);

bool Duplicate::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
        return false;
    
    if( !_target.vfs->IsWritable() )
        return false;
    
    const auto i = _target.view.item;
    if( !i )
        return false;
    
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

static void CommonPerform(PanelController *_target, const vector<VFSListingItem> &_items)
{
    auto directory_filenames = ExtractFilenames(_target.data.Listing());

    for( const auto &item: _items) {
        auto duplicate = FindFreeFilenameToDuplicateIn(item, directory_filenames);
        if( duplicate.empty() )
            return;
        directory_filenames.emplace(duplicate);
        
        const auto options = MakeDefaultFileCopyOptions();
        
        const auto op = make_shared<ops::Copying>(vector<VFSListingItem>{item},
                                                      item.Directory() + duplicate,
                                                      item.Host(),
                                                      options);

        if( &item == &_items.front() ) {
            const bool force_refresh = !_target.receivesUpdateNotifications;
            __weak PanelController *weak_panel = _target;
            auto finish_handler = ^{
                dispatch_to_main_queue( [weak_panel, duplicate, force_refresh]{
                    if( PanelController *panel = weak_panel) {
                        nc::panel::DelayedFocusing req;
                        req.filename = duplicate;
                        [panel scheduleDelayedFocusing:req];
                        if( force_refresh  )
                            [panel refreshPanel];
                    }
                });
            };
            op->ObserveUnticketed(ops::Operation::NotifyAboutCompletion, finish_handler);
         }
        [_target.mainWindowController enqueueOperation:op];
    }
}

void Duplicate::Perform( PanelController *_target, id _sender ) const
{
    CommonPerform(_target, _target.selectedEntriesOrFocusedEntry);
}

context::Duplicate::Duplicate(const vector<VFSListingItem> &_items):
    m_Items(_items)
{
}

bool context::Duplicate::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
        return false;
    
    return _target.vfs->IsWritable();
}

void context::Duplicate::Perform( PanelController *_target, id _sender ) const
{
    CommonPerform(_target, m_Items);
}

static pair<int, string> ExtractExistingDuplicateInfo( const string &_filename )
{
    const auto suffix_pos = _filename.rfind(g_Suffix);
    if( suffix_pos == string::npos )
        return {-1, {}};
    
    if( suffix_pos + g_Suffix.length() >= _filename.length() - 1 )
        return {1, _filename.substr(0, suffix_pos + g_Suffix.length())};
    
    try {
        auto index = stoi( _filename.substr(suffix_pos + g_Suffix.length()) );
        return {index, _filename.substr(0, suffix_pos + g_Suffix.length())};
    }
    catch (...) {
        return {-1, {}};
    }
}

static string FindFreeFilenameToDuplicateIn(const VFSListingItem& _item,
                                            const unordered_set<string> &_filenames)
{
    const auto max_duplicates = 100;
    const auto filename = _item.FilenameWithoutExt();
    const auto extension = _item.HasExtension() ? "."s + _item.Extension() : ""s;
    const auto [duplicate_index, filename_wo_index] = ExtractExistingDuplicateInfo(filename);
    
    if( duplicate_index < 0 )
        for(int i = 1; i < max_duplicates; ++i) {
            auto target = filename + " " + g_Suffix + (i == 1 ? "" : " "+to_string(i)) + extension;
            if( _filenames.count(ProduceFormCLowercase(target)) == 0 )
                return target;
        }
    else
        for(int i = duplicate_index + 1; i < max_duplicates; ++i) {
            auto target = filename_wo_index + " " + to_string(i) + extension;
            if( _filenames.count(ProduceFormCLowercase(target)) == 0 )
                return target;
        }
    
    return "";
}

static unordered_set<string> ExtractFilenames( const VFSListing &_listing )
{
    unordered_set<string> filenames;
    for( int i = 0, e = _listing.Count(); i != e; ++i )
        filenames.emplace( ProduceFormCLowercase(_listing.Filename(i)) );
    return filenames;
}

static string ProduceFormCLowercase(string_view _string)
{
    CFStackAllocator allocator;

    CFStringRef original = CFStringCreateWithBytesNoCopy(allocator.Alloc(),
                                                         (UInt8*)_string.data(),
                                                         _string.length(),
                                                         kCFStringEncodingUTF8,
                                                         false,
                                                         kCFAllocatorNull);
    
    if( !original )
        return "";
    
    CFMutableStringRef mutable_string = CFStringCreateMutableCopy(allocator.Alloc(), 0, original);
    CFRelease(original);
    if( !mutable_string )
        return "";
    
    CFStringLowercase(mutable_string, nullptr);
    CFStringNormalize(mutable_string, kCFStringNormalizationFormC);

    char utf8[MAXPATHLEN];
    long used = 0;
    CFStringGetBytes(mutable_string,
                     CFRangeMake(0, CFStringGetLength(mutable_string)),
                     kCFStringEncodingUTF8,
                     0,
                     false,
                     (UInt8*)utf8,
                     MAXPATHLEN-1,
                     &used);
    utf8[used] = 0;
    
    CFRelease(mutable_string);
    return utf8;
}

}
