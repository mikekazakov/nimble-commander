// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DragReceiver.h"
#include "FilesDraggingSource.h"
#include "PanelController.h"
#include <Panel/PanelData.h>
#include <Panel/Log.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <Utility/NativeFSManager.h>
#include <Utility/ObjCpp.h>
#include <Utility/PathManip.h>
#include <Utility/StringExtras.h>
#include <Utility/URLSecurityScopedResourceGuard.h>
#include "PanelAux.h"
#include <Operations/Linkage.h>
#include <Operations/Copying.h>
#include <NimbleCommander/Core/Alert.h>
#include <Base/dispatch_cpp.h>
#include "../MainWindowController.h"
#include <VFS/Native.h>
#include <map>
#include <filesystem>
#include <expected>
#include <iostream>
#include <algorithm>

namespace nc::panel {

using namespace std::literals;

static void UpdateValidDropNumber(id<NSDraggingInfo> _dragging, int _valid_number, NSDragOperation _operation);
static bool DraggingIntoFoldersAllowed() noexcept;
static void PrintDragOperations(NSDragOperation _op);
static std::vector<VFSListingItem> ExtractListingItems(FilesDraggingSource *_source);
static NSArray<NSURL *> *ExtractURLs(NSPasteboard *_source);
static int CountItemsWithType(id<NSDraggingInfo> _sender, NSString *_type);
static NSString *URLs_Promise_UTI();
static NSString *URLs_UTI();
static std::expected<std::vector<VFSListingItem>, Error> FetchListingItems(NSArray<NSURL *> *_input, VFSHost &_host);

static void AddPanelRefreshIfNecessary(PanelController *_target, ops::Operation &_operation);
static void AddPanelRefreshIfNecessary(PanelController *_target, PanelController *_source, ops::Operation &_operation);

DragReceiver::DragReceiver(PanelController *_target,
                           id<NSDraggingInfo> _dragging,
                           int _dragging_over_index,
                           nc::utility::NativeFSManager &_native_fs_man,
                           nc::vfs::NativeHost &_native_host)
    : m_Target(_target), m_Dragging(_dragging), m_DraggingOverIndex(_dragging_over_index),
      m_NativeFSManager(_native_fs_man), m_NativeHost(_native_host)
{
    if( !m_Target || !m_Dragging )
        throw std::invalid_argument("DragReceiver can't accept nil arguments");

    m_DraggingOperationsMask = m_Dragging.draggingSourceOperationMask;
    m_ItemUnderDrag = m_Target.data.EntryAtSortPosition(m_DraggingOverIndex);
    m_DraggingOverDirectory = m_ItemUnderDrag && m_ItemUnderDrag.IsDir();
}

DragReceiver::~DragReceiver() = default;

NSDragOperation DragReceiver::Validate()
{
    if( m_ItemUnderDrag ) {
        if( m_DraggingOverDirectory && !DraggingIntoFoldersAllowed() )
            return NSDragOperationNone;
        if( !m_DraggingOverDirectory )
            return NSDragOperationNone;
    }

    int valid_items = 0;
    NSDragOperation operation = NSDragOperationNone;
    const auto destination = ComposeDestination();

    if( destination )
        panel::Log::Trace("DragReceiver::Validate() - dragging over path: {}{}",
                          destination.Host()->JunctionPath(),
                          destination.Path());
    else
        panel::Log::Trace("DragReceiver::Validate() - dragging over an empty destination");

    if( destination && destination.Host()->IsWritable() ) {
        if( const auto source = objc_cast<FilesDraggingSource>(m_Dragging.draggingSource) )
            std::tie(operation, valid_items) = ScanLocalSource(source, destination);
        else if( [m_Dragging.draggingPasteboard.types containsObject:URLs_UTI()] )
            std::tie(operation, valid_items) = ScanURLsSource(ExtractURLs(m_Dragging.draggingPasteboard), destination);
        else if( [m_Dragging.draggingPasteboard.types containsObject:URLs_Promise_UTI()] )
            std::tie(operation, valid_items) = ScanURLsPromiseSource(destination);
    }

    if( valid_items == 0 ) {
        // regardless of a previous logic - we can't accept an unacceptable drags
        operation = NSDragOperationNone;
    }
    else if( operation == NSDragOperationNone ) {
        // inverse - we can't drag here anything - amount of draggable items should be zero
        valid_items = 0;
    }

    UpdateValidDropNumber(m_Dragging, valid_items, operation);
    m_Dragging.draggingFormation = NSDraggingFormationList;

    return operation;
}

bool DragReceiver::Receive()
{
    const auto destination = ComposeDestination();
    if( !destination || !destination.Host()->IsWritable() )
        return false;

    if( const auto source = objc_cast<FilesDraggingSource>(m_Dragging.draggingSource) )
        return PerformWithLocalSource(source, destination);
    else if( [m_Dragging.draggingPasteboard.types containsObject:URLs_UTI()] )
        return PerformWithURLsSource(ExtractURLs(m_Dragging.draggingPasteboard), destination);
    else if( [m_Dragging.draggingPasteboard.types containsObject:URLs_Promise_UTI()] )
        return PerformWithURLsPromiseSource(destination);

    return false;
}

std::pair<NSDragOperation, int> DragReceiver::ScanLocalSource(FilesDraggingSource *_source,
                                                              const vfs::VFSPath &_dest) const
{
    const auto valid_items = static_cast<int>(_source.items.size());
    NSDragOperation operation = NSDragOperationNone;
    if( _source.sourceController == m_Target && !m_DraggingOverDirectory )
        operation = NSDragOperationNone; // we can't drag into the same dir on the same panel
    else
        operation = BuildOperationForLocal(_source, _dest);

    // check that we dont drag an item to the same folder in other panel
    if( operation != NSDragOperationNone ) {
        const auto same_folder = any_of(begin(_source.items), end(_source.items), [&](auto &_i) {
            return _i.item.Directory() == _dest.Path() && _i.item.Host() == _dest.Host();
        });
        if( same_folder )
            operation = NSDragOperationNone;
    }

    // check that we dont drag a folder into itself
    if( operation != NSDragOperationNone && m_DraggingOverDirectory ) {
        // filenames are stored without trailing slashes, so have to add it
        for( const auto &item : _source.items )
            if( item.item.Host() == _dest.Host() && item.item.IsDir() && _dest.Path() == item.item.Path() + "/" ) {
                operation = NSDragOperationNone;
                break;
            }
    }

    return {operation, valid_items};
}

std::pair<NSDragOperation, int> DragReceiver::ScanURLsSource(NSArray<NSURL *> *_urls,
                                                             const vfs::VFSPath &_destination) const
{
    if( !_urls )
        return {NSDragOperationNone, 0};

    const auto valid_items = static_cast<int>(_urls.count);
    NSDragOperation operation = BuildOperationForURLs(_urls, _destination);

    if( operation != NSDragOperationNone && _destination.Host()->IsNativeFS() ) {
        for( NSURL *url in _urls )
            if( _destination.Path() == url.fileSystemRepresentation + "/"s ) {
                operation = NSDragOperationNone;
                break;
            }
    }

    return {operation, valid_items};
}

std::pair<NSDragOperation, int> DragReceiver::ScanURLsPromiseSource(const vfs::VFSPath &_dest) const
{
    if( !_dest.Host()->IsNativeFS() )
        return {NSDragOperationNone, 0};

    const auto valid_items = CountItemsWithType(m_Dragging, URLs_Promise_UTI());
    const NSDragOperation operation = NSDragOperationCopy;

    return {operation, valid_items};
}

vfs::VFSPath DragReceiver::ComposeDestination() const
{
    if( m_DraggingOverDirectory ) {
        if( m_ItemUnderDrag.IsDotDot() ) {
            if( !m_Target.isUniform )
                return {};
            auto vfs = m_Target.vfs;

            std::filesystem::path parent_dir = nc::utility::PathManip::Parent(m_Target.currentDirectoryPath);
            if( parent_dir.empty() && vfs->Parent() != nullptr ) {
                // 'escape' from the current vfs into the parent one
                parent_dir = nc::utility::PathManip::Parent(vfs->JunctionPath());
                vfs = vfs->Parent();
            }

            if( parent_dir.empty() ) {
                parent_dir += "/"; // ensure that the path is 1) non-empty 2) has a trailing slash
            }

            return {vfs, std::move(parent_dir)};
        }
        else {
            return {m_ItemUnderDrag.Host(), m_ItemUnderDrag.Path() + "/"};
        }
    }
    else {
        if( !m_Target.isUniform )
            return {};
        return {m_Target.vfs, m_Target.currentDirectoryPath};
    }
}

NSDragOperation DragReceiver::BuildOperationForLocal(FilesDraggingSource *_source,
                                                     const vfs::VFSPath &_destination) const
{
    if( m_DraggingOperationsMask == NSDragOperationCopy )
        return NSDragOperationCopy;

    const auto src_and_dst_native = _destination.Host()->IsNativeFS() && _source.areAllHostsNative;
    if( src_and_dst_native ) {
        if( m_DraggingOperationsMask == NSDragOperationLink ||
            m_DraggingOperationsMask == (NSDragOperationCopy | NSDragOperationGeneric) )
            return NSDragOperationLink;

        if( m_DraggingOperationsMask == NSDragOperationGeneric )
            return NSDragOperationMove;

        if( m_DraggingOperationsMask & NSDragOperationGeneric ) {
            const auto v1 = m_NativeFSManager.VolumeFromPath(_destination.Path());
            const auto v2 = m_NativeFSManager.VolumeFromPath(_source.items.front().item.Directory());
            const auto same_native_fs = (v1 != nullptr && v1 == v2);
            return same_native_fs ? NSDragOperationMove : NSDragOperationCopy;
        }
    }
    else {
        if( _source.commonHost == _destination.Host() ) {
            if( m_DraggingOperationsMask & NSDragOperationGeneric )
                return _source.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
        }
        else {
            if( m_DraggingOperationsMask == NSDragOperationGeneric )
                return _source.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
            if( m_DraggingOperationsMask & NSDragOperationGeneric )
                return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

NSDragOperation DragReceiver::BuildOperationForURLs(NSArray<NSURL *> *_source, const vfs::VFSPath &_destination) const
{
    if( _source.count == 0 || !_destination )
        return NSDragOperationNone;

    if( m_DraggingOperationsMask == NSDragOperationCopy )
        return NSDragOperationCopy;

    if( m_DraggingOperationsMask == NSDragOperationGeneric )
        return NSDragOperationMove;

    if( _destination.Host()->IsNativeFS() ) {
        if( m_DraggingOperationsMask == NSDragOperationLink ||
            m_DraggingOperationsMask == (NSDragOperationCopy | NSDragOperationGeneric) )
            return NSDragOperationLink;

        if( m_DraggingOperationsMask & NSDragOperationGeneric ) {
            const auto v1 = m_NativeFSManager.VolumeFromPath(_destination.Path());
            const auto v2 = m_NativeFSManager.VolumeFromPath(_source.firstObject.fileSystemRepresentation);
            const auto same_native_fs = (v1 != nullptr && v1 == v2);
            return same_native_fs ? NSDragOperationMove : NSDragOperationCopy;
        }
    }
    else {
        if( m_DraggingOperationsMask & NSDragOperationGeneric )
            return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}

bool DragReceiver::PerformWithLocalSource(FilesDraggingSource *_source, const vfs::VFSPath &_destination)
{
    const auto files = ExtractListingItems(_source);
    if( files.empty() )
        return false;

    const auto operation = BuildOperationForLocal(_source, _destination);
    if( operation == NSDragOperationCopy ) {
        const auto opts = MakeDefaultFileCopyOptions();
        const auto op = std::make_shared<ops::Copying>(files, _destination.Path(), _destination.Host(), opts);
        AddPanelRefreshIfNecessary(m_Target, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    else if( operation == NSDragOperationMove ) {
        const auto opts = MakeDefaultFileMoveOptions();
        const auto op = std::make_shared<ops::Copying>(files, _destination.Path(), _destination.Host(), opts);
        AddPanelRefreshIfNecessary(m_Target, _source.sourceController, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    else if( operation == NSDragOperationLink && _source.areAllHostsNative && _destination.Host()->IsNativeFS() ) {
        for( const auto &file : files ) {
            const auto source_path = file.Path();
            const auto dest_path = std::filesystem::path(_destination.Path()) / file.Filename();
            const auto op = std::make_shared<nc::ops::Linkage>(
                dest_path.native(), source_path, _destination.Host(), nc::ops::LinkageType::CreateSymlink);
            AddPanelRefreshIfNecessary(m_Target, *op);
            [m_Target.mainWindowController enqueueOperation:op];
        }
        return true;
    }
    return false;
}

bool DragReceiver::PerformWithURLsSource(NSArray<NSURL *> *_source, const vfs::VFSPath &_destination)
{
    if( !_source || _source.count == 0 )
        return false;

    // start accessing the security scoped resources identified by the urls if any there are any.
    // this guard must be kept alive until operations finish, hence it's attached to observers.
    const auto urls_access_guard = std::make_shared<utility::URLSecurityScopedResourceGuard>(_source);

    const auto operation = BuildOperationForURLs(_source, _destination);

    // currently fetching listings synchronously in main thread, which is BAAAD
    auto source_items = FetchListingItems(_source, m_NativeHost);

    if( !source_items.has_value() ) {
        // failed to fetch the source items.
        // refuse the drag and show an error message asynchronously.
        const Error &error = source_items.error();
        dispatch_to_main_queue([error] {
            Alert *const alert = [[Alert alloc] init];
            alert.messageText = NSLocalizedString(@"Failed to access the dragged item:",
                                                  "Showing error when failed to access the dragged items");
            alert.informativeText = [NSString stringWithUTF8StdString:error.LocalizedFailureReason()];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
        return false;
    }

    if( operation == NSDragOperationCopy ) {
        const auto opts = MakeDefaultFileCopyOptions();
        const auto op = std::make_shared<nc::ops::Copying>(
            std::move(*source_items), _destination.Path(), _destination.Host(), opts);
        op->Observe(ops::Operation::NotifyAboutFinish, [urls_access_guard] {});
        AddPanelRefreshIfNecessary(m_Target, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    if( operation == NSDragOperationMove ) {
        const auto opts = MakeDefaultFileMoveOptions();
        const auto op = std::make_shared<nc::ops::Copying>(
            std::move(*source_items), _destination.Path(), _destination.Host(), opts);
        op->Observe(ops::Operation::NotifyAboutFinish, [urls_access_guard] {});
        AddPanelRefreshIfNecessary(m_Target, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    if( operation == NSDragOperationLink ) {
        for( const auto &file : *source_items ) {
            const auto source_path = file.Path();
            const auto dest_path = std::filesystem::path(_destination.Path()) / file.Filename();
            const auto op = std::make_shared<nc::ops::Linkage>(
                dest_path.native(), source_path, _destination.Host(), nc::ops::LinkageType::CreateSymlink);
            op->Observe(ops::Operation::NotifyAboutFinish, [urls_access_guard] {});
            AddPanelRefreshIfNecessary(m_Target, *op);
            [m_Target.mainWindowController enqueueOperation:op];
        }
        return true;
    }
    return false;
}

bool DragReceiver::PerformWithURLsPromiseSource(const vfs::VFSPath &_dest)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    const auto drop_url = [NSURL fileURLWithFileSystemRepresentation:_dest.Path().c_str()
                                                         isDirectory:true
                                                       relativeToURL:nil];
    [m_Dragging namesOfPromisedFilesDroppedAtDestination:drop_url];
#pragma clang diagnostic pop
    return true;
}

NSArray<NSString *> *DragReceiver::AcceptedUTIs()
{
    // why don't we support filenames pasteboard?
    static const auto utis = @[
        FilesDraggingSource.fileURLsPromiseDragUTI,
        FilesDraggingSource.fileURLsDragUTI,
        FilesDraggingSource.privateDragUTI
    ];
    return utis;
}

static void UpdateValidDropNumber(id<NSDraggingInfo> _dragging, int _valid_number, NSDragOperation _operation)
{
    // prevent setting of a same value to DraggingInfo, since it causes weird blinking
    static __weak id last_updated = nil;
    static int last_set = 0;

    if( last_updated == _dragging ) {
        if( last_set != _valid_number ) {
            last_set = _valid_number;
            if( _operation != NSDragOperationNone )
                _dragging.numberOfValidItemsForDrop = last_set;
        }
    }
    else {
        last_updated = _dragging;
        last_set = _valid_number;
        if( _operation != NSDragOperationNone )
            _dragging.numberOfValidItemsForDrop = last_set;
    }
}

static bool DraggingIntoFoldersAllowed() noexcept
{
    static const auto path = "filePanel.general.allowDraggingIntoFolders";
    static const auto fetch = [] { return GlobalConfig().GetBool(path); };
    static bool value = [] {
        GlobalConfig().ObserveForever(path, [] { value = fetch(); });
        return fetch();
    }();
    return value;
}

[[maybe_unused]] static void PrintDragOperations(NSDragOperation _op)
{
    if( _op == NSDragOperationNone ) {
        std::cout << "NSDragOperationNone" << '\n';
    }
    else if( _op == NSDragOperationEvery ) {
        std::cout << "NSDragOperationEvery" << '\n';
    }
    else {
        if( _op & NSDragOperationCopy )
            std::cout << "NSDragOperationCopy ";
        if( _op & NSDragOperationLink )
            std::cout << "NSDragOperationLink ";
        if( _op & NSDragOperationGeneric )
            std::cout << "NSDragOperationGeneric ";
        if( _op & NSDragOperationPrivate )
            std::cout << "NSDragOperationPrivate ";
        if( _op & NSDragOperationMove )
            std::cout << "NSDragOperationMove ";
        if( _op & NSDragOperationDelete )
            std::cout << "NSDragOperationDelete ";
        std::cout << '\n';
    }
}

static std::vector<VFSListingItem> ExtractListingItems(FilesDraggingSource *_source)
{
    std::vector<VFSListingItem> files;
    for( PanelDraggingItem *const &item : _source.items )
        files.emplace_back(item.item);
    return files;
}

static NSArray<NSURL *> *ExtractURLs(NSPasteboard *_source)
{
    static const auto read_opts = @{NSPasteboardURLReadingFileURLsOnlyKey: @YES};
    static const auto classes = @[NSURL.class];
    return [_source readObjectsForClasses:classes options:read_opts];
}

static NSString *URLs_Promise_UTI()
{
    static const auto uti = FilesDraggingSource.fileURLsPromiseDragUTI;
    return uti;
}

static NSString *URLs_UTI()
{
    static const auto uti = FilesDraggingSource.fileURLsDragUTI;
    return uti;
}

static std::expected<std::vector<VFSListingItem>, Error> FetchListingItems(NSArray<NSURL *> *_input, VFSHost &_host)
{
    // TODO:
    // The current implementation uses a rather moronic approach of fetching multiple single-item
    // listings. That is very inefficient as listings are meant to be bulky by nature.
    // However the implementation cannot use Host::FetchFlexibleListingItems() on a per-directory
    // basis as this might break the paranoid security model coming with NSURL. One can end up in a
    // situation when they can access a file but cannot access a directory where this file is
    // located. This breaks the mechanics of FetchDirectoryListing(), which
    // FetchFlexibleListingItems() uses under the hood. Ideally FetchFlexibleListingItems needs to
    // be made virtual so that implementation like Native can provide more efficient implementations
    // AND this function need to imply that there might not be any access to the directories and the
    // implementation must rely only on stat()-level functions.
    std::vector<VFSListingItem> source_items;
    for( NSURL *url : _input ) {
        const std::expected<VFSListingPtr, Error> listing =
            _host.FetchSingleItemListing(url.fileSystemRepresentation, 0);
        if( listing ) {
            assert(*listing && (*listing)->Count() == 1);
            source_items.emplace_back((*listing)->Item(0));
        }
        else
            return std::unexpected(listing.error());
    }
    return source_items;
}

static void AddPanelRefreshIfNecessary(PanelController *_target, ops::Operation &_operation)
{
    __weak PanelController *cntr = _target;
    _operation.ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
        dispatch_to_main_queue([cntr] {
            if( PanelController *const pc = cntr )
                [pc hintAboutFilesystemChange];
        });
    });
}

static void AddPanelRefreshIfNecessary(PanelController *_target, PanelController *_source, ops::Operation &_operation)
{
    AddPanelRefreshIfNecessary(_target, _operation);
    AddPanelRefreshIfNecessary(_source, _operation);
}

static int CountItemsWithType(id<NSDraggingInfo> _sender, NSString *_type)
{
    static const auto classes = @[NSPasteboardItem.class];
    static const auto options = @{};
    __block int amount = 0;
    const auto block = ^(NSDraggingItem *draggingItem, NSInteger, BOOL *) {
      if( const auto i = objc_cast<NSPasteboardItem>(draggingItem.item) )
          if( [i.types containsObject:_type] )
              amount++;
    };
    [_sender enumerateDraggingItemsWithOptions:0 forView:nil classes:classes searchOptions:options usingBlock:block];
    return amount;
}

} // namespace nc::panel
