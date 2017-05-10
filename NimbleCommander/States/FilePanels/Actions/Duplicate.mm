#include "Duplicate.h"
#include "../PanelController.h"
#include <VFS/VFS.h>
#include <Habanero/CFStackAllocator.h>
#include "../PanelData.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include "../MainWindowFilePanelState.h"

namespace nc::panel::actions {

static unordered_set<string> ExtractFilenames( const VFSListing &_listing );
static string ProduceFormCLowercase(string_view _string);
static string FindFreeFilenameToDuplicateIn(const VFSListingItem& _item,
                                            const unordered_set<string> &_filenames);
static void CommonPerform(PanelController *_target, const vector<VFSListingItem> &_items);

bool Duplicate::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
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
        
        auto op = [[FileCopyOperation alloc] initWithItems:{item}
                                           destinationPath:item.Directory() + duplicate
                                           destinationHost:item.Host()
                                                   options:options];
        if( &item == &_items.front() ) {
            const bool force_refresh = !_target.receivesUpdateNotifications;
            __weak PanelController *weak_panel = _target;
            auto finish_handler = ^{
                dispatch_to_main_queue( [weak_panel, duplicate, force_refresh]{
                    if( PanelController *panel = weak_panel) {
                        nc::panel::DelayedSelection req;
                        req.filename = duplicate;
                        [panel ScheduleDelayedSelectionChangeFor:req];
                        if( force_refresh  )
                            [panel refreshPanel];
                    }
                });
            };
            [op AddOnFinishHandler:finish_handler];
         }
        [_target.state AddOperation:op];
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

static string FindFreeFilenameToDuplicateIn(const VFSListingItem& _item,
                                            const unordered_set<string> &_filenames)
{
    string filename = _item.FilenameWithoutExt();
    string ext = _item.HasExtension() ? "."s + _item.Extension() : ""s;
    string target = filename + " copy" + ext;
    
    if( _filenames.count(target) == 0 )
        return target;
    
    for(int i = 2; i < 100; ++i) {
        target = filename + " copy " + to_string(i) + ext;
        
        if( _filenames.count(target) == 0 )
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
