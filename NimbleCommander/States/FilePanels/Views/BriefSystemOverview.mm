// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BriefSystemOverview.h"
#include <Utility/SystemInformation.h>
#include <Utility/NSTimer+Tolerance.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

static NSTextField *CreateStockTF()
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
    nc::utility::MemoryInfo m_MemoryInfo;
    nc::utility::CPULoad    m_CPULoad;
    nc::utility::SystemOverview m_Overview;
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
    NSNumberFormatter            *m_BytesFormatter;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_BytesFormatter = [NSNumberFormatter new];
        [m_BytesFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        m_IsRight = true;
        memset(&m_MemoryInfo, 0, sizeof(m_MemoryInfo));
        memset(&m_CPULoad, 0, sizeof(m_CPULoad));

        [self UpdateData];
        [self CreateControls];
        [self UpdateControls];
        
        m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval:2. // 2 sec update
                                                         target:self
                                                       selector:@selector(UpdateByTimer:)
                                                       userInfo:nil
                                                        repeats:YES];
        [m_UpdateTimer setDefaultTolerance];
        self.wantsLayer = true;
    }
    return self;
}

- (BOOL) isOpaque
{
    return YES;
}

- (BOOL) canDrawSubviewsIntoLayer
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

    [NSColor.windowBackgroundColor set];
    NSRectFill(dirtyRect);
    
    [self UpdateAlignment];
}

- (void) UpdateAlignment
{
    bool was_right = m_IsRight;
    if(auto *s = objc_cast<NSSplitView>(self.superview)) {
        NSArray *v = [s subviews];
        unsigned long ind = [v indexOfObject:self];
        if(ind == 0)
            m_IsRight = false;
        else if(ind == 1)
            m_IsRight = true;
    }
    if(m_IsRight != was_right)
        dispatch_to_main_queue([=]{
            [self CreateControls];
            [self UpdateControls];
            [self setNeedsDisplay];
        });
}

- (void)viewDidMoveToSuperview
{
    if(self.superview == nil)
        [m_UpdateTimer invalidate];
}

