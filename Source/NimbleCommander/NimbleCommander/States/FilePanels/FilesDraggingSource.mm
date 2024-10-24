// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FilesDraggingSource.h"
#include <VFS/Native.h>
#include <Utility/StringExtras.h>
#include <Operations/Deletion.h>
#include <Operations/Copying.h>
#include <Base/dispatch_cpp.h>
#include "PanelController.h"
#include "MainWindowFilePanelState.h"
#include "../MainWindowController.h"

static const auto g_PrivateDragUTI = @"com.magnumbytes.nimblecommander.filespanelsdraganddrop";

// "com.apple.pasteboard.promised-file-url"
static const auto g_PasteboardFileURLPromiseUTI = static_cast<NSString *>(kPasteboardTypeFileURLPromise);

// "public.file-url"
static const auto g_PasteboardFileURLUTI = static_cast<NSString *>(kUTTypeFileURL);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static const auto g_PasteboardFilenamesUTI = static_cast<NSString *>(
    CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType,
                                                            (__bridge CFStringRef)NSFilenamesPboardType,
                                                            kUTTypeData)));
#pragma clang diagnostic pop

@implementation PanelDraggingItem {
    VFSListingItem m_Item;
}
@synthesize item = m_Item;
@synthesize icon;

- (PanelDraggingItem *)initWithItem:(const VFSListingItem &)_item
{
    self = [super init];
    if( self ) {
        m_Item = _item;

        // for File URL Promise. need to check if this is necessary
        [self setString:static_cast<NSString *>(kUTTypeData)
                forType:static_cast<NSString *>(kPasteboardTypeFilePromiseContent)];
    }
    return self;
}

- (void)reset
{
    m_Item = VFSListingItem();
}

@end

@implementation FilesDraggingSource {
    std::vector<PanelDraggingItem *> m_Items;
    __weak PanelController *m_SourceController;
    VFSHostPtr m_CommonHost;
    bool m_AreAllHostsWriteable;
    bool m_AreAllHostsNative;
    VFSHostPtr m_NativeVFS;
}

@synthesize areAllHostsWriteable = m_AreAllHostsWriteable;
@synthesize areAllHostsNative = m_AreAllHostsNative;
@synthesize commonHost = m_CommonHost;
@synthesize items = m_Items;
@synthesize sourceController = m_SourceController;

+ (NSString *)privateDragUTI
{
    return g_PrivateDragUTI;
}
+ (NSString *)fileURLsPromiseDragUTI
{
    return g_PasteboardFileURLPromiseUTI;
}
+ (NSString *)fileURLsDragUTI
{
    return g_PasteboardFileURLUTI;
}
+ (NSString *)filenamesPBoardDragUTI
{
    return g_PasteboardFilenamesUTI;
}

- (FilesDraggingSource *)initWithSourceController:(PanelController *)_controller
                                       nativeHost:(nc::vfs::NativeHost &)_native_vfs
{
    self = [super init];
    if( self ) {
        m_SourceController = _controller;
        m_AreAllHostsWriteable = false;
        m_AreAllHostsNative = false;
        m_NativeVFS = _native_vfs.SharedPtr();
    }
    return self;
}

- (void)addItem:(PanelDraggingItem *)_item
{
    if( m_Items.empty() ) {
        m_CommonHost = _item.item.Host();
        m_AreAllHostsNative = m_CommonHost->IsNativeFS();
        m_AreAllHostsWriteable = m_CommonHost->IsWritable();
    }
    else {
        if( m_CommonHost && _item.item.Host() != m_CommonHost )
            m_CommonHost = nullptr;
        if( m_AreAllHostsNative && !_item.item.Host()->IsNativeFS() )
            m_AreAllHostsNative = false;
        if( m_AreAllHostsWriteable && !_item.item.Host()->IsWritable() )
            m_AreAllHostsWriteable = false;
    }

    m_Items.emplace_back(_item);
}

- (NSDragOperation)draggingSession:(NSDraggingSession *) [[maybe_unused]] _session
    sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch( context ) {
        case NSDraggingContextOutsideApplication:
            if( m_AreAllHostsNative && m_AreAllHostsWriteable )
                return NSDragOperationCopy | NSDragOperationLink | NSDragOperationGeneric | NSDragOperationMove |
                       NSDragOperationDelete;
            else
                return NSDragOperationCopy;

        case NSDraggingContextWithinApplication:
            if( m_AreAllHostsNative )
                return NSDragOperationCopy | NSDragOperationLink | NSDragOperationGeneric | NSDragOperationMove;
            else
                return NSDragOperationCopy | NSDragOperationGeneric | NSDragOperationMove;

        default:
            return NSDragOperationNone;
    }
}

// g_PasteboardFilenamesUTI - NSFilenamesPboardType as UTI
//- (void)provideFilenamesPasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item
//{
//    if( !m_FilenamesPasteboard )
//        return;
//
//    m_FilenameURLsPasteboard = false;
//    m_FilenamesPasteboard = false;
//    m_URLsPromisePasteboard = false;
//
//    cout << "provideFilenamesPasteboard" << endl;
//
//    NSMutableArray *ar = [NSMutableArray new];
//    for( auto &i: m_Items )
//        if( i.item.Host()->IsNativeFS() ) {
//            auto url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:i.item.Path()]];
//            [ar addObject:url];
//        }
//    [sender writeObjects:ar];
// }

