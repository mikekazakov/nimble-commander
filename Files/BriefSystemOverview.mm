//
//  BriefSystemOverview.m
//  Files
//
//  Created by Michael G. Kazakov on 08.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <stdint.h>
#import "BriefSystemOverview.h"
#import "sysinfo.h"
#import "Common.h"

static NSString *FormHumanReadableMemSize(uint64_t _sz)
{
    // format should be xx.yy AB
    // or x.YY AB
    // or 0 bytes
    
    if(_sz < 999ul)
    {
        // bytes, ABC bytes format, 5 symbols max
        return [NSString stringWithFormat:@"%llu B",
                _sz
                ];
    }
    else if(_sz < 999ul * 1024ul)
    {
        // kilobytes, ABC KB format, 6 symbols max
        return [NSString stringWithFormat:@"%.0f KB",
                (double)_sz / double(1024ul)
                ];
    }
    else if(_sz < 99ul * 1024ul * 1024ul)
    {
        // megabytes, AB.CD MB format, 8 symbols max
        return [NSString stringWithFormat:@"%.2f MB",
                (double)_sz / double(1024ul * 1024ul)
                ];
    }
    else if(_sz < 99ul * 1024ul * 1024ul * 1024ul)
    {
        // gygabites, AB.CD GB format, 8 symbols max
        return [NSString stringWithFormat:@"%.2f GB",
                (double)_sz / double(1024ul * 1024ul * 1024ul)
                ];
    }
    else
        return @"";
}

NSTextField *CreateStockTF()
{
    auto tf = [[NSTextField alloc] initWithFrame:NSRect()];
    [tf setTranslatesAutoresizingMaskIntoConstraints:NO];
    [tf setEditable:false];
    [tf setBordered:false];
    [tf setDrawsBackground:false];
    return tf;
}

@implementation BriefSystemOverview
{
    sysinfo::MemoryInfo m_MemoryInfo;
    sysinfo::CPULoad    m_CPULoad;
    sysinfo::SystemOverview m_Overview;
    VFSStatFS           m_StatFS;
    
    // controls
    NSTextField *m_TextCPULoadSystem;
    NSTextField *m_TextCPULoadUser;
    NSTextField *m_TextCPULoadIdle;

    NSTextField *m_TextMemTotal;
    NSTextField *m_TextMemUsed;
    NSTextField *m_TextMemSwap;
    
    NSTextField *m_TextMachineModel;
    NSTextField *m_TextComputerName;
    NSTextField *m_TextUserName;
    
    NSTextField *m_TextVolumeName;
    NSTextField *m_TextVolumeTotalBytes;
    NSTextField *m_TextVolumeAvailBytes;
    
    std::string m_TargetVFSPath;
    std::shared_ptr<VFSHost> m_TargetVFSHost;
    bool m_IsRight;
    NSTimer                      *m_UpdateTimer;
}




- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_IsRight = true;
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

- (BOOL) isOpaque
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self UpdateAlignment];
    
	[super drawRect:dirtyRect];
    NSColor *c;
    NSGraphicsContext *contetx = [NSGraphicsContext currentContext];
    [contetx saveGraphicsState];
    c = [NSColor colorWithCalibratedRed:0.97 green:0.97 blue:0.97 alpha:1.0];
    [c set];
    NSRectFill([self bounds]);
    [contetx restoreGraphicsState];

}

- (void) UpdateAlignment
{
    bool was_right = m_IsRight;
    if(self.superview != nil && [self.superview isKindOfClass:[NSSplitView class]])
    {
        NSSplitView *s = (NSSplitView *)self.superview;
        NSArray *v = [s subviews];
        unsigned long ind = [v indexOfObject:self];
        if(ind == 0)
            m_IsRight = false;
        else if(ind == 1)
            m_IsRight = true;
    }
    if(m_IsRight != was_right)
    {
        [self CreateControls];
        [self UpdateControls];
    }
}

- (void)viewDidMoveToSuperview
{
    if(self.superview == nil)
        [m_UpdateTimer invalidate];
}

