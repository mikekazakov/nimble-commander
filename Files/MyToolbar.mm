//
//  MyToolbar.m
//  Files
//
//  Created by Michael G. Kazakov on 27.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import "MyToolbar.h"

using namespace std;

static const double g_Gap = 8.0;
static const int g_FlexInd = -1;

@implementation MyToolbar
{
    vector<int>     m_Indices;
    vector<NSView*> m_Views;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
        [self UpdateVisibility];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)drawRect:(NSRect)rect {
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
        if(i.bounds.size.height > h)
            h = i.bounds.size.height;
    return h;
}

- (int) CountFlexSpaces
{
    int n = 0;
    for(auto i: m_Indices)
        if(i == g_FlexInd)
            n++;
    return n;
}

- (void) DoLayout
{
    double fixed_sum = 0;
    for(auto i: m_Views)
        fixed_sum += i.bounds.size.width;
    
    double fixed_gaps = 0;
    for(int i = 0; i < m_Indices.size(); ++i)
    {
        if( i == 0 && m_Indices[i] >= 0 ) {
            // first entry is a view
            fixed_gaps += g_Gap;
        }
        
        if( i < m_Indices.size() - 1 &&
           m_Indices[i] >= 0 &&
           m_Indices[i+1] >= 0
           ) {
            // gap between fixed elements
            fixed_gaps += g_Gap;
        }
        
        if(i == m_Indices.size() - 1 &&
           m_Indices[i] >= 0) {
            // last entry is a view
            fixed_gaps += g_Gap;
        }
    }
    
    double all_flex_space = self.bounds.size.width - fixed_sum - fixed_gaps;
    if(all_flex_space < 0) all_flex_space = 0;
    int flex_spaces_count = self.CountFlexSpaces;
    double space_per_flex = 0;
    if(flex_spaces_count)
        space_per_flex = all_flex_space / flex_spaces_count;
    
    
    double offset = 0;
    
    for(int i = 0; i < m_Indices.size(); ++i)
    {
        if( i == 0 && m_Indices[i] >= 0 ) {
            // first entry is a view
            offset += g_Gap;
        }
        
        if(m_Indices[i] >= 0)
        {
            // this is a view
            NSView *v = m_Views[m_Indices[i]];
            // layout it
            
            NSRect frame;
//            frame.origin.y = self.bounds.size.height / 2;
            frame.origin.y = (self.bounds.size.height - v.bounds.size.height) / 2;
            frame.origin.x = offset;
            frame.size = v.bounds.size;
            
            [v setFrame:frame];
            
            offset += v.bounds.size.width;
            
            if( i < m_Indices.size() - 1 && m_Indices[i+1] >= 0)
                offset += g_Gap;
        }
        else if(m_Indices[i] == g_FlexInd)
        {
            offset += space_per_flex;
        }
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
