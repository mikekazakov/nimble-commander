//
//  MyToolbar.m
//  Files
//
//  Created by Michael G. Kazakov on 27.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <algorithm>
#import <numeric>
#import "MyToolbar.h"


using namespace std;

static const double g_Gap = 8.0;
static const int g_FlexInd = -1;

template<class InputIt, class T, class UnaryOperation>
T sum(InputIt first, InputIt last, T init, UnaryOperation op)
{
    for (; first != last; ++first)
        init += op(*first);
    return init;
}

template <class InputIterator, class BinaryPredicate>
typename iterator_traits<InputIterator>::difference_type
count_if_pair (InputIterator first, InputIterator last, BinaryPredicate pred)
{
    typename iterator_traits<InputIterator>::difference_type ret = 0;
    if(first == last)
        return ret;

    auto second = first;
    second++;
    
    while (second!=last) {
        if (pred(*first, *second)) ++ret;
        ++first;
        ++second;
    }
    return ret;
}

@implementation MyToolbar
{
    vector<int>     m_Indices;
    vector<NSView*> m_Views;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        [self UpdateVisibility];
    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)drawRect:(NSRect)rect
{
    NSDrawWindowBackground(rect);
}

- (void) InsertView:(NSView*) _view
{
    m_Views.push_back(_view);
    m_Indices.push_back((int)m_Views.size()-1);
    
    [self addSubview:_view];
    
    [self DoLayout];
}

- (void) InsertFlexSpace
{
    m_Indices.push_back(g_FlexInd);
    
    [self DoLayout];
}

- (double) MaxHeight
{
    double h = 0;
    for(auto i: m_Views)
        h = max(h, i.bounds.size.height);
    return h;
}

- (int) CountFlexSpaces
{
    return (int)count_if(begin(m_Indices), end(m_Indices), [](auto i) { return i == g_FlexInd; });
}

- (void) DoLayout
{
    double fixed_sum = sum(begin(m_Views), end(m_Views), 0., [](auto i) { return i.bounds.size.width; } );
    
    double fixed_gaps = 0;
    if(!m_Indices.empty() && m_Indices.front() >= 0) fixed_gaps += g_Gap;
    if(!m_Indices.empty() && m_Indices.back()  >= 0) fixed_gaps += g_Gap;
    fixed_gaps += count_if_pair(begin(m_Indices), end(m_Indices), [](auto i1, auto i2){
                                    return i1 >= 0 && i2 >= 0;
                                }) * g_Gap;
    
    double all_flex_space = max(self.bounds.size.width - fixed_sum - fixed_gaps, 0.);
    int flex_spaces_count = self.CountFlexSpaces;
    double space_per_flex = flex_spaces_count ? all_flex_space / flex_spaces_count : 0;

    double offset = 0;
    int last = 0;
    for(auto i:m_Indices)
    {
        if(i >= 0)
        {   // this is a view, layout it
            if(last >= 0)
                offset += g_Gap; // prev entry was a view
            NSView *v = m_Views[i];
            v.frameOrigin = NSMakePoint(offset, floor(((self.bounds.size.height - v.bounds.size.height) / 2.) + 0.5));
            offset += v.bounds.size.width;
        }
        else if(i == g_FlexInd)
            offset += space_per_flex;
        last = i;
    }
}

- (void)frameDidChange
{
    [self DoLayout];
}

- (void)setHidden:(BOOL)flag
{
    if(self.isHidden == flag)
        return;
    
    [super setHidden:flag];
    [NSUserDefaults.standardUserDefaults setBool:!flag forKey:@"GeneralShowToolbar"];
}

- (void) UpdateVisibility
{
    [super setHidden:![NSUserDefaults.standardUserDefaults boolForKey:@"GeneralShowToolbar"]];
}

@end
