// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DragReceiver.h"
#include "FilesDraggingSource.h"
#include "PanelController.h"
#include "PanelData.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include <Utility/NativeFSManager.h>
#include <Utility/ObjCpp.h>
#include "PanelAux.h"
#include <Operations/Linkage.h>
#include <Operations/Copying.h>
#include "../MainWindowController.h"
#include <VFS/Native.h>
#include <map>

namespace nc::panel {

using namespace std::literals;

static void UpdateValidDropNumber(id <NSDraggingInfo> _dragging,
                                  int _valid_number,
                                  NSDragOperation _operation );
static bool DraggingIntoFoldersAllowed();
static void PrintDragOperations(NSDragOperation _op);
static std::vector<VFSListingItem> ExtractListingItems(FilesDraggingSource *_source);
static NSArray<NSURL*> *ExtractURLs(NSPasteboard *_source);
static int CountItemsWithType( id<NSDraggingInfo> _sender, NSString *_type );
static NSString *URLs_Promise_UTI();
static NSString *URLs_UTI();
static std::map<std::string, std::vector<std::string>>
    LayoutURLsByDirectories(NSArray<NSURL*> *_file_urls);
static std::vector<VFSListingItem>
    FetchDirectoriesItems(const std::map<std::string, std::vector<std::string>>& _input, VFSHost& _host);
static void AddPanelRefreshIfNecessary(PanelController *_target,
                                       ops::Operation &_operation);
static void AddPanelRefreshIfNecessary(PanelController *_target,
                                       PanelController *_source,
                                       ops::Operation &_operation);

DragReceiver::DragReceiver(PanelController *_target,
                           id <NSDraggingInfo> _dragging,
                           int _dragging_over_index):
    m_Target(_target),
    m_Dragging(_dragging),
    m_DraggingOverIndex(_dragging_over_index)
{
    if( !m_Target || !m_Dragging )
        throw std::invalid_argument("DragReceiver can't accept nil arguments");

    m_DraggingOperationsMask = m_Dragging.draggingSourceOperationMask;
    m_ItemUnderDrag = m_Target.data.EntryAtSortPosition(m_DraggingOverIndex);
    m_DraggingOverDirectory = m_ItemUnderDrag && m_ItemUnderDrag.IsDir();
}

DragReceiver::~DragReceiver()
{
}

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
    if( destination && destination.Host()->IsWritable() ) {
        if( const auto source = objc_cast<FilesDraggingSource>(m_Dragging.draggingSource) )
            std::tie(operation, valid_items) = ScanLocalSource(source, destination);
        else if( [m_Dragging.draggingPasteboard.types containsObject:URLs_UTI()] )
            std::tie(operation, valid_items) = ScanURLsSource(ExtractURLs(m_Dragging.draggingPasteboard),
                                                         destination);
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
    
    UpdateValidDropNumber( m_Dragging, valid_items, operation );
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
                                                         const VFSPath& _dest) const
{
    const auto valid_items = (int)_source.items.size();
    NSDragOperation operation = NSDragOperationNone;
    if( _source.sourceController == m_Target && !m_DraggingOverDirectory )
        operation = NSDragOperationNone; // we can't drag into the same dir on the same panel
    else
        operation = BuildOperationForLocal(_source, _dest);
    
    // check that we dont drag an item to the same folder in other panel
    if( operation != NSDragOperationNone ) {
        const auto same_folder = any_of( begin(_source.items), end(_source.items), [&](auto &_i) {
            return _i.item.Directory() == _dest.Path() && _i.item.Host() == _dest.Host();
        });
        if( same_folder)
            operation = NSDragOperationNone;
    }

    // check that we dont drag a folder into itself
    if( operation != NSDragOperationNone && m_DraggingOverDirectory ) {
        // filenames are stored without trailing slashes, so have to add it
        for( const auto &item: _source.items )
            if( item.item.Host() == _dest.Host() &&
               item.item.IsDir() &&
               _dest.Path() == item.item.Path()+"/" ) {
                operation = NSDragOperationNone;
                break;
            }
    }
    
    return {operation, valid_items};
}

std::pair<NSDragOperation, int> DragReceiver::ScanURLsSource(NSArray<NSURL*> *_urls,
                                                        const VFSPath& _destination) const
{
    if( !_urls )
        return {NSDragOperationNone, 0};
    
    const auto valid_items = (int)_urls.count;
    NSDragOperation operation = BuildOperationForURLs(_urls, _destination);

    if( operation != NSDragOperationNone &&
        _destination.Host()->IsNativeFS() ) {
        for( NSURL* url in _urls )
            if( _destination.Path() == url.fileSystemRepresentation + "/"s ) {
                operation = NSDragOperationNone;
                break;
            }
    }

    return {operation, valid_items};
}

std::pair<NSDragOperation, int> DragReceiver::ScanURLsPromiseSource(const VFSPath& _dest) const
{
    if( !_dest.Host()->IsNativeFS() )
        return {NSDragOperationNone, 0};

    const auto valid_items = CountItemsWithType(m_Dragging, URLs_Promise_UTI());
    NSDragOperation operation = NSDragOperationCopy;
    
    return {operation, valid_items};
}

VFSPath DragReceiver::ComposeDestination() const
{
    if( m_DraggingOverDirectory ) {
        if( m_ItemUnderDrag.IsDotDot() ) {
            if( !m_Target.isUniform )
                return {};
            boost::filesystem::path p = m_Target.currentDirectoryPath;
            p.remove_filename();
            if( p.empty() )
                p = "/";
            return {m_Target.vfs, (p.parent_path() / "/").native()};
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
                                                     const VFSPath &_destination ) const
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
            const auto &fs_man = utility::NativeFSManager::Instance();
            const auto v1 = fs_man.VolumeFromPathFast( _destination.Path() );
            const auto v2 = fs_man.VolumeFromPathFast( _source.items.front().item.Directory() );
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

NSDragOperation DragReceiver::BuildOperationForURLs(NSArray<NSURL*> *_source,
                                                    const VFSPath &_destination ) const
{
    if( _source.count == 0 || !_destination)
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
            const auto &fs_man = utility::NativeFSManager::Instance();
            const auto v1 = fs_man.VolumeFromPathFast( _destination.Path() );
            const auto v2 = fs_man.VolumeFromPathFast(_source.firstObject.fileSystemRepresentation);
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

bool DragReceiver::PerformWithLocalSource(FilesDraggingSource *_source,
                                          const VFSPath& _destination)
{
    const auto files = ExtractListingItems(_source);
    if( files.empty() )
        return false;
    
    const auto operation = BuildOperationForLocal(_source, _destination);
    if( operation == NSDragOperationCopy ) {
        const auto opts = MakeDefaultFileCopyOptions();
        const auto op = std::make_shared<ops::Copying>(std::move(files),
                                                       _destination.Path(),
                                                       _destination.Host(),
                                                       opts);
        AddPanelRefreshIfNecessary(m_Target, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    else if( operation == NSDragOperationMove ) {
        const auto opts = MakeDefaultFileMoveOptions();
        const auto op = std::make_shared<ops::Copying>(std::move(files),
                                                       _destination.Path(),
                                                       _destination.Host(),
                                                       opts);
        AddPanelRefreshIfNecessary(m_Target, _source.sourceController, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    else if( operation == NSDragOperationLink &&
            _source.areAllHostsNative &&
            _destination.Host()->IsNativeFS() ) {
        for( const auto &file: files ) {
            const auto source_path = file.Path();
            const auto dest_path = (boost::filesystem::path(_destination.Path()) /
                                    file.Filename()).native();
            const auto op = std::make_shared<nc::ops::Linkage>(dest_path,
                                                               source_path,
                                                               _destination.Host(),
                                                               nc::ops::LinkageType::CreateSymlink);
            AddPanelRefreshIfNecessary(m_Target, *op);
            [m_Target.mainWindowController enqueueOperation:op];
        }
        return true;
    }
    return false;
}

bool DragReceiver::PerformWithURLsSource(NSArray<NSURL*> *_source,
                                         const VFSPath& _destination)
{
    if( !_source )
        return false;
    
    const auto operation = BuildOperationForURLs(_source, _destination);
    
    // currently fetching listings synchronously in main thread, which is BAAAD
    auto source_items = FetchDirectoriesItems(LayoutURLsByDirectories(_source),
                                              *VFSNativeHost::SharedHost());
    
    if( source_items.empty() )
        return false;
    
    if( operation == NSDragOperationCopy ) {
        const auto opts = MakeDefaultFileCopyOptions();
        const auto op = std::make_shared<nc::ops::Copying>(std::move(source_items),
                                                           _destination.Path(),
                                                           _destination.Host(),
                                                           opts);
        AddPanelRefreshIfNecessary(m_Target, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    if( operation == NSDragOperationMove ) {
        const auto opts = MakeDefaultFileMoveOptions();
        const auto op = std::make_shared<nc::ops::Copying>(std::move(source_items),
                                                           _destination.Path(),
                                                           _destination.Host(),
                                                           opts);
        AddPanelRefreshIfNecessary(m_Target, *op);
        [m_Target.mainWindowController enqueueOperation:op];
        return true;
    }
    if( operation == NSDragOperationLink ) {
        for( const auto &file: source_items ) {
            const auto source_path = file.Path();
            const auto dest_path = (boost::filesystem::path(_destination.Path()) /
                                    file.Filename()).native();
            const auto op = std::make_shared<nc::ops::Linkage>(dest_path,
                                                               source_path,
                                                               _destination.Host(),
                                                               nc::ops::LinkageType::CreateSymlink);
            AddPanelRefreshIfNecessary(m_Target, *op);
            [m_Target.mainWindowController enqueueOperation:op];
        }
        return true;
    }
    return false;
}

bool DragReceiver::PerformWithURLsPromiseSource(const VFSPath& _dest)
{
    const auto drop_url = [NSURL fileURLWithFileSystemRepresentation:_dest.Path().c_str()
                                                         isDirectory:true
                                                       relativeToURL:nil];
    [m_Dragging namesOfPromisedFilesDroppedAtDestination:drop_url];
    return true;
}

NSArray<NSString*> *DragReceiver::AcceptedUTIs()
{
    // why don't we support filenames pasteboard?
    static const auto utis = @[FilesDraggingSource.fileURLsPromiseDragUTI,
                               FilesDraggingSource.fileURLsDragUTI,
                               FilesDraggingSource.privateDragUTI];
    return utis;
}

static void UpdateValidDropNumber( id <NSDraggingInfo> _dragging,
                                   int _valid_number,
                                   NSDragOperation _operation )
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

static bool DraggingIntoFoldersAllowed()
{
    static const auto path = "filePanel.general.allowDraggingIntoFolders";
    static const auto fetch = []{
        return GlobalConfig().GetBool( path );
    };
    static bool value = []{
        GlobalConfig().ObserveForever(path, []{ value = fetch(); });
        return fetch();
    }();
    return value;
}

[[maybe_unused]] static void PrintDragOperations(NSDragOperation _op)
{
    if( _op == NSDragOperationNone ) {
        std::cout << "NSDragOperationNone" << std::endl;
    }
    else if( _op == NSDragOperationEvery ) {
        std::cout << "NSDragOperationEvery" << std::endl;
    }
    else {
        if( _op & NSDragOperationCopy )     std::cout << "NSDragOperationCopy ";
        if( _op & NSDragOperationLink )     std::cout << "NSDragOperationLink ";
        if( _op & NSDragOperationGeneric )  std::cout << "NSDragOperationGeneric ";
        if( _op & NSDragOperationPrivate )  std::cout << "NSDragOperationPrivate ";
        if( _op & NSDragOperationMove )     std::cout << "NSDragOperationMove ";
        if( _op & NSDragOperationDelete )   std::cout << "NSDragOperationDelete ";
        std::cout << std::endl;
    }
}

static std::vector<VFSListingItem> ExtractListingItems(FilesDraggingSource *_source)
{
    std::vector<VFSListingItem> files;
    for( PanelDraggingItem *item: _source.items )
        files.emplace_back( item.item );
    return files;
}

static NSArray<NSURL*> *ExtractURLs(NSPasteboard *_source)
{
    static const auto read_opts = @{NSPasteboardURLReadingFileURLsOnlyKey:@YES};
    static const auto classes = @[NSURL.class];
    return [_source readObjectsForClasses:classes
                                  options:read_opts];
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

static std::map<std::string, std::vector<std::string>>
    LayoutURLsByDirectories(NSArray<NSURL*> *_file_urls)
{
    if(!_file_urls)
        return {};
    std::map<std::string, std::vector<std::string>> files; // directory/ -> [filename1, filename2, ...]
    for(NSURL *url in _file_urls) {
        if( !objc_cast<NSURL>(url) ) continue; // guard agains malformed input data
        boost::filesystem::path source_path = url.path.fileSystemRepresentation;
        std::string root = source_path.parent_path().native() + "/";
        files[root].emplace_back(source_path.filename().native());
    }
    return files;
}

static std::vector<VFSListingItem> FetchDirectoriesItems
    (const std::map<std::string, std::vector<std::string>>& _input, VFSHost& _host)
{
    std::vector<VFSListingItem> source_items;
    for( const auto &dir: _input ) {
        std::vector<VFSListingItem> items_for_dir;
        const auto rc = _host.FetchFlexibleListingItems(dir.first,
                                                        dir.second,
                                                        0,
                                                        items_for_dir,
                                                        nullptr);
        if( rc == VFSError::Ok )
            move( begin(items_for_dir), end(items_for_dir), back_inserter(source_items) );
    }
    return source_items;
}

static void AddPanelRefreshIfNecessary(PanelController *_target,
                                       ops::Operation &_operation)
{
    const bool force_refresh = !_target.receivesUpdateNotifications;
    if( force_refresh ) {
        __weak PanelController *cntr = _target;
        _operation.ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
            dispatch_to_main_queue([cntr]{
                if(PanelController *pc = cntr)
                    [pc refreshPanel];
            });
        });
    }
}

static void AddPanelRefreshIfNecessary(PanelController *_target,
                                       PanelController *_source,
                                       ops::Operation &_operation)
{
    AddPanelRefreshIfNecessary(_target, _operation);
    AddPanelRefreshIfNecessary(_source, _operation);
}

static int CountItemsWithType( id<NSDraggingInfo> _sender, NSString *_type )
{
    static const auto classes = @[NSPasteboardItem.class];
    static const auto options = @{};
    __block int amount = 0;
    const auto block = ^(NSDraggingItem *draggingItem, NSInteger, BOOL *) {
        if( const auto i = objc_cast<NSPasteboardItem>(draggingItem.item) )
            if( [i.types containsObject:_type] )
                amount++;
    };
    [_sender enumerateDraggingItemsWithOptions:0
                                       forView:nil
                                       classes:classes
                                 searchOptions:options
                                    usingBlock:block];
    return amount;
}

}
