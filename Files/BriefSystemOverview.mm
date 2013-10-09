//
//  BriefSystemOverview.m
//  Files
//
//  Created by Michael G. Kazakov on 08.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "BriefSystemOverview.h"
#import "sysinfo.h"

@implementation BriefSystemOverview
{
    sysinfo::MemoryInfo m_MemoryInfo;
    sysinfo::CPULoad    m_CPULoad;
    
    // controls
    NSTextField *m_TextCPULoadSystem;
    NSTextField *m_TextCPULoadUser;
    NSTextField *m_TextCPULoadIdle;
    
    NSTimer                      *m_UpdateTimer;    
}




- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        memset(&m_MemoryInfo, 0, sizeof(m_MemoryInfo));
        memset(&m_CPULoad, 0, sizeof(m_CPULoad));
        [self UpdateData];
        
        [self CreateControls];
        [self UpdateControls];
        
        m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval:2 // 2 sec update
                                                         target:self
                                                       selector:@selector(UpdateByTimer:)
                                                       userInfo:nil
                                                        repeats:YES];
    }
    return self;
}

- (void)viewDidMoveToSuperview
{
    if(self.superview == nil)
        [m_UpdateTimer invalidate];
}

- (void) CreateControls
{
    m_TextCPULoadSystem = [[NSTextField alloc] initWithFrame:NSRect()];
    [m_TextCPULoadSystem setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_TextCPULoadSystem setEditable:false];
    [m_TextCPULoadSystem setBordered:false];
    [m_TextCPULoadSystem setDrawsBackground:false];
    [self addSubview:m_TextCPULoadSystem];

    m_TextCPULoadUser = [[NSTextField alloc] initWithFrame:NSRect()];
    [m_TextCPULoadUser setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_TextCPULoadUser setEditable:false];
    [m_TextCPULoadUser setBordered:false];
    [m_TextCPULoadUser setDrawsBackground:false];
    [self addSubview:m_TextCPULoadUser];
    
    m_TextCPULoadIdle = [[NSTextField alloc] initWithFrame:NSRect()];
    [m_TextCPULoadIdle setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_TextCPULoadIdle setEditable:false];
    [m_TextCPULoadIdle setBordered:false];
    [m_TextCPULoadIdle setDrawsBackground:false];
    [self addSubview:m_TextCPULoadIdle];
    

    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_TextCPULoadSystem, m_TextCPULoadUser, m_TextCPULoadIdle);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[m_TextCPULoadSystem]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[m_TextCPULoadUser]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[m_TextCPULoadIdle]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[m_TextCPULoadSystem]-[m_TextCPULoadUser]-[m_TextCPULoadIdle]" options:0 metrics:nil views:views]];
}

- (void) UpdateByTimer:(NSTimer*)theTimer
{
    [self UpdateData];
    [self UpdateControls];
}


- (void) UpdateData
{
    sysinfo::GetMemoryInfo(m_MemoryInfo);
    sysinfo::GetCPULoad(m_CPULoad);
}

- (void) UpdateControls
{
    [m_TextCPULoadSystem setStringValue:[NSString stringWithFormat:@"System: %.2f%%", m_CPULoad.system*100.]];
    [m_TextCPULoadUser setStringValue:[NSString stringWithFormat:@"User: %.2f%%", m_CPULoad.user*100.]];
    [m_TextCPULoadIdle setStringValue:[NSString stringWithFormat:@"Idle: %.2f%%", m_CPULoad.idle*100.]];
}

/*- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    // Drawing code here.
}*/

@end