- (void) CreateControls
{
    const auto text_font = [NSFont labelFontOfSize:11];
    const auto digits_font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
 
    // clear current layout
    while ([self.subviews count] > 0)
        [[self.subviews lastObject] removeFromSuperview];
    
    ////////////////////////////////////////////////////////////////////////////////// Title
    NSTextField *title = CreateStockTF();
    title.stringValue = NSLocalizedString(@"Brief System Information", "Brief System Information overlay title");
    title.alignment = NSCenterTextAlignment;
    title.font = [NSFont boldSystemFontOfSize:13];
    [self addSubview:title];
    
    ////////////////////////////////////////////////////////////////////////////////// CPU
    NSBox *cpu_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        cpu_box.translatesAutoresizingMaskIntoConstraints = NO;
        cpu_box.titlePosition = NSAtTop;
        cpu_box.contentViewMargins = {2, 2};
        cpu_box.borderType = NSLineBorder;
        cpu_box.title = NSLocalizedString(@"CPU", "Brief System Information cpu box title");
        [self addSubview:cpu_box];
        
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        line1.translatesAutoresizingMaskIntoConstraints = NO;
        line1.boxType = NSBoxCustom;
        line1.borderColor = NSColor.gridColor;
        [cpu_box addSubview:line1];

        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        line2.translatesAutoresizingMaskIntoConstraints = NO;
        line2.boxType = NSBoxCustom;
        line2.borderColor = NSColor.gridColor;
        [cpu_box addSubview:line2];
        
        auto cpu_sysload_title = CreateStockTF();
        cpu_sysload_title.stringValue = NSLocalizedString(@"System:", "Brief System Information system label title");
        cpu_sysload_title.font = text_font;
        [cpu_box addSubview:cpu_sysload_title];

        auto cpu_usrload_title = CreateStockTF();
        cpu_usrload_title.stringValue = NSLocalizedString(@"User:", "Brief System Information user label title");
        cpu_usrload_title.font = text_font;
        [cpu_box addSubview:cpu_usrload_title];

        auto cpu_idle_title = CreateStockTF();
        cpu_idle_title.stringValue = NSLocalizedString(@"Idle:", "Brief System Information idle label title");
        cpu_idle_title.font = text_font;
        [cpu_box addSubview:cpu_idle_title];

        m_TextCPULoadSystem = CreateStockTF();
        m_TextCPULoadSystem.alignment = NSRightTextAlignment;
        m_TextCPULoadSystem.font = digits_font;
        m_TextCPULoadSystem.textColor = [NSColor colorWithCalibratedRed:1.00 green:0.15 blue:0.10 alpha:1.0];
        [cpu_box addSubview:m_TextCPULoadSystem];
    
        m_TextCPULoadUser = CreateStockTF();
        m_TextCPULoadUser.alignment = NSRightTextAlignment;
        m_TextCPULoadUser.font = digits_font;
        m_TextCPULoadUser.textColor = [NSColor colorWithCalibratedRed:0.10 green:0.15 blue:1.00 alpha:1.0];
        [cpu_box addSubview:m_TextCPULoadUser];
    
        m_TextCPULoadIdle = CreateStockTF();
        m_TextCPULoadIdle.alignment = NSRightTextAlignment;
        m_TextCPULoadIdle.font = digits_font;
        [cpu_box addSubview:m_TextCPULoadIdle];
    
        NSDictionary *cpu_box_views = NSDictionaryOfVariableBindings(m_TextCPULoadSystem, m_TextCPULoadUser, m_TextCPULoadIdle, cpu_sysload_title, cpu_usrload_title, cpu_idle_title, line1, line2);
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[cpu_sysload_title]-(==8)-[m_TextCPULoadSystem(>=60)]-(==8)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[cpu_usrload_title]-(==8)-[m_TextCPULoadUser(>=60)]-(==8)-|" options:0 metrics:nil views:cpu_box_views]];
        [cpu_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[cpu_idle_title]-(==8)-[m_TextCPULoadIdle(>=60)]-(==8)-|" options:0 metrics:nil views:cpu_box_views]];
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
        ram_box.translatesAutoresizingMaskIntoConstraints = NO;
        ram_box.titlePosition = NSAtTop;
        ram_box.contentViewMargins = {2, 2};
        ram_box.borderType = NSLineBorder;
        ram_box.title = NSLocalizedString(@"RAM", "Brief System Information ram box title");
        [self addSubview:ram_box];
    
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        line1.translatesAutoresizingMaskIntoConstraints = NO;
        line1.boxType = NSBoxCustom;
        line1.borderColor = NSColor.gridColor;
        [ram_box addSubview:line1];
        
        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        line2.translatesAutoresizingMaskIntoConstraints = NO;
        line2.boxType = NSBoxCustom;
        line2.borderColor = NSColor.gridColor;
        [ram_box addSubview:line2];
        
        auto ram_total_title = CreateStockTF();
        ram_total_title.stringValue = NSLocalizedString(@"Total:", "Brief System Information total label title");
        ram_total_title.font = text_font;
        [ram_box addSubview:ram_total_title];

        auto ram_used_title = CreateStockTF();
        ram_used_title.stringValue = NSLocalizedString(@"Used:", "Brief System Information used label title");
        ram_used_title.font = text_font;
        [ram_box addSubview:ram_used_title];

        auto ram_swap_title = CreateStockTF();
        ram_swap_title.stringValue = NSLocalizedString(@"Swap:", "Brief System Information swap label title");
        ram_swap_title.font = text_font;
        [ram_box addSubview:ram_swap_title];
    
        m_TextMemTotal = CreateStockTF();
        m_TextMemTotal.alignment = NSRightTextAlignment;
        m_TextMemTotal.font = digits_font;
        [ram_box addSubview:m_TextMemTotal];

        m_TextMemUsed = CreateStockTF();
        m_TextMemUsed.alignment = NSRightTextAlignment;
        m_TextMemUsed.font = digits_font;
        [ram_box addSubview:m_TextMemUsed];

        m_TextMemSwap = CreateStockTF();
        m_TextMemSwap.alignment = NSRightTextAlignment;
        m_TextMemSwap.font = digits_font;
        [ram_box addSubview:m_TextMemSwap];
    
        NSDictionary *ram_box_views = NSDictionaryOfVariableBindings(m_TextMemTotal, m_TextMemUsed, m_TextMemSwap, ram_total_title, ram_used_title, ram_swap_title, line1, line2);
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[ram_total_title]-(==8)-[m_TextMemTotal]-(==8)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[ram_used_title]-(==8)-[m_TextMemUsed]-(==8)-|" options:0 metrics:nil views:ram_box_views]];
        [ram_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[ram_swap_title]-(==8)-[m_TextMemSwap]-(==8)-|" options:0 metrics:nil views:ram_box_views]];
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
        system_box.translatesAutoresizingMaskIntoConstraints = NO;
        system_box.titlePosition = NSAtTop;
        system_box.contentViewMargins = {2, 2};
        system_box.borderType = NSLineBorder;
        system_box.title = NSLocalizedString(@"General", "Brief System Information general box title");
        [self addSubview:system_box];
    
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        line1.translatesAutoresizingMaskIntoConstraints = NO;
        line1.boxType = NSBoxCustom;
        line1.borderColor = NSColor.gridColor;
        [system_box addSubview:line1];
        
        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        line2.translatesAutoresizingMaskIntoConstraints = NO;
        line2.boxType = NSBoxCustom;
        line2.borderColor = NSColor.gridColor;
        [system_box addSubview:line2];
        
        auto model_title = CreateStockTF();
        model_title.stringValue = NSLocalizedString(@"Mac Model:", "Brief System Information mac model label title");
        model_title.font = text_font;
        [system_box addSubview:model_title];
        
        auto computer_title = CreateStockTF();
        computer_title.stringValue = NSLocalizedString(@"Computer Name:", "Brief System Information computer name label title");
        computer_title.font = text_font;
        [system_box addSubview:computer_title];
        
        auto user_title = CreateStockTF();
        user_title.stringValue = NSLocalizedString(@"User Name:", "Brief System Information user name label title");
        user_title.font = text_font;
        [system_box addSubview:user_title];
        
        m_TextMachineModel = CreateStockTF();
        m_TextMachineModel.alignment = NSRightTextAlignment;
        m_TextMachineModel.font = text_font;
        [system_box addSubview:m_TextMachineModel];
    
        m_TextComputerName = CreateStockTF();
        m_TextComputerName.alignment = NSRightTextAlignment;
        m_TextComputerName.font = text_font;
        [system_box addSubview:m_TextComputerName];
    
        m_TextUserName = CreateStockTF();
        m_TextUserName.alignment = NSRightTextAlignment;
        m_TextUserName.font = text_font;
        [system_box addSubview:m_TextUserName];
        
        NSDictionary *system_box_views = NSDictionaryOfVariableBindings(m_TextMachineModel, m_TextComputerName, m_TextUserName, line1, line2, model_title, computer_title, user_title);
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[model_title]-(==8)-[m_TextMachineModel]-(==8)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[computer_title]-(==8)-[m_TextComputerName]-(==8)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[user_title]-(==8)-[m_TextUserName]-(==8)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line1]-(==1)-|" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==1)-[line2]-(==1)-|" options:0 metrics:nil views:system_box_views]];

        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[model_title]-(<=1)-[line1(==1)]-(==7)-[computer_title]-(<=1)-[line2(==1)]-(==7)-[user_title]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextMachineModel]-(<=1)-[line1]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_TextComputerName]-(<=1)-[line2]" options:0 metrics:nil views:system_box_views]];
        [system_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[line2]-(==7)-[m_TextUserName]" options:0 metrics:nil views:system_box_views]];
    }
    
    ////////////////////////////////////////////////////////////////////////////////// STORAGE
    NSBox *storage_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        storage_box.translatesAutoresizingMaskIntoConstraints = NO;
        storage_box.titlePosition = NSAtTop;
        storage_box.contentViewMargins = {2, 2};
        storage_box.borderType = NSLineBorder;
        storage_box.title = NSLocalizedString(@"Storage", "Brief System Information storage box title");
        [self addSubview:storage_box];
    
        NSBox *line1 = [[NSBox alloc] initWithFrame:NSRect()];
        line1.translatesAutoresizingMaskIntoConstraints = NO;
        line1.boxType = NSBoxCustom;
        line1.borderColor = NSColor.gridColor;
        [storage_box addSubview:line1];
        
        NSBox *line2 = [[NSBox alloc] initWithFrame:NSRect()];
        line2.translatesAutoresizingMaskIntoConstraints = NO;
        line2.boxType = NSBoxCustom;
        line2.borderColor = NSColor.gridColor;
        [storage_box addSubview:line2];
        
        auto vol_title = CreateStockTF();
        vol_title.stringValue = NSLocalizedString(@"Volume Name:", "Brief System Information volume name label title");
        vol_title.font = text_font;
        [storage_box addSubview:vol_title];
        
        auto bytes_title = CreateStockTF();
        bytes_title.stringValue = NSLocalizedString(@"Total Bytes:", "Brief System Information total bytes label title");
        bytes_title.font = text_font;
        [storage_box addSubview:bytes_title];
        
        auto free_title = CreateStockTF();
        free_title.stringValue = NSLocalizedString(@"Free Bytes:", "Brief System Information free bytes label title");
        free_title.font = text_font;
        [storage_box addSubview:free_title];
        
        m_TextVolumeName = CreateStockTF();
        m_TextVolumeName.alignment = NSRightTextAlignment;
        m_TextVolumeName.font = text_font;
        [storage_box addSubview:m_TextVolumeName];
    
        m_TextVolumeTotalBytes = CreateStockTF();
        m_TextVolumeTotalBytes.alignment = NSRightTextAlignment;
        m_TextVolumeTotalBytes.font = digits_font;
        [storage_box addSubview:m_TextVolumeTotalBytes];
    
        m_TextVolumeAvailBytes = CreateStockTF();
        m_TextVolumeAvailBytes.alignment = NSRightTextAlignment;
        m_TextVolumeAvailBytes.font = digits_font;
        [storage_box addSubview:m_TextVolumeAvailBytes];
    
        NSDictionary *storage_views = NSDictionaryOfVariableBindings(line1, line2, vol_title, bytes_title, free_title, m_TextVolumeName, m_TextVolumeTotalBytes, m_TextVolumeAvailBytes);
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[vol_title]-(==8)-[m_TextVolumeName]-(==8)-|" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[bytes_title]-(==8)-[m_TextVolumeTotalBytes]-(==8)-|" options:0 metrics:nil views:storage_views]];
        [storage_box addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==8)-[free_title]-(==8)-[m_TextVolumeAvailBytes]-(==8)-|" options:0 metrics:nil views:storage_views]];
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
    [self addConstraint:[NSLayoutConstraint constraintWithItem:system_box attribute:NSLayoutAttributeLeading
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:cpu_box
                                                     attribute:NSLayoutAttributeLeading
                                                    multiplier:1
                                                      constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:system_box
                                                     attribute:NSLayoutAttributeLeading
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:storage_box
                                                     attribute:NSLayoutAttributeLeading
                                                    multiplier:1
                                                      constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:system_box
                                                     attribute:NSLayoutAttributeTrailing
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:ram_box
                                                     attribute:NSLayoutAttributeTrailing
                                                    multiplier:1
                                                      constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:system_box
                                                     attribute:NSLayoutAttributeTrailing
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:storage_box
                                                     attribute:NSLayoutAttributeTrailing
                                                    multiplier:1
                                                      constant:0]];
    if(m_IsRight) {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[title(>=272)]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[system_box(>=272)]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[storage_box(>=272)]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[cpu_box(>=128)]-(==16)-[ram_box(>=128)]" options:0 metrics:nil views:views]];
    }
    else {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[title(>=272)]-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[system_box(>=272)]-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[storage_box(>=272)]-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[cpu_box(>=128)]-(==16)-[ram_box(>=128)]-|" options:0 metrics:nil views:views]];
    }
}

