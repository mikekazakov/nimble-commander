#include "BriefOperationViewController.h"
#include "Internal.h"
#include "Operation.h"
#include <Utility/ByteCountFormatter.h>
#include "StatisticsFormatter.h"

using namespace nc::ops;

@interface NCOpsBriefOperationViewController()
@property (strong) IBOutlet NSTextField *ETA;
@property (strong) IBOutlet NSProgressIndicator *progressBar;

@end

@implementation NCOpsBriefOperationViewController
{
    shared_ptr<nc::ops::Operation> m_Operation;
    NSTimer *m_RapidTimer;
    NSTimer *m_SlowTimer;
    NSString *m_ETA;
}

- (instancetype)initWithOperation:(const shared_ptr<nc::ops::Operation>&)_operation
{
    dispatch_assert_main_queue();
    if( !_operation )
        return nil;
    
    self = [super initWithNibName:@"BriefOperationViewController" bundle:Bundle()];
    if( self ) {
        m_Operation = _operation;
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
    self.ETA.font = [NSFont monospacedDigitSystemFontOfSize:self.ETA.font.pointSize
                                                     weight:NSFontWeightRegular];
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
        m_RapidTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0
                                                         target:self
                                                       selector:@selector(updateRapid)
                                                       userInfo:nil
                                                        repeats:YES];
        m_RapidTimer.tolerance = m_RapidTimer.timeInterval/10.;
    }
    if (!m_SlowTimer) {
        m_SlowTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
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
    const auto done = m_Operation->Statistics().DoneFraction(Statistics::SourceType::Bytes);
    if( done != 0.0 && self.progressBar.isIndeterminate ) {
        [self.progressBar setIndeterminate:false];
        [self.progressBar stopAnimation:self];
    }
    self.progressBar.doubleValue = done;
}

- (void)updateSlow
{

    self.ETA.stringValue = StatisticsFormatter{m_Operation->Statistics()}.ProgressCaption();
}

- (IBAction)onStop:(id)sender
{
    m_Operation->Stop();
}
- (IBAction)onPause:(id)sender {
}

@end
