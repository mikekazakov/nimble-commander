#include "VFSNetDropboxFileUploadStream.h"

@implementation VFSNetDropboxFileUploadStream
{
    NSStreamStatus m_Status;
    bool           m_EOF;    
    
    mutex m_CallbacksLock;
    function<ssize_t(uint8_t *_buffer, size_t _sz)> m_FeedData;
    function<bool()> m_HasDataToFeed;
    
//    NSMutableDictionary    *m_Properties;
    __weak id<NSStreamDelegate> m_Delegate;
    NSRunLoop              *m_RunLoop;
    NSRunLoopMode           m_RunLoopMode;
    
    // +mutex
    deque<NSStreamEvent>   m_PendingEvents;
}

- (NSStreamStatus) streamStatus
{
    cout << "told stream status: " << m_Status << endl;
    return m_Status;
}

- (void)open
{
    cout << "open" << endl;
    m_Status = NSStreamStatusOpen;
    
    [self enqueueStreamEvent:NSStreamEventOpenCompleted];
    
    if( m_EOF )
//        m_Status = NSStreamStatusAtEnd;
        [self enqueueStreamEvent:NSStreamEventEndEncountered];
}

- (void)close
{
    cout << "close" << endl;
    m_Status = NSStreamStatusClosed;
}

- (nullable id)propertyForKey:(NSStreamPropertyKey)key
{
    NSLog(@"property for key %@", key);
    return nil;
}

- (BOOL)setProperty:(nullable id)property forKey:(NSStreamPropertyKey)key
{
    NSLog(@"set property %@=%@", key, property);
    return true;
}

- (void) setDelegate:(id<NSStreamDelegate>)delegate
{
    m_Delegate = delegate;
}

- (BOOL)getBuffer:(uint8_t * _Nullable * _Nonnull)buffer length:(NSUInteger *)len
{
    return false;
}

- (BOOL) hasBytesAvailable
{
    cout << "hasBytesAvailable called from " << this_thread::get_id() << endl;
    LOCK_GUARD(m_CallbacksLock) {
        if( m_HasDataToFeed )
            return m_HasDataToFeed();
    }
    return false;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    LOCK_GUARD(m_CallbacksLock) {
        if( m_FeedData ) {
            auto rc = m_FeedData(buffer, len);
            if( rc >= 0 )
                return rc;
        }
    }
    return -1;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode
{
    m_RunLoop = aRunLoop;
    m_RunLoopMode = mode;
    
    
    if( !m_PendingEvents.empty() )
        [m_RunLoop performSelector:@selector(drainPendingEvent)
                            target:self
                          argument:nil
                             order:0
                             modes:@[m_RunLoopMode]];
    
//    int a = 10;
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {}

- (void)enqueueStreamEvent:(NSStreamEvent)_event
{
    m_PendingEvents.emplace_back(_event);

    if( m_RunLoop )
        [m_RunLoop performSelector:@selector(drainPendingEvent)
                            target:self
                          argument:nil
                             order:0
                             modes:@[m_RunLoopMode]];
}

- (void)drainPendingEvent
{
    cout << "drainPendingEvent called from " << this_thread::get_id() << endl;

    if( m_PendingEvents.empty() )
        return;
    
    auto ev = m_PendingEvents.front();
    m_PendingEvents.pop_front();
    
    if( ev == NSStreamEventEndEncountered ) {
    
//    NSStreamStatusNotOpen = 0,
//    NSStreamStatusOpening = 1,
    
//    NSStreamStatusReading = 3,
//    NSStreamStatusWriting = 4,
//    NSStreamStatusAtEnd = 5,
//    NSStreamStatusClosed = 6,
//    NSStreamStatusError = 7
    
    
        if( m_Status == NSStreamStatusNotOpen || m_Status == NSStreamStatusOpening ) {
            m_EOF = true;
        }
        else if( m_Status == NSStreamStatusOpen || NSStreamStatusReading ) {
            m_Status = NSStreamStatusAtEnd;
        
            cout << "told connection about NSStreamEventEndEncountered" << endl;
            if( [m_Delegate respondsToSelector:@selector(stream:handleEvent:)] )
                [m_Delegate stream:self handleEvent:ev];
        }
    
//    NSStreamStatusOpen = 2,
//    NSStreamStatusReading = 3,
//        m_Status =  NSStreamStatusAtEnd;
        

    }
    
    if( ev == NSStreamEventHasBytesAvailable  ) {
        cout << "told connection about NSStreamEventHasBytesAvailable" << endl;
        if( [m_Delegate respondsToSelector:@selector(stream:handleEvent:)] )
            [m_Delegate stream:self handleEvent:ev];
    }

    // drain other events if any
    if( !m_PendingEvents.empty() )
        [m_RunLoop performSelector:@selector(drainPendingEvent)
                            target:self
                          argument:nil
                             order:0
                             modes:@[m_RunLoopMode]];
}

- (void) setFeedData:(function<ssize_t (uint8_t *, size_t)>)feedData
{
    LOCK_GUARD(m_CallbacksLock) {
        m_FeedData = move(feedData);
    }
}

- (function<ssize_t(uint8_t *_buffer, size_t _sz)>) feedData
{
    LOCK_GUARD(m_CallbacksLock) {
        return m_FeedData;
    }
    return nullptr;
}

- (void) setHasDataToFeed:(function<bool()>)hasDataToFeed
{
    LOCK_GUARD(m_CallbacksLock) {
        m_HasDataToFeed = move(hasDataToFeed);
    }
}

- (function<bool()>) hasDataToFeed
{
    LOCK_GUARD(m_CallbacksLock) {
        return m_HasDataToFeed;
    }
    return nullptr;
}

- (void)notifyAboutNewData
{
    [self enqueueStreamEvent:NSStreamEventHasBytesAvailable];
}

- (void)notifyAboutDataEnd
{
    [self enqueueStreamEvent:NSStreamEventEndEncountered];
}

@end