static NSURL *ExtractPromiseDropLocation(NSPasteboard *_pasteboard)
{
    NSURL *result = nil;
    PasteboardRef pboardRef = nullptr;
    PasteboardCreate((__bridge CFStringRef)_pasteboard.name, &pboardRef);
    if( pboardRef ) {
        PasteboardSynchronize(pboardRef);
        CFURLRef urlRef = nullptr;
        PasteboardCopyPasteLocation(pboardRef, &urlRef);
        if( urlRef )
            result = static_cast<NSURL *>(CFBridgingRelease(urlRef));
        CFRelease(pboardRef);
    }
    return result;
}

// g_PasteboardFileURLPromiseUTI - kPasteboardTypeFileURLPromise
// "com.apple.pasteboard.promised-file-url"
- (void)provideURLPromisePasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item
{
    auto drop_url = ExtractPromiseDropLocation(sender);
    if( drop_url == nil )
        return;

    nc::ops::CopyingOptions opts;
    opts.docopy = true;
    opts.copy_file_times = true;
    opts.copy_unix_flags = true;
    opts.copy_unix_owners = true;
    opts.preserve_symlinks = true;
    opts.exist_behavior = nc::ops::CopyingOptions::ExistBehavior::Stop;

    const auto dest = std::filesystem::path(drop_url.path.fileSystemRepresentation) / item.item.Filename();

    auto operation =
        std::make_shared<nc::ops::Copying>(std::vector<VFSListingItem>{item.item}, dest, m_NativeVFS, opts);

    operation->Start();
    operation->Wait();
    const bool success = operation->State() == nc::ops::OperationState::Completed;

    if( success ) {
        // write result url into pasteboard
        const auto url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:dest.c_str()]
                                    isDirectory:item.item.IsDir()
                                  relativeToURL:nil];
        if( url ) {
            // NB! keep this in dumb form!
            // [url writeToPasteboard:sender] doesn't work.
            [sender writeObjects:@[url]];
        }
    }
}

// From Apple's doc:
//    The recommended approach for writing URLs to the pasteboard is as follows:
//    NSArray *arrayOfURLs; // assume this exists
//    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard]; // get pasteboard
//    [pasteboard clearContents]; // clear pasteboard to take ownership
//    [pasteboard writeObjects:arrayOfURLs]; // write the URLs
- (void)writeURLsPBoard:(NSPasteboard *)_sender
{
    NSMutableArray *urls = [NSMutableArray new];
    for( auto &i : m_Items )
        if( i.item.Host()->IsNativeFS() ) {
            auto url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:i.item.Path()]];
            [urls addObject:url];
        }

    if( urls.count ) {
        [_sender clearContents];     // clear pasteboard to take ownership
        [_sender writeObjects:urls]; // clear pasteboard to take ownership
    }
}

// g_PasteboardFileURLUTI - kUTTypeFileURL
// "public.file-url"
//- (void)provideFilenamesURLsPasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item
//{
//    if( !m_FilenameURLsPasteboard )
//        return;
//
//    m_FilenamesPasteboard = false;
//
//    if( item.item.Host()->IsNativeFS() ) {
//        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:item.item.Path()]];
//        [url writeToPasteboard:sender];
//    }
//}

// dispatch incoming data request
- (void)pasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item provideDataForType:(NSString *)type
{
    if( !item.item )
        return;

    //    else if( [type isEqualToString:g_PasteboardFilenamesUTI] )
    //        [self provideFilenamesPasteboard:sender item:item];
    if( [type isEqualToString:g_PasteboardFileURLPromiseUTI] )
        [self provideURLPromisePasteboard:sender item:item];
    //    else if( [type isEqualToString:g_PasteboardFileURLUTI] )
    //        [self provideFilenamesURLsPasteboard:sender item:item];
}

- (void)draggingSession:(NSDraggingSession *) [[maybe_unused]] session
           endedAtPoint:(NSPoint) [[maybe_unused]] screenPoint
              operation:(NSDragOperation)operation
{
    if( operation == NSDragOperationDelete ) {
        [self deleteSoureItems];
    }

    for( auto &item : m_Items )
        [item reset];

    m_Items.clear();
    m_CommonHost = nullptr;
}

static void AddPanelRefreshEpilogIfNeeded(PanelController *_target, nc::ops::Operation &_operation)
{
    __weak PanelController *weak_panel = _target;
    _operation.ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=] {
        dispatch_to_main_queue([=] {
            if( PanelController *const strong_pc = weak_panel )
                [strong_pc hintAboutFilesystemChange];
        });
    });
}

- (void)deleteSoureItems
{
    if( PanelController *target = m_SourceController ) {
        std::vector<VFSListingItem> items;
        for( auto &i : m_Items )
            items.push_back(i.item);

        const auto operation = std::make_shared<nc::ops::Deletion>(items, nc::ops::DeletionType::Trash);

        AddPanelRefreshEpilogIfNeeded(target, *operation);
        [target.mainWindowController enqueueOperation:operation];
    }
}

@end
