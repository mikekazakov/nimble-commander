// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Duplicate.h"
#include "../PanelController.h"
#include <VFS/VFS.h>
#include <Base/CFStackAllocator.h>
#include <Panel/PanelData.h>
#include "../PanelView.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include "../../MainWindowController.h"
#include <Operations/Copying.h>
#include <unordered_set>
#include <Base/dispatch_cpp.h>
#include <Config/Config.h>
#include "Helpers.h"
#include <ankerl/unordered_dense.h>
#include <fmt/format.h>

namespace nc::panel::actions {

using namespace std::literals;

[[clang::no_destroy]] static const auto g_Suffix = "copy"s; // TODO: localize
static const auto g_DeselectConfigFlag = "filePanel.general.deselectItemsAfterFileOperations";

static ankerl::unordered_dense::set<std::string> ExtractFilenames(const VFSListing &_listing);
static std::string ProduceFormCLowercase(std::string_view _string);
static std::string FindFreeFilenameToDuplicateIn(const VFSListingItem &_item,
                                                 const ankerl::unordered_dense::set<std::string> &_filenames);
static void CommonPerform(PanelController *_target, const std::vector<VFSListingItem> &_items, bool _add_deselector);

Duplicate::Duplicate(nc::config::Config &_config) : m_Config(_config)
{
}

bool Duplicate::Predicate(PanelController *_target) const
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

static void CommonPerform(PanelController *_target, const std::vector<VFSListingItem> &_items, bool _add_deselector)
{
    auto directory_filenames = ExtractFilenames(_target.data.Listing());

    for( const auto &item : _items ) {
        auto duplicate = FindFreeFilenameToDuplicateIn(item, directory_filenames);
        if( duplicate.empty() )
            return;
        directory_filenames.emplace(duplicate);

        const auto options = MakeDefaultFileCopyOptions();

        const auto op = std::make_shared<ops::Copying>(
            std::vector<VFSListingItem>{item}, item.Directory() + duplicate, item.Host(), options);

        if( &item == &_items.front() ) {
            __weak PanelController *weak_panel = _target;
            auto finish_handler = [weak_panel, duplicate] {
                dispatch_to_main_queue([weak_panel, duplicate] {
                    if( PanelController *const panel = weak_panel ) {
                        [panel hintAboutFilesystemChange];
                        nc::panel::DelayedFocusing req;
                        req.filename = duplicate;
                        req.timeout = std::chrono::seconds{1};
                        [panel scheduleDelayedFocusing:req];
                    }
                });
            };
            op->ObserveUnticketed(ops::Operation::NotifyAboutCompletion, std::move(finish_handler));
        }

        if( _add_deselector ) {
            const auto deselector = std::make_shared<const DeselectorViaOpNotification>(_target);
            op->SetItemStatusCallback([deselector](nc::ops::ItemStateReport _report) { deselector->Handle(_report); });
        }

        [_target.mainWindowController enqueueOperation:op];
    }
}

void Duplicate::Perform(PanelController *_target, id /*_sender*/) const
{
    CommonPerform(_target, _target.selectedEntriesOrFocusedEntry, m_Config.GetBool(g_DeselectConfigFlag));
}

context::Duplicate::Duplicate(nc::config::Config &_config, const std::vector<VFSListingItem> &_items)
    : m_Config(_config), m_Items(_items)
{
}

bool context::Duplicate::Predicate(PanelController *_target) const
{
    if( !_target.isUniform )
        return false;

    return _target.vfs->IsWritable();
}

void context::Duplicate::Perform(PanelController *_target, id /*_sender*/) const
{
    CommonPerform(_target, m_Items, m_Config.GetBool(g_DeselectConfigFlag));
}

static std::pair<int, std::string> ExtractExistingDuplicateInfo(const std::string &_filename)
{
    const auto suffix_pos = _filename.rfind(g_Suffix);
    if( suffix_pos == std::string::npos )
        return {-1, {}};

    if( suffix_pos + g_Suffix.length() >= _filename.length() - 1 )
        return {1, _filename.substr(0, suffix_pos + g_Suffix.length())};

    try {
        auto index = stoi(_filename.substr(suffix_pos + g_Suffix.length()));
        return {index, _filename.substr(0, suffix_pos + g_Suffix.length())};
    } catch( ... ) {
        return {-1, {}};
    }
}

static std::string FindFreeFilenameToDuplicateIn(const VFSListingItem &_item,
                                                 const ankerl::unordered_dense::set<std::string> &_filenames)
{
    const auto max_duplicates = 100;
    const auto filename = _item.FilenameWithoutExt();
    const auto extension = _item.HasExtension() ? "."s + _item.Extension() : ""s;
    const auto [duplicate_index, filename_wo_index] = ExtractExistingDuplicateInfo(filename);

    if( duplicate_index < 0 )
        for( int i = 1; i < max_duplicates; ++i ) {
            const auto target =
                fmt::format("{} {}{}{}", filename, g_Suffix, (i == 1 ? ""s : " "s + std::to_string(i)), extension);
            if( !_filenames.contains(ProduceFormCLowercase(target)) )
                return target;
        }
    else
        for( int i = duplicate_index + 1; i < max_duplicates; ++i ) {
            const auto target = fmt::format("{} {}{}", filename_wo_index, i, extension);
            if( !_filenames.contains(ProduceFormCLowercase(target)) )
                return target;
        }

    return "";
}

static ankerl::unordered_dense::set<std::string> ExtractFilenames(const VFSListing &_listing)
{
    ankerl::unordered_dense::set<std::string> filenames;
    for( int i = 0, e = _listing.Count(); i != e; ++i )
        filenames.emplace(ProduceFormCLowercase(_listing.Filename(i)));
    return filenames;
}

static std::string ProduceFormCLowercase(std::string_view _string)
{
    const base::CFStackAllocator allocator;

    CFStringRef original = CFStringCreateWithBytesNoCopy(allocator,
                                                         reinterpret_cast<const UInt8 *>(_string.data()),
                                                         _string.length(),
                                                         kCFStringEncodingUTF8,
                                                         false,
                                                         kCFAllocatorNull);

    if( !original )
        return "";

    CFMutableStringRef mutable_string = CFStringCreateMutableCopy(allocator, 0, original);
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
                     reinterpret_cast<UInt8 *>(utf8),
                     MAXPATHLEN - 1,
                     &used);
    utf8[used] = 0;

    CFRelease(mutable_string);
    return utf8;
}

} // namespace nc::panel::actions
