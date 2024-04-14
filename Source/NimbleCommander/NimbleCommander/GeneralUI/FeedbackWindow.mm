// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Core/FeedbackManager.h"
#include "FeedbackWindow.h"
#include <chrono>
#include <Base/dispatch_cpp.h>
#include <Base/debug.h>

using namespace std::literals;

@interface FeedbackWindow ()
@property(nonatomic) IBOutlet NSTabView *tabView;

@end

@implementation FeedbackWindow {
    FeedbackWindow *m_Self;
    nc::FeedbackManager *m_FeedbackManager;
}

@synthesize rating;
@synthesize tabView;

- (instancetype)initWithFeedbackManager:(nc::FeedbackManager &)_fm
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_FeedbackManager = &_fm;
        self.rating = 1;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    m_Self = self;

    if( self.rating == 5 || self.rating == 4 ) {
        // positive branch
        if( nc::base::AmISandboxed() ) // i.e. for AppStore
            [self.tabView selectTabViewItemAtIndex:0];
        else
            [self.tabView selectTabViewItemAtIndex:1];
    }
    else if( self.rating == 3 || self.rating == 2 ) {
        // neutral branch
        [self.tabView selectTabViewItemAtIndex:2];
    }
    else {
        // negative branch
        [self.tabView selectTabViewItemAtIndex:3];
    }
}

- (void)windowWillClose:(NSNotification *) [[maybe_unused]] _notification
{
    dispatch_to_main_queue_after(10ms, [=] { m_Self = nil; });
}

- (IBAction)onEmailFeedback:(id) [[maybe_unused]] _sender
{
    m_FeedbackManager->EmailFeedback();
}

- (IBAction)onHelp:(id) [[maybe_unused]] _sender
{
    m_FeedbackManager->EmailSupport();
}

- (IBAction)onRate:(id) [[maybe_unused]] _sender
{
    m_FeedbackManager->RateOnAppStore();
}

@end
