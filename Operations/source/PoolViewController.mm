// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PoolViewController.h"
#include "Pool.h"
#include "Internal.h"
#include "BriefOperationViewController.h"

using namespace nc::ops;

static const auto g_ViewAppearTimeout = 100ms;

@interface NCOpsPoolViewController()
@property (strong) IBOutlet NSView *idleViewHolder;
@property (strong) IBOutlet NSView *briefViewHolder;
@property (strong) IBOutlet NSButton *upButton;
@property (strong) IBOutlet NSButton *downButton;


@end

@implementation NCOpsPoolViewController
{
    shared_ptr<Pool> m_Pool;
    vector<NCOpsBriefOperationViewController*> m_BriefViews;
    int m_IndexToShow;
    shared_ptr<Operation> m_ShownOperation;
}

- (instancetype) initWithPool:(Pool&)_pool
{
    dispatch_assert_main_queue();
    self = [super initWithNibName:@"PoolViewController" bundle:Bundle()];
    if( self ) {
        m_IndexToShow = -1;
        m_Pool = _pool.shared_from_this();
        m_Pool->ObserveUnticketed(Pool::NotifyAboutChange,
                                  objc_callback(self, @selector(poolDidChangeCallback)));
    }
    return self;
}

- (void)poolDidChangeCallback
{
    dispatch_to_main_queue([=]{
        [self poolDidChange];
    });
}

- (void)poolDidChange
{
    [self syncWithOperations:m_Pool->Operations()];
    [self updateButtonsState];
}

- (void)syncWithOperations:(const vector<shared_ptr<Operation>>&)_operations
{
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
            new_views.emplace_back([[NCOpsBriefOperationViewController alloc] initWithOperation:o]);
            new_views.back().shouldDelayAppearance = _operations.size() == 1;
        }
 
    const auto index_of = [=](const shared_ptr<Operation>&_op)->int{
        const auto it = find_if( begin(m_BriefViews), end(m_BriefViews), [_op](auto &v){
            return v.operation == _op;
        });
        return it != end(m_BriefViews) ? (int)distance(begin(m_BriefViews), it) : -1;
    };
    
    m_BriefViews = new_views;
    
    if( m_ShownOperation ) {
        if( const auto ind = index_of(m_ShownOperation); ind >= 0 )
            m_IndexToShow = ind;
        else
            m_ShownOperation = nullptr;
    }

    if( !m_ShownOperation ) {
        m_IndexToShow = min(max(m_IndexToShow, 0), (int)m_BriefViews.size() - 1);
        if( m_IndexToShow >= 0 )
            m_ShownOperation = m_BriefViews[m_IndexToShow].operation;
    }
 
    if( m_IndexToShow < 0 )
        [self hideBriefView];
    else
        [self showBriefView:m_BriefViews[m_IndexToShow]];
    
    [self updateIdleViewVisibility];
}

- (void)updateIdleViewVisibility
{
    if( self.idleView.hidden && m_ShownOperation == nil )
        self.idleView.hidden = false;
    else if( !self.idleView.hidden && m_ShownOperation != nil )
        dispatch_to_main_queue_after(g_ViewAppearTimeout, [=]{
            if( m_ShownOperation )
                self.idleView.hidden = true;
        });
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

- (void)updateButtonsState
{
    const auto op_num = (int)m_BriefViews.size();
    self.upButton.hidden = op_num < 2;
    self.downButton.hidden = op_num < 2;
    if( op_num >= 2 ) {
        self.upButton.enabled = m_IndexToShow > 0;
        self.downButton.enabled = m_IndexToShow < op_num - 1;
    }
}

- (IBAction)onUpButtonClicked:(id)sender
{
    if( m_BriefViews.size() >= 2 && m_IndexToShow > 0) {
        m_IndexToShow--;
        const auto v = m_BriefViews[m_IndexToShow];
        m_ShownOperation = v.operation;
        [self showBriefView:v];
        [self updateButtonsState];
    }
}

- (IBAction)onDownButtonClicked:(id)sender
{
    if( m_BriefViews.size() >= 2 && m_IndexToShow < m_BriefViews.size() - 1 ) {
        m_IndexToShow++;
        const auto v = m_BriefViews[m_IndexToShow];
        m_ShownOperation = v.operation;
        [self showBriefView:v];
        [self updateButtonsState];
    }
}

- (NSView*)idleView
{
    return self.idleViewHolder;
}

@end
