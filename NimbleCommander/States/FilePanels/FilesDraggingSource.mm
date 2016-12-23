#include <VFS/Native.h>
#include "FilesDraggingSource.h"

static NSString *g_PrivateDragUTI = @"com.magnumbytes.nimblecommander.filespanelsdraganddrop";
static NSString *g_PasteboardFileURLPromiseUTI = (NSString *)kPasteboardTypeFileURLPromise;
static NSString *g_PasteboardFileURLUTI = (NSString *)kUTTypeFileURL;
static NSString *g_PasteboardFilenamesUTI = (NSString*)CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType, (__bridge CFStringRef)NSFilenamesPboardType, kUTTypeData));

@implementation PanelDraggingItem
{
    VFSListingItem m_Item;
}
@synthesize item = m_Item;

- (PanelDraggingItem*) initWithItem:(const VFSListingItem&)_item
{
    self = [super init];
    if( self ) {
        m_Item = _item;

        // for File URL Promise. need to check if this is necessary
        [self setString:(NSString*)kUTTypeData forType:(NSString *)kPasteboardTypeFilePromiseContent];
    }
    return self;
}

- (void) reset
{
    m_Item = VFSListingItem();
}

@end


@implementation FilesDraggingSource
{
    vector<PanelDraggingItem*>  m_Items;
    __weak PanelController*     m_SourceController;
    VFSHostPtr                  m_CommonHost;
    bool                        m_AreAllHostsWriteable;
    bool                        m_AreAllHostsNative;
    bool                        m_FilenameURLsPasteboard;
    bool                        m_FilenamesPasteboard;
    bool                        m_URLsPromisePasteboard;
}

@synthesize areAllHostsWriteable = m_AreAllHostsWriteable;
@synthesize areAllHostsNative = m_AreAllHostsNative;
@synthesize commonHost = m_CommonHost;
@synthesize items = m_Items;
@synthesize sourceController = m_SourceController;

+ (NSString*) privateDragUTI            { return g_PrivateDragUTI;              }
+ (NSString*) fileURLsPromiseDragUTI    { return g_PasteboardFileURLPromiseUTI; }
+ (NSString*) fileURLsDragUTI           { return g_PasteboardFileURLUTI;        }
+ (NSString*) filenamesPBoardDragUTI    { return g_PasteboardFilenamesUTI;      }

- (FilesDraggingSource*) initWithSourceController:(PanelController*)_controller;
{
    self = [super init];
    if(self) {
        m_SourceController = _controller;
        m_FilenameURLsPasteboard = m_FilenamesPasteboard = m_URLsPromisePasteboard = true;
        m_AreAllHostsWriteable = false;
        m_AreAllHostsNative = false;
    }
    return self;
}

- (void)addItem:(PanelDraggingItem*)_item
{
    if( m_Items.empty() ) {
        m_CommonHost = _item.item.Host();
        m_AreAllHostsNative = m_CommonHost->IsNativeFS();
        m_AreAllHostsWriteable = m_CommonHost->IsWriteable();
    }
    else {
        if( m_CommonHost && _item.item.Host() != m_CommonHost )
            m_CommonHost = nullptr;
        if( m_AreAllHostsNative && !_item.item.Host()->IsNativeFS() )
            m_AreAllHostsNative = false;
        if( m_AreAllHostsWriteable && !_item.item.Host()->IsWriteable() )
            m_AreAllHostsWriteable = false;
    }
    
    m_Items.emplace_back(_item);
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch(context) {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationCopy|NSDragOperationGeneric;
            break;
            
        case NSDraggingContextWithinApplication:
            // ||!! actually this mask is not used by the receiver !!||
            // need some complex logic here later
            
            if( m_Items.size() > 1 || !m_AreAllHostsNative )
                return NSDragOperationCopy|NSDragOperationMove;
            
            return NSDragOperationCopy|NSDragOperationLink|NSDragOperationMove;
            
        default:
            return NSDragOperationNone;
    }
}

// g_PasteboardFilenamesUTI - NSFilenamesPboardType as UTI
- (void)provideFilenamesPasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item
{
    if( !m_FilenamesPasteboard )
        return;
    
    m_FilenameURLsPasteboard = false;
    m_FilenamesPasteboard = false;
    m_URLsPromisePasteboard = false;
    
    cout << "provideFilenamesPasteboard" << endl;
    
    NSMutableArray *ar = [NSMutableArray new];
    for( auto &i: m_Items )
        if( i.item.Host()->IsNativeFS() ) {
            auto url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:i.item.Path()]];
            [ar addObject:url];
        }
    [sender writeObjects:ar];
 }

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
            result = (NSURL*) CFBridgingRelease(urlRef);
        CFRelease(pboardRef);
    }
    return result;
}

// g_PasteboardFileURLPromiseUTI - kPasteboardTypeFileURLPromise
// "com.apple.pasteboard.promised-file-url"
- (void)provideURLPromisePasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item
{
    if( !m_URLsPromisePasteboard )
        return;
    
    m_FilenameURLsPasteboard    = false;
    m_FilenamesPasteboard       = false;
    m_URLsPromisePasteboard     = false;
  
    if( auto drop_url = ExtractPromiseDropLocation(sender) ) {
        NSMutableArray *ar = [NSMutableArray new];
        for(auto &i: m_Items) {
            path dest = path(drop_url.path.fileSystemRepresentation) / i.item.Filename();
            VFSEasyCopyNode(i.item.Path().c_str(), i.item.Host(),
                            dest.c_str(), VFSNativeHost::SharedHost());
            if( NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:dest.c_str()]
                                        isDirectory:i.item.IsDir()
                                      relativeToURL:nil] )
                [ar addObject:url];
        }
        [sender writeObjects:ar];
    }
}

// g_PasteboardFileURLUTI - kUTTypeFileURL
// "public.file-url"
- (void)provideFilenamesURLsPasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item
{
    if( !m_FilenameURLsPasteboard )
        return;
    
    m_FilenamesPasteboard = false;
    
    if( item.item.Host()->IsNativeFS() ) {
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:item.item.Path()]];
        [url writeToPasteboard:sender];
    }
}

// dispatch incoming data request
- (void)pasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item provideDataForType:(NSString *)type
{
    if( !item.item )
        return;
    else if( [type isEqualToString:g_PasteboardFilenamesUTI] )
        [self provideFilenamesPasteboard:sender item:item];
    else if ( [type isEqualToString:g_PasteboardFileURLPromiseUTI] )
        [self provideURLPromisePasteboard:sender item:item];
    else if( [type isEqualToString:g_PasteboardFileURLUTI] )
        [self provideFilenamesURLsPasteboard:sender item:item];
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    for( auto &item: m_Items )
        [item reset];
    
    m_Items.clear();
}

@end

