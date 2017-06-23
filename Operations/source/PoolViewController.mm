#include "PoolViewController.h"
#include "Pool.h"
#include "Internal.h"
#include "BriefOperationViewController.h"

using namespace nc::ops;

@interface NCOpsPoolViewController()
@property (strong) IBOutlet NSTextField *label;
@property (strong) IBOutlet NSTextField *ETA;
@property (strong) IBOutlet NSView *briefViewHolder;

@end

@implementation NCOpsPoolViewController
{
    shared_ptr<Pool> m_Pool;
//    NSTimer *m_RapidTimer;
//    NSTimer *m_SlowTimer;

    vector<NCOpsBriefOperationViewController*> m_BriefViews;
}

- (instancetype) initWithPool:(Pool&)_pool
{
    dispatch_assert_main_queue();
    self = [super initWithNibName:@"PoolViewController" bundle:Bundle()];
    if( self ) {
        m_Pool = _pool.shared_from_this();
        
        m_Pool->ObserveUnticketed(Pool::NotifyAboutChange,
                                  objc_callback(self, @selector(poolDidChangeCallback)));
    }
    return self;
}

- (void) dealloc
{
//    dispatch_assert_main_queue();
//    int a = 10;
}

- (void)poolDidChangeCallback
{
    dispatch_to_main_queue([=]{
        [self poolDidChange];
    });
}

- (void)poolDidChange
{
    //        label.
    const auto op_num = m_Pool->TotalOperationsCount();
    
    self.label.integerValue = op_num;
    //        if( op_num == 0 )
    //            [self stopAnimating];
    //        else if( ![self isAnimating] )
    //            [self startAnimating];
    
//    if( op_num == 1 ) {
//        if( const auto operation = m_Pool->Front() ) {
//            const auto bvc = [[NCOpsBriefOperationViewController alloc] initWithOperation:operation];
//            m_BriefViews.emplace_back(bvc);
//            [self showBriefView:bvc];
//        }
    const auto operations = m_Pool->Operations();
    [self syncWithOperations:operations];
//    }
}


- (void)syncWithOperations:(const vector<shared_ptr<Operation>>&)_operations
{
//    const auto has =
    const auto find_existing = [=](const shared_ptr<Operation>&_op){
        const auto existing = find_if( begin(m_BriefViews), end(m_BriefViews), [_op](auto &v){
            return v.operation == _op;
        });
        return existing != end(m_BriefViews) ? *existing : nullptr;
    };
    
    vector<NCOpsBriefOperationViewController*> new_views;
    new_views.reserve(_operations.size());
    for( auto o: _operations )
        if( const auto existing = find_existing(o) ) {
            new_views.emplace_back(existing);
        }
        else {
            const auto bvc = [[NCOpsBriefOperationViewController alloc] initWithOperation:o];
            new_views.emplace_back(bvc);
        }
 
    m_BriefViews = new_views;
    if( m_BriefViews.empty() )
        [self hideBriefView];
    else
        [self showBriefView:m_BriefViews.front()];
}

- (void)showBriefView:(NCOpsBriefOperationViewController*)_view
{
    const auto bv = _view.view;

    const auto subviews = self.briefViewHolder.subviews;
    if( subviews.count != 0 && subviews[0] == bv )
        return;

    [self hideBriefView];
    [self.briefViewHolder addSubview:bv];
    bv.frame = NSMakeRect(0,
                          0,
                          self.briefViewHolder.bounds.size.width,
                          self.briefViewHolder.bounds.size.height);
}

- (void)hideBriefView
{
    for( NSView* v in self.briefViewHolder.subviews )
        [v removeFromSuperview];
}

@end