- (void) CreateControls
{
    NSColor *box_sep_color = [NSColor colorWithCalibratedRed:0.85 green:0.85 blue:0.85 alpha:1.0];
    NSFont *text_font = [NSFont labelFontOfSize:11];
 
    // clear current layout
    while ([self.subviews count] > 0)
        [[self.subviews lastObject] removeFromSuperview];
    
    ////////////////////////////////////////////////////////////////////////////////// Title
    NSTextField *title = CreateStockTF();
    [title setStringValue:@"Brief System Information"];
    [title setAlignment:NSCenterTextAlignment];
    [title setFont:[NSFont boldSystemFontOfSize:13]];
    [self addSubview:title];
    
    ////////////////////////////////////////////////////////////////////////////////// CPU
    NSBox *cpu_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        [cpu_box setTranslatesAutoresizingMaskIntoConstraints:NO];
        [cpu_box setTitlePosition:NSAtTop];
        [cpu_box setContentViewMargins:{2, 2}];
        [cpu_box setBorderType:NSLineBorder];
        [cpu_box setTitle:@"CPU"];
        [self addSubview:cpu_box];
        
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        [line1 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line1 setBoxType:NSBoxCustom];
        [line1 setBorderColor:box_sep_color];
        [cpu_box addSubview:line1];

        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        [line2 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line2 setBoxType:NSBoxCustom];
        [line2 setBorderColor:box_sep_color ];
        [cpu_box addSubview:line2];
        
        auto cpu_sysload_title = CreateStockTF();
        [cpu_sysload_title setStringValue:@"System:"];
        [cpu_sysload_title setFont: text_font];
        [cpu_box addSubview:cpu_sysload_title];

        auto cpu_usrload_title = CreateStockTF();
        [cpu_usrload_title setStringValue:@"User:"];
        [cpu_usrload_title setFont: text_font];
        [cpu_box addSubview:cpu_usrload_title];

        auto cpu_idle_title = CreateStockTF();
        [cpu_idle_title setStringValue:@"Idle:"];
        [cpu_idle_title setFont: text_font];
        [cpu_box addSubview:cpu_idle_title];

        m_TextCPULoadSystem = CreateStockTF();
        [m_TextCPULoadSystem setFont: text_font];
        [m_TextCPULoadSystem setTextColor:[NSColor colorWithCalibratedRed:1.00 green:0.15 blue:0.10 alpha:1.0]];
        [cpu_box addSubview:m_TextCPULoadSystem];
    
        m_TextCPULoadUser = CreateStockTF();
        [m_TextCPULoadUser setFont: text_font];
        [m_TextCPULoadUser setTextColor:[NSColor colorWithCalibratedRed:0.10 green:0.15 blue:1.00 alpha:1.0]];
        [cpu_box addSubview:m_TextCPULoadUser];
    
        m_TextCPULoadIdle = CreateStockTF();
        [m_TextCPULoadIdle setFont: text_font];
        [cpu_box addSubview:m_TextCPULoadIdle];
    
        NSDictionary *cpu_box_views = NSDictionaryOfVariableBindings(m_TextCPULoadSystem, m_TextCPULoadUser, m_TextCPULoadIdle, cpu_sysload_title, cpu_usrload_title, cpu_idle_title, line1, line2);
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[cpu_sysload_title]" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[cpu_usrload_title]" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[cpu_idle_title]" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextCPULoadSystem]-(==8)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextCPULoadUser]-(==8)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextCPULoadIdle]-(==8)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line1]-(==1)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line2]-(==1)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[cpu_sysload_title]-(<=1)-[line1(==1)]-(==7)-[cpu_usrload_title]-(<=1)-[line2(==1)]-(==7)-[cpu_idle_title]" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextCPULoadSystem]-(<=1)-[line1]" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextCPULoadUser]-(<=1)-[line2]" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[line2]-(==7)-[m_TextCPULoadIdle]" options:0 metrics:nil views:cpu_box_views]];
    }

    ////////////////////////////////////////////////////////////////////////////////// RAM
    NSBox *ram_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        [ram_box setTranslatesAutoresizingMaskIntoConstraints:NO];
        [ram_box setTitlePosition:NSAtTop];
        [ram_box setContentViewMargins:{2, 2}];
        [ram_box setBorderType:NSLineBorder];
        [ram_box setTitle:@"RAM"];
        [self addSubview:ram_box];
    
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        [line1 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line1 setBoxType:NSBoxCustom];
        [line1 setBorderColor:box_sep_color];
        [ram_box addSubview:line1];
        
        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        [line2 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line2 setBoxType:NSBoxCustom];
        [line2 setBorderColor:box_sep_color ];
        [ram_box addSubview:line2];
        
        auto ram_total_title = CreateStockTF();
        [ram_total_title setStringValue:@"Total:"];
        [ram_total_title setFont: text_font];
        [ram_box addSubview:ram_total_title];

        auto ram_used_title = CreateStockTF();
        [ram_used_title setStringValue:@"Used:"];
        [ram_used_title setFont: text_font];
        [ram_box addSubview:ram_used_title];

        auto ram_swap_title = CreateStockTF();
        [ram_swap_title setStringValue:@"Swap:"];
        [ram_swap_title setFont: text_font];
        [ram_box addSubview:ram_swap_title];
    
        m_TextMemTotal = CreateStockTF();
        [m_TextMemTotal setFont: text_font];
        [ram_box addSubview:m_TextMemTotal];

        m_TextMemUsed = CreateStockTF();
        [m_TextMemUsed setFont: text_font];
        [ram_box addSubview:m_TextMemUsed];

        m_TextMemSwap = CreateStockTF();
        [m_TextMemSwap setFont: text_font];
        [ram_box addSubview:m_TextMemSwap];
    
        NSDictionary *ram_box_views = NSDictionaryOfVariableBindings(m_TextMemTotal, m_TextMemUsed, m_TextMemSwap, ram_total_title, ram_used_title, ram_swap_title, line1, line2);
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[ram_total_title]" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[ram_used_title]" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[ram_swap_title]" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextMemTotal]-(==8)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextMemUsed]-(==8)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextMemSwap]-(==8)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line1]-(==1)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line2]-(==1)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[ram_total_title]-(<=1)-[line1(==1)]-(==7)-[ram_used_title]-(<=1)-[line2(==1)]-(==7)-[ram_swap_title]" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextMemTotal]-(<=1)-[line1]" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextMemUsed]-(<=1)-[line2]" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[line2]-(==7)-[m_TextMemSwap]" options:0 metrics:nil views:ram_box_views]];
    }
    
    ////////////////////////////////////////////////////////////////////////////////// SYSTEM
    NSBox *system_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        [system_box setTranslatesAutoresizingMaskIntoConstraints:NO];
        [system_box setTitlePosition:NSAtTop];
        [system_box setContentViewMargins:{2, 2}];
        [system_box setBorderType:NSLineBorder];
        [system_box setTitle:@"General"];
        [self addSubview:system_box];
    
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        [line1 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line1 setBoxType:NSBoxCustom];
        [line1 setBorderColor:box_sep_color];
        [system_box addSubview:line1];
        
        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        [line2 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line2 setBoxType:NSBoxCustom];
        [line2 setBorderColor:box_sep_color ];
        [system_box addSubview:line2];
        
        auto model_title = CreateStockTF();
        [model_title setStringValue:@"Mac Model:"];
        [model_title setFont: text_font];
        [system_box addSubview:model_title];
        
        auto computer_title = CreateStockTF();
        [computer_title setStringValue:@"Computer Name:"];
        [computer_title setFont: text_font];
        [system_box addSubview:computer_title];
        
        auto user_title = CreateStockTF();
        [user_title setStringValue:@"User Name:"];
        [user_title setFont: text_font];
        [system_box addSubview:user_title];
        
        m_TextMachineModel = CreateStockTF();
        [m_TextMachineModel setFont: text_font];
        [system_box addSubview:m_TextMachineModel];
    
        m_TextComputerName = CreateStockTF();
        [m_TextComputerName setFont: text_font];
        [system_box addSubview:m_TextComputerName];
    
        m_TextUserName = CreateStockTF();
        [m_TextUserName setFont: text_font];
        [system_box addSubview:m_TextUserName];
        
        NSDictionary *system_box_views = NSDictionaryOfVariableBindings(m_TextMachineModel, m_TextComputerName, m_TextUserName, line1, line2, model_title, computer_title, user_title);
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextMachineModel]-(==8)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextComputerName]-(==8)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextUserName]-(==8)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[model_title]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[computer_title]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[user_title]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line1]-(==1)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line2]-(==1)-|" options:0 metrics:nil views:system_box_views]];

        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[model_title]-(<=1)-[line1(==1)]-(==7)-[computer_title]-(<=1)-[line2(==1)]-(==7)-[user_title]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextMachineModel]-(<=1)-[line1]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextComputerName]-(<=1)-[line2]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[line2]-(==7)-[m_TextUserName]" options:0 metrics:nil views:system_box_views]];
    }
    
    ////////////////////////////////////////////////////////////////////////////////// SYSTEM
    NSBox *storage_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        [storage_box setTranslatesAutoresizingMaskIntoConstraints:NO];
        [storage_box setTitlePosition:NSAtTop];
        [storage_box setContentViewMargins:{2, 2}];
        [storage_box setBorderType:NSLineBorder];
        [storage_box setTitle:@"Storage"];
        [self addSubview:storage_box];
    
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        [line1 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line1 setBoxType:NSBoxCustom];
        [line1 setBorderColor:box_sep_color];
        [storage_box addSubview:line1];
        
        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        [line2 setTranslatesAutoresizingMaskIntoConstraints:NO];
        [line2 setBoxType:NSBoxCustom];
        [line2 setBorderColor:box_sep_color ];
        [storage_box addSubview:line2];
        
        auto vol_title = CreateStockTF();
        [vol_title setStringValue:@"Volume Name:"];
        [vol_title setFont: text_font];
        [storage_box addSubview:vol_title];
        
        auto bytes_title = CreateStockTF();
        [bytes_title setStringValue:@"Total Bytes:"];
        [bytes_title setFont: text_font];
        [storage_box addSubview:bytes_title];
        
        auto free_title = CreateStockTF();
        [free_title setStringValue:@"Free Bytes:"];
        [free_title setFont: text_font];
        [storage_box addSubview:free_title];
        
        m_TextVolumeName = CreateStockTF();
        [m_TextUserName setFont: text_font];
        [storage_box addSubview:m_TextVolumeName];
    
        m_TextVolumeTotalBytes = CreateStockTF();
        [m_TextUserName setFont: text_font];
        [storage_box addSubview:m_TextVolumeTotalBytes];
    
        m_TextVolumeAvailBytes = CreateStockTF();
        [m_TextUserName setFont: text_font];
        [storage_box addSubview:m_TextVolumeAvailBytes];
    
        NSDictionary *storage_views = NSDictionaryOfVariableBindings(line1, line2, vol_title, bytes_title, free_title, m_TextVolumeName, m_TextVolumeTotalBytes, m_TextVolumeAvailBytes);
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextVolumeName]-(==8)-|" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextVolumeTotalBytes]-(==8)-|" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_TextVolumeAvailBytes]-(==8)-|" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[vol_title]" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[bytes_title]" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[free_title]" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line1]-(==1)-|" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line2]-(==1)-|" options:0 metrics:nil views:storage_views]];

        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[vol_title]-(<=1)-[line1(==1)]-(==7)-[bytes_title]-(<=1)-[line2(==1)]-(==7)-[free_title]" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextVolumeName]-(<=1)-[line1]" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextVolumeTotalBytes]-(<=1)-[line2]" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[line2]-(==7)-[m_TextVolumeAvailBytes]" options:0 metrics:nil views:storage_views]];
    }
    
    NSDictionary *views = NSDictionaryOfVariableBindings(title, system_box, cpu_box, ram_box, storage_box);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[title]-[system_box(==90)]-[cpu_box(==90)]-[storage_box(==90)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[system_box]-[ram_box(==90)]" options:0 metrics:nil views:views]];
    if(m_IsRight) {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[title(==272)]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[system_box(==272)]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[storage_box(==272)]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[cpu_box(==128)]-(==16)-[ram_box(==128)]" options:0 metrics:nil views:views]];
    }
    else {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[title(==272)]-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[system_box(==272)]-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[storage_box(==272)]-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[cpu_box(==128)]-(==16)-[ram_box(==128)]-|" options:0 metrics:nil views:views]];
    }
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
    sysinfo::GetSystemOverview(m_Overview);

    m_StatFS = {};
    if(!m_TargetVFSPath.empty() && m_TargetVFSHost.get())
        m_TargetVFSHost->StatFS(m_TargetVFSPath.c_str(), m_StatFS, 0);
}

