// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FileUploadStream.h"
#include <mutex>
#include <deque>
#include <Base/spinlock.h>

@implementation NCVFSDropboxFileUploadStream {
    NSStreamStatus m_Status;
    bool m_EOF;

    std::mutex m_CallbacksLock;
    std::function<ssize_t(uint8_t *_buffer, size_t _sz)> m_FeedData;
    std::function<bool()> m_HasDataToFeed;

    __weak id<NSStreamDelegate> m_Delegate;
    NSRunLoop *m_RunLoop;
    NSRunLoopMode m_RunLoopMode;

    // +mutex
    std::deque<NSStreamEvent> m_PendingEvents;
}

- (NSStreamStatus)streamStatus
{
    return m_Status;
}

- (void)open
{
    m_Status = NSStreamStatusOpen;

    [self enqueueStreamEvent:NSStreamEventOpenCompleted];

    if( m_EOF )
        //        m_Status = NSStreamStatusAtEnd;
        [self enqueueStreamEvent:NSStreamEventEndEncountered];
}

- (void)close
{
    m_Status = NSStreamStatusClosed;
}

- (nullable id)propertyForKey:(NSStreamPropertyKey) [[maybe_unused]] _key
{
    return nil;
}

- (BOOL)setProperty:(nullable id) [[maybe_unused]] _property forKey:(NSStreamPropertyKey) [[maybe_unused]] _key
{
    return true;
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate
{
    m_Delegate = delegate;
}

- (BOOL)getBuffer:(uint8_t *_Nullable *_Nonnull) [[maybe_unused]] _buffer length:(NSUInteger *) [[maybe_unused]] _len
{
    return false;
}

- (BOOL)hasBytesAvailable
{
    const auto lock = std::lock_guard{m_CallbacksLock};
    if( m_HasDataToFeed )
        return m_HasDataToFeed();
    return false;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    const auto lock = std::lock_guard{m_CallbacksLock};
    if( m_FeedData ) {
        auto rc = m_FeedData(buffer, len);
        if( rc >= 0 )
            return rc;
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
}

- (void)removeFromRunLoop:(NSRunLoop *) [[maybe_unused]] _loop forMode:(NSRunLoopMode) [[maybe_unused]] _mode
{
}

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
    if( m_PendingEvents.empty() )
        return;

    auto ev = m_PendingEvents.front();
    m_PendingEvents.pop_front();

    if( ev == NSStreamEventEndEncountered ) {
        if( m_Status == NSStreamStatusNotOpen || m_Status == NSStreamStatusOpening ) {
            m_EOF = true;
        }
        else if( m_Status == NSStreamStatusOpen || m_Status == NSStreamStatusReading ) {
            m_Status = NSStreamStatusAtEnd;

            if( [m_Delegate respondsToSelector:@selector(stream:handleEvent:)] )
                [m_Delegate stream:self handleEvent:ev];
        }
    }

    if( ev == NSStreamEventHasBytesAvailable ) {
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

- (void)setFeedData:(std::function<ssize_t(uint8_t *, size_t)>)feedData
{
    const auto lock = std::lock_guard{m_CallbacksLock};
    m_FeedData = std::move(feedData);
}

- (std::function<ssize_t(uint8_t *_buffer, size_t _sz)>)feedData
{
    const auto lock = std::lock_guard{m_CallbacksLock};
    return m_FeedData;
}

- (void)setHasDataToFeed:(std::function<bool()>)hasDataToFeed
{
    const auto lock = std::lock_guard{m_CallbacksLock};
    m_HasDataToFeed = std::move(hasDataToFeed);
}

- (std::function<bool()>)hasDataToFeed
{
    const auto lock = std::lock_guard{m_CallbacksLock};
    return m_HasDataToFeed;
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