- (void) UpdateByTimer:(NSTimer*)[[maybe_unused]]_the_timer
{
    [self UpdateData];
    [self UpdateControls];
}

- (void) UpdateData
{
    nc::utility::GetMemoryInfo(m_MemoryInfo);
    nc::utility::GetCPULoad(m_CPULoad);
    nc::utility::GetSystemOverview(m_Overview);

    m_StatFS = {};
    if(!m_TargetVFSPath.empty() && m_TargetVFSHost.get())
        m_TargetVFSHost->StatFS(m_TargetVFSPath.c_str(), m_StatFS, 0);
}

- (void) UpdateControls
{
    m_TextCPULoadSystem.stringValue = [NSString stringWithFormat:@"%.2f %%", m_CPULoad.system*100.];
    m_TextCPULoadUser.stringValue = [NSString stringWithFormat:@"%.2f %%", m_CPULoad.user*100.];
    m_TextCPULoadIdle.stringValue = [NSString stringWithFormat:@"%.2f %%", m_CPULoad.idle*100.];
    auto &f = ByteCountFormatter::Instance();
    m_TextMemTotal.stringValue = f.ToNSString(m_MemoryInfo.total_hw, ByteCountFormatter::Adaptive8);
    m_TextMemUsed.stringValue = f.ToNSString(m_MemoryInfo.used, ByteCountFormatter::Adaptive8);
    m_TextMemSwap.stringValue = f.ToNSString(m_MemoryInfo.swap, ByteCountFormatter::Adaptive8);
    m_TextMachineModel.stringValue = [NSString stringWithUTF8StdString:m_Overview.human_model];
    m_TextComputerName.stringValue = [NSString stringWithUTF8StdString:m_Overview.computer_name];
    m_TextUserName.stringValue = [NSString stringWithUTF8StdString:m_Overview.user_full_name];
    if(!m_StatFS.volume_name.empty())
        m_TextVolumeName.stringValue = [NSString stringWithUTF8String:m_StatFS.volume_name.c_str()];
    else
        m_TextVolumeName.stringValue = NSLocalizedString(@"N/A", "");
    
    m_TextVolumeTotalBytes.stringValue = [m_BytesFormatter stringFromNumber:[NSNumber numberWithLong:m_StatFS.total_bytes]];
    m_TextVolumeAvailBytes.stringValue = [m_BytesFormatter stringFromNumber:[NSNumber numberWithLong:m_StatFS.avail_bytes]];
}

- (void) UpdateVFSTarget:(const std::string&)_path host:(std::shared_ptr<VFSHost>)_host
{
    if( m_TargetVFSHost == _host && m_TargetVFSPath == _path )
        return;
    
    // TODO: need to prevent inefficient updates here when volume remains the same. (?)
    
    m_TargetVFSPath = _path;
    m_TargetVFSHost = _host;

    // update only curresponding statistics to avoid user confusinion on non-regular updates when traversing in /Volumes
    m_StatFS = {};
    if(!m_TargetVFSPath.empty() && m_TargetVFSHost.get())
        m_TargetVFSHost->StatFS(m_TargetVFSPath.c_str(), m_StatFS, 0);

    [self UpdateControls];
}

@end