- (void) UpdateControls
{
    [m_TextCPULoadSystem setStringValue:[NSString stringWithFormat:@"%.2f %%", m_CPULoad.system*100.]];
    [m_TextCPULoadUser setStringValue:[NSString stringWithFormat:@"%.2f %%", m_CPULoad.user*100.]];
    [m_TextCPULoadIdle setStringValue:[NSString stringWithFormat:@"%.2f %%", m_CPULoad.idle*100.]];
    [m_TextMemTotal setStringValue:FormHumanReadableMemSize(m_MemoryInfo.total_hw)];
    [m_TextMemUsed setStringValue:FormHumanReadableMemSize(m_MemoryInfo.used)];
    [m_TextMemSwap setStringValue:FormHumanReadableMemSize(m_MemoryInfo.swap)];
    [m_TextMachineModel setStringValue:m_Overview.human_model];
    [m_TextComputerName setStringValue:m_Overview.computer_name];
    [m_TextUserName setStringValue:m_Overview.user_full_name];
    [m_TextVolumeName setStringValue:[NSString stringWithUTF8String:m_StatFS.volume_name.c_str()]];
    [m_TextVolumeTotalBytes setIntegerValue:m_StatFS.total_bytes];
    [m_TextVolumeAvailBytes setIntegerValue:m_StatFS.avail_bytes];
}

- (void) UpdateVFSTarget:(const char*)_path host:(std::shared_ptr<VFSHost>)_host
{
    m_TargetVFSPath = _path;
    m_TargetVFSHost = _host;

    // update only curresponding statistics to avoid user confusinion on non-regular updates when traversing in /Volumes
    m_StatFS = {};
    if(!m_TargetVFSPath.empty() && m_TargetVFSHost.get())
        m_TargetVFSHost->StatFS(m_TargetVFSPath.c_str(), m_StatFS, 0);

    [self UpdateControls];
}

@end
