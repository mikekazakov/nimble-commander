//
//  BigFileViewHistory.m
//  Files
//
//  Created by Michael G. Kazakov on 29.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "BigFileViewHistory.h"
#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "Encodings.h"
#import "DispatchQueue.h"

static NSString *g_FileName = @"/bigfileviewhistory.bplist"; // bplist file name
static NSString *g_PathArchiveKey = @"path";
static NSString *g_PositionArchiveKey = @"position";
static NSString *g_LastViewedArchiveKey = @"lastviewed";
static NSString *g_WrappingArchiveKey = @"wrapping";
static NSString *g_ViewModeArchiveKey = @"viewmode";
static NSString *g_EncodingArchiveKey = @"encoding";
static NSString *g_SelPosArchiveKey = @"sel_position";
static NSString *g_SelLenArchiveKey = @"sel_length";
static BigFileViewHistory *g_SharedInstance = nil;
static const auto g_MaximumEntries = 256;

static NSString* StorageFileName()
{
    return [NSFileManager.defaultManager.applicationSupportDirectory stringByAppendingString:g_FileName];
}

@implementation BigFileViewHistoryEntry

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        path = [decoder decodeObjectForKey:g_PathArchiveKey];

        if([decoder containsValueForKey:g_PositionArchiveKey])
            position = [decoder decodeInt64ForKey:g_PositionArchiveKey];
        else
            position = 0;
        
        if([decoder containsValueForKey:g_LastViewedArchiveKey])
            last_viewed = [decoder decodeObjectForKey:g_LastViewedArchiveKey];
        else
            last_viewed = [NSDate distantPast];
        
        if([decoder containsValueForKey:g_WrappingArchiveKey])
            wrapping = [decoder decodeBoolForKey:g_WrappingArchiveKey];
        else
            wrapping = true;
        
        if([decoder containsValueForKey:g_ViewModeArchiveKey])
        {
            int mode = [decoder decodeIntForKey:g_ViewModeArchiveKey];
            if(mode == static_cast<int>(BigFileViewModes::Text))
                view_mode = BigFileViewModes::Text;
            else
                view_mode = BigFileViewModes::Hex;
        }
        else
            view_mode = BigFileViewModes::Text;
        
        if([decoder containsValueForKey:g_EncodingArchiveKey])
            encoding = encodings::EncodingFromName(
                                                   [(NSString*)[decoder decodeObjectForKey:g_EncodingArchiveKey]
                                                    UTF8String]
                                                   );
        else
            encoding = encodings::ENCODING_INVALID;
        
        if([decoder containsValueForKey:g_SelPosArchiveKey] &&
           [decoder containsValueForKey:g_SelLenArchiveKey] )
            selection = CFRangeMake([decoder decodeInt64ForKey:g_SelPosArchiveKey],
                                    [decoder decodeInt64ForKey:g_SelLenArchiveKey]);
        else
            selection = CFRangeMake(-1, 0);
            
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:path forKey:g_PathArchiveKey];
    [encoder encodeInt64:position forKey:g_PositionArchiveKey];
    [encoder encodeObject:last_viewed forKey:g_LastViewedArchiveKey];
    [encoder encodeBool:wrapping forKey:g_WrappingArchiveKey];
    [encoder encodeInt:static_cast<int>(view_mode) forKey:g_ViewModeArchiveKey];
    [encoder encodeObject:[NSString stringWithUTF8String:encodings::NameFromEncoding(encoding)] forKey:g_EncodingArchiveKey];
    [encoder encodeInt64:selection.location forKey:g_SelPosArchiveKey];
    [encoder encodeInt64:selection.length forKey:g_SelLenArchiveKey];
}

@end


@implementation BigFileViewHistory
{
    NSMutableArray *m_History;
    bool            m_IsDirty;
    SerialQueue     m_Queue;
}

- (id) init
{
    self = [super init];
    if(self == nil)
        return self;
    
    m_Queue = SerialQueueT::Make();
    
    // try to load history from file
    m_History = [[NSKeyedUnarchiver unarchiveObjectWithFile:StorageFileName()] mutableCopy];
        
    if(!m_History)
        m_History = [NSMutableArray new]; // failed to load it - ok, just create a new one
    
    m_IsDirty = false;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(OnTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:[NSApplication sharedApplication]];
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (BigFileViewHistory*) sharedHistory
{
    static once_flag once;
    call_once(once, []{
        g_SharedInstance = [BigFileViewHistory new];
    });
    
    return g_SharedInstance;
}

- (void)OnTerminate:(NSNotification *)note
{
    m_Queue->Wait();
    if(m_IsDirty)
        [NSKeyedArchiver archiveRootObject:m_History toFile:StorageFileName()];
}

- (BigFileViewHistoryEntry*) FindEntryByPath: (NSString *)_path
{
    if(_path == nil)
        return nil;
    for(BigFileViewHistoryEntry *e in m_History)
        if(e->path != nil &&
           [e->path compare:_path] == NSOrderedSame)
            return e;
    return nil;
}

- (void) InsertEntry:(BigFileViewHistoryEntry*) _entry
{
    assert(_entry);
    assert(_entry->last_viewed);
    assert(_entry->path);
    m_Queue->Run([=]{
        m_IsDirty = true;
        for(BigFileViewHistoryEntry *e in m_History)
            if(e->path != nil &&
               [e->path compare:_entry->path] == NSOrderedSame)
            {
                [m_History removeObject:e];
                break;
            }
        [m_History insertObject:_entry atIndex:0];
  
        if( m_History.count > g_MaximumEntries )
            [m_History removeObjectsInRange:NSMakeRange(g_MaximumEntries, m_History.count - g_MaximumEntries)];
    });
}

+ (BigFileViewHistoryOptions) HistoryOptions
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BigFileViewHistoryOptions options;
    options.encoding    = [defaults boolForKey:@"BigFileViewDoSaveFileEncoding"];
    options.mode        = [defaults boolForKey:@"BigFileViewDoSaveFileMode"];
    options.position    = [defaults boolForKey:@"BigFileViewDoSaveFilePosition"];
    options.wrapping    = [defaults boolForKey:@"BigFileViewDoSaveFileWrapping"];
    options.selection   = [defaults boolForKey:@"BigFileViewDoSaveFileSelection"];
    return options;
}

+ (bool) HistoryEnabled
{
    BigFileViewHistoryOptions options = [BigFileViewHistory HistoryOptions];
    return options.encoding || options.mode || options.position || options.wrapping || options.selection;
}

+ (bool) DeleteHistory
{
    if(g_SharedInstance != nil)
        g_SharedInstance->m_Queue->Run([]{
            g_SharedInstance->m_History = [NSMutableArray new];
            g_SharedInstance->m_IsDirty = false;
        });
    
    bool result = [[NSFileManager defaultManager] removeItemAtPath:StorageFileName() error:nil];;
    return result;
}

@end
