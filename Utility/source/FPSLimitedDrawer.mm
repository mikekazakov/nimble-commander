// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <atomic>
#include <Habanero/mach_time.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/FPSLimitedDrawer.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/NSTimer+Tolerance.h>

using namespace std;
using namespace std::chrono;

static const nanoseconds m_MaxTimeBeforeInvalidation = 1s;

@implementation FPSLimitedDrawer
{
    __weak NSView *m_View;
    unsigned       m_FPS;
    nanoseconds    m_LastDrawedTime;
    atomic_bool    m_Dirty;
    NSTimer       *m_DrawTimer;
}

- (id) initWithView:(NSView*)_view
{
    self = [super init];
    if(self) {
        assert(dispatch_is_main_queue());
        m_FPS = 60;
        m_Dirty = false;
        m_View = _view;
        m_LastDrawedTime = 0ns;
        [self setupTimer];
    }
    return self;
}

- (void) dealloc
{
    [self cleanupTimer];
}

- (unsigned) fps
{
    return m_FPS;
}

- (void) setFps:(unsigned)_fps
{
    assert(dispatch_is_main_queue());
    if(_fps == m_FPS)
        return;
    m_FPS = _fps;
    [self cleanupTimer];
    if(_fps > 0)
        [self setupTimer];
}

- (NSView*)view
{
    return (NSView*)m_View;
}

- (void) invalidate
{
    if(m_FPS > 0) {
        m_Dirty = true;
        if(m_DrawTimer == nil) {
            if(dispatch_is_main_queue())
                [self setupTimer];
            else
                dispatch_to_main_queue([=]{ [self setupTimer]; });
        }
    }
    else
        [self.view setNeedsDisplay];
}

- (void) UpdateByTimer:(NSTimer*)[[maybe_unused]]theTimer
{
    if(self.view) {
        if(m_Dirty) {
            self.view.needsDisplay = true;
            m_Dirty = false;
            m_LastDrawedTime = machtime();
        }
        else {
            // timer invalidation by max inactivity time
            if(machtime() - m_LastDrawedTime > m_MaxTimeBeforeInvalidation)
                [self cleanupTimer];
        }
    }
    else {
        [self cleanupTimer];
    }
}

- (void) setupTimer
{
    if(m_DrawTimer)
        return;
    m_DrawTimer = [NSTimer scheduledTimerWithTimeInterval:1./m_FPS
                                                   target:self
                                                 selector:@selector(UpdateByTimer:)
                                                 userInfo:nil
                                                  repeats:YES];
    [m_DrawTimer setDefaultTolerance];
    m_LastDrawedTime = machtime();
}

- (void) cleanupTimer
{
    assert(dispatch_is_main_queue());
    [m_DrawTimer invalidate];
    m_DrawTimer = nil;
}

@end
