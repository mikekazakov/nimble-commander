// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BriefOperationViewController.h"
#include "Internal.h"
#include "Operation.h"
#include "Statistics.h"
#include "StatisticsFormatter.h"
#include <Base/dispatch_cpp.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>

using namespace nc::ops;

using namespace std::literals;

static const auto g_ViewAppearTimeout = 100ms;
static const auto g_RapidUpdateFreq = 30.0;
static const auto g_SlowUpdateFreq = 1.0;

@interface NCOpsBriefOperationViewController ()
@property(strong, nonatomic) IBOutlet NSTextField *titleLabel;
@property(strong, nonatomic) IBOutlet NSTextField *ETA;
@property(strong, nonatomic) IBOutlet NSProgressIndicator *progressBar;
@property(strong, nonatomic) IBOutlet NSButton *pauseButton;
@property(strong, nonatomic) IBOutlet NSButton *resumeButton;
@property(strong, nonatomic) IBOutlet NSButton *stopButton;
@property(nonatomic) bool isPaused;
@property(nonatomic) bool isCold;
@end

@implementation NCOpsBriefOperationViewController {
    std::shared_ptr<nc::ops::Operation> m_Operation;
    NSTimer *m_RapidTimer;
    NSTimer *m_SlowTimer;
    NSString *m_ETA;
    bool m_ShouldDelayAppearance;
}

@synthesize shouldDelayAppearance = m_ShouldDelayAppearance;
@synthesize titleLabel;
@synthesize ETA;
@synthesize progressBar;
@synthesize pauseButton;
@synthesize resumeButton;
@synthesize stopButton;
@synthesize isPaused;
@synthesize isCold;

- (instancetype)initWithOperation:(const std::shared_ptr<nc::ops::Operation> &)_operation
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
        _operation->ObserveUnticketed(Operation::NotifyAboutStateChange,
                                      nc::objc_callback_to_main_queue(self, @selector(onOperationStateChanged)));
        _operation->ObserveUnticketed(Operation::NotifyAboutTitleChange,
                                      nc::objc_callback_to_main_queue(self, @selector(onOperationTitleChanged)));
    }
    return self;
}

- (const std::shared_ptr<nc::ops::Operation> &)operation
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
        dispatch_to_main_queue_after(g_ViewAppearTimeout, [self] { self.view.hidden = false; });
    }
    self.ETA.font = [NSFont monospacedDigitSystemFontOfSize:self.ETA.font.pointSize weight:NSFontWeightRegular];
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
    if( !m_RapidTimer ) {
        m_RapidTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / g_RapidUpdateFreq
                                                        target:self
                                                      selector:@selector(updateRapid)
                                                      userInfo:nil
                                                       repeats:YES];
        m_RapidTimer.tolerance = m_RapidTimer.timeInterval / 10.;
    }
    if( !m_SlowTimer ) {
        m_SlowTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / g_SlowUpdateFreq
                                                       target:self
                                                     selector:@selector(updateSlow)
                                                     userInfo:nil
                                                      repeats:YES];
        m_SlowTimer.tolerance = m_SlowTimer.timeInterval / 10.;
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
    if( m_Operation->State() == OperationState::Cold )
        self.ETA.stringValue = NSLocalizedString(@"Waiting in the queue...", "");
    else
        self.ETA.stringValue = StatisticsFormatter{m_Operation->Statistics()}.ProgressCaption();
}

- (IBAction)onStop:(id) [[maybe_unused]] sender
{
    m_Operation->Stop();
    self.stopButton.hidden = true;
    self.pauseButton.hidden = true;
    self.resumeButton.hidden = true;
}

- (IBAction)onPause:(id) [[maybe_unused]] sender
{
    m_Operation->Pause();
}

- (IBAction)onResume:(id) [[maybe_unused]] sender
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
