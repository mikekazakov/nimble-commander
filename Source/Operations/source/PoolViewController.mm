// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PoolViewController.h"
#include "Pool.h"
#include "Internal.h"
#include "BriefOperationViewController.h"
#include <Base/dispatch_cpp.h>
#include <Utility/ObjCpp.h>

#include <algorithm>

using namespace nc::ops;
using namespace std::literals;

static const auto g_ViewAppearTimeout = 100ms;

@interface NCOpsPoolViewController ()
@property(strong, nonatomic) IBOutlet NSView *idleViewHolder;
@property(strong, nonatomic) IBOutlet NSView *briefViewHolder;
@property(strong, nonatomic) IBOutlet NSButton *upButton;
@property(strong, nonatomic) IBOutlet NSButton *downButton;

@end

@implementation NCOpsPoolViewController {
    std::shared_ptr<Pool> m_Pool;
    std::vector<NCOpsBriefOperationViewController *> m_BriefViews;
    int m_IndexToShow;
    std::shared_ptr<Operation> m_ShownOperation;
}
@synthesize idleViewHolder;
@synthesize briefViewHolder;
@synthesize upButton;
@synthesize downButton;

- (instancetype)initWithPool:(Pool &)_pool
{
    dispatch_assert_main_queue();
    self = [super initWithNibName:@"PoolViewController" bundle:Bundle()];
    if( self ) {
        m_IndexToShow = -1;
        m_Pool = _pool.shared_from_this();
        m_Pool->ObserveUnticketed(Pool::NotifyAboutChange, nc::objc_callback(self, @selector(poolDidChangeCallback)));
    }
    return self;
}

- (void)poolDidChangeCallback
{
    dispatch_to_main_queue([=] { [self poolDidChange]; });
}

- (void)poolDidChange
{
    [self syncWithOperations:m_Pool->Operations()];
    [self updateButtonsState];
}

- (void)syncWithOperations:(const std::vector<std::shared_ptr<Operation>> &)_operations
{
    const auto find_existing = [=](const std::shared_ptr<Operation> &_op) {
        const auto existing = std::ranges::find_if(m_BriefViews, [_op](auto &v) { return v.operation == _op; });
        return existing != m_BriefViews.end() ? *existing : nullptr;
    };

    std::vector<NCOpsBriefOperationViewController *> new_views;
    new_views.reserve(_operations.size());
    for( const auto &o : _operations )
        if( const auto existing = find_existing(o) ) {
            new_views.emplace_back(existing);
        }
        else {
            new_views.emplace_back([[NCOpsBriefOperationViewController alloc] initWithOperation:o]);
            new_views.back().shouldDelayAppearance = _operations.size() == 1;
        }

    const auto index_of = [=](const std::shared_ptr<Operation> &_op) -> int {
        const auto it = std::ranges::find_if(m_BriefViews, [_op](auto &v) { return v.operation == _op; });
        return it != m_BriefViews.end() ? static_cast<int>(std::distance(m_BriefViews.begin(), it)) : -1;
    };

    // NB! retain the view controllers until their view are removed
    std::vector<NCOpsBriefOperationViewController *> old_view = m_BriefViews;
    m_BriefViews = new_views;

    if( m_ShownOperation ) {
        if( const auto ind = index_of(m_ShownOperation); ind >= 0 )
            m_IndexToShow = ind;
        else
            m_ShownOperation = nullptr;
    }

    if( !m_ShownOperation ) {
        m_IndexToShow = std::min(std::max(m_IndexToShow, 0), static_cast<int>(m_BriefViews.size()) - 1);
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
        dispatch_to_main_queue_after(g_ViewAppearTimeout, [=] {
            if( m_ShownOperation )
                self.idleView.hidden = true;
        });
}

- (void)showBriefView:(NCOpsBriefOperationViewController *)_view
{
    const auto bv = _view.view;

    const auto subviews = self.briefViewHolder.subviews;
    if( subviews.count != 0 && subviews[0] == bv )
        return;

    [self hideBriefView];
    [self.briefViewHolder addSubview:bv];
    NSDictionary *views = NSDictionaryOfVariableBindings(bv);
    [self.briefViewHolder addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[bv]-(==0)-|"
                                                                                 options:0
                                                                                 metrics:nil
                                                                                   views:views]];
    [self.briefViewHolder addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[bv]-(==0)-|"
                                                                                 options:0
                                                                                 metrics:nil
                                                                                   views:views]];
}

- (void)hideBriefView
{
    for( NSView *v in self.briefViewHolder.subviews )
        [v removeFromSuperview];
}

- (void)updateButtonsState
{
    const auto op_num = static_cast<int>(m_BriefViews.size());
    self.upButton.hidden = op_num < 2;
    self.downButton.hidden = op_num < 2;
    if( op_num >= 2 ) {
        self.upButton.enabled = m_IndexToShow > 0;
        self.downButton.enabled = m_IndexToShow < op_num - 1;
    }
}

- (IBAction)onUpButtonClicked:(id) [[maybe_unused]] _sender
{
    if( m_BriefViews.size() >= 2 && m_IndexToShow > 0 ) {
        m_IndexToShow--;
        const auto v = m_BriefViews[m_IndexToShow];
        m_ShownOperation = v.operation;
        [self showBriefView:v];
        [self updateButtonsState];
    }
}

- (IBAction)onDownButtonClicked:(id) [[maybe_unused]] _sender
{
    if( m_BriefViews.size() >= 2 && m_IndexToShow < static_cast<int>(m_BriefViews.size() - 1) ) {
        m_IndexToShow++;
        const auto v = m_BriefViews[m_IndexToShow];
        m_ShownOperation = v.operation;
        [self showBriefView:v];
        [self updateButtonsState];
    }
}

- (NSView *)idleView
{
    return self.idleViewHolder;
}

@end
