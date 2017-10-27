// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BriefOperationViewController.h"
#include "Internal.h"
#include "Operation.h"
#include <Utility/ByteCountFormatter.h>
#include "StatisticsFormatter.h"
#include "Statistics.h"
#include "Internal.h"

using namespace nc::ops;

static const auto g_ViewAppearTimeout = 100ms;
static const auto g_RapidUpdateFreq = 30.0;
static const auto g_SlowUpdateFreq = 1.0;

@interface NCOpsBriefOperationViewController()
@property (strong) IBOutlet NSTextField *titleLabel;
@property (strong) IBOutlet NSTextField *ETA;
@property (strong) IBOutlet NSProgressIndicator *progressBar;
@property (strong) IBOutlet NSButton *pauseButton;
@property (strong) IBOutlet NSButton *resumeButton;
@property (strong) IBOutlet NSButton *stopButton;
@property bool isPaused;
@property bool isCold;
@end

@implementation NCOpsBriefOperationViewController
{
    shared_ptr<nc::ops::Operation> m_Operation;
    NSTimer *m_RapidTimer;
    NSTimer *m_SlowTimer;
    NSString *m_ETA;
    bool m_ShouldDelayAppearance;
}

@synthesize shouldDelayAppearance = m_ShouldDelayAppearance;

- (instancetype)initWithOperation:(const shared_ptr<nc::ops::Operation>&)_operation
{
    dispatch_assert_main_queue();
    assert(_operation);
    
    self = [super initWithNibName:@"BriefOperationViewController" bundle:Bundle()];
    if( self ) {
        m_ShouldDelayAppearance = false;
        m_Operation = _operation;
        const auto current_state = _operation->State();
        self.isPaused = current_state == OperationState::Paused;
        self.isCold = current_state == OperationState::Cold;
        _operation->ObserveUnticketed(
            Operation::NotifyAboutStateChange,
            objc_callback_to_main_queue(self, @selector(onOperationStateChanged)));
        _operation->ObserveUnticketed(
            Operation::NotifyAboutTitleChange,
            objc_callback_to_main_queue(self, @selector(onOperationTitleChanged)));
    }
    return self;
}

- (const shared_ptr<nc::ops::Operation>&) operation
{
    return m_Operation;
}

- (bool)isAnimating
{
    return m_RapidTimer != nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if( m_ShouldDelayAppearance ) {
        self.view.hidden = true;
        dispatch_to_main_queue_after(g_ViewAppearTimeout, [self]{
            self.view.hidden = false;
        });
    }
    self.ETA.font = [NSFont monospacedDigitSystemFontOfSize:self.ETA.font.pointSize
                                                     weight:NSFontWeightRegular];
    [self onOperationTitleChanged];
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [self startAnimating];
    [self.progressBar startAnimation:self];

}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    [self stopAnimating];
}

- (void)startAnimating
{
    dispatch_assert_main_queue();
    if (!m_RapidTimer) {
        m_RapidTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/g_RapidUpdateFreq
                                                         target:self
                                                       selector:@selector(updateRapid)
                                                       userInfo:nil
                                                        repeats:YES];
        m_RapidTimer.tolerance = m_RapidTimer.timeInterval/10.;
    }
    if (!m_SlowTimer) {
        m_SlowTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/g_SlowUpdateFreq
                                                         target:self
                                                       selector:@selector(updateSlow)
                                                       userInfo:nil
                                                        repeats:YES];
        m_SlowTimer.tolerance = m_SlowTimer.timeInterval/10.;
    }
    [self updateSlow];
    [self updateRapid];
}

- (void)stopAnimating
{
    dispatch_assert_main_queue();
    if( m_RapidTimer ) {
        [m_RapidTimer invalidate];
        m_RapidTimer = nil;
    }
    if( m_SlowTimer ) {
        [m_SlowTimer invalidate];
        m_SlowTimer = nil;
    }
}

- (void)updateRapid
{
    const auto preffered_source = m_Operation->Statistics().PreferredSource();
    const auto done = m_Operation->Statistics().DoneFraction(preffered_source);
    if( done != 0.0 && self.progressBar.isIndeterminate ) {
        [self.progressBar setIndeterminate:false];
        [self.progressBar stopAnimation:self];
    }
    self.progressBar.doubleValue = done;
}

- (void)updateSlow
{
    if(m_Operation->State() == OperationState::Cold)
        self.ETA.stringValue = NSLocalizedString(@"Waiting in the queue...", "");
    else
        self.ETA.stringValue = StatisticsFormatter{m_Operation->Statistics()}.ProgressCaption();
}

- (IBAction)onStop:(id)sender
{
    m_Operation->Stop();
    self.stopButton.hidden = true;
    self.pauseButton.hidden = true;
    self.resumeButton.hidden = true;
}

- (IBAction)onPause:(id)sender
{
    m_Operation->Pause();
}

- (IBAction)onResume:(id)sender
{
    m_Operation->Resume();
}

- (void)onOperationStateChanged
{
    const auto new_state = m_Operation->State();
    self.isPaused = new_state == OperationState::Paused;
    self.isCold = new_state == OperationState::Cold;
}

- (void)onOperationTitleChanged
{
    self.titleLabel.stringValue = [NSString stringWithUTF8StdString:m_Operation->Title()];
}

@end
