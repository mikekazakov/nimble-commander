// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

@implementation BriefSystemOverview {
    nc::utility::MemoryInfo m_MemoryInfo;
    nc::utility::CPULoad m_CPULoad;
    nc::utility::SystemOverview m_Overview;
    std::chrono::seconds m_Uptime;
    VFSStatFS m_StatFS;

    // controls
    NSTextField *m_TextCPULoadSystem;
    NSTextField *m_TextCPULoadUser;
    NSTextField *m_TextCPULoadIdle;
    NSTextField *m_TextCPULoadHistory;
    NSTextField *m_TextCPUThreads;
    NSTextField *m_TextCPUProcesses;
    NSTextField *m_TextCPUUptime;

    NSTextField *m_TextMemTotal;
    NSTextField *m_TextMemUsed;
    NSTextField *m_TextMemSwap;
    NSTextField *m_TextMemApp;
    NSTextField *m_TextMemWired;
    NSTextField *m_TextMemCompressed;
    NSTextField *m_TextMemCache;

    NSTextField *m_TextMachineModel;
    NSTextField *m_TextComputerName;
    NSTextField *m_TextUserName;

    NSTextField *m_TextVolumeName;
    NSTextField *m_TextVolumeTotalBytes;
    NSTextField *m_TextVolumeAvailBytes;

    std::string m_TargetVFSPath;
    std::shared_ptr<VFSHost> m_TargetVFSHost;
    bool m_IsRight;
    NSTimer *m_UpdateTimer;
    NSNumberFormatter *m_BytesFormatter;
    NSDateComponentsFormatter *m_UptimeFormatter;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if( self ) {
        m_BytesFormatter = [NSNumberFormatter new];
        m_BytesFormatter.numberStyle = NSNumberFormatterDecimalStyle;

        m_UptimeFormatter = [NSDateComponentsFormatter new];
        m_UptimeFormatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
        m_UptimeFormatter.allowsFractionalUnits = false;
        m_UptimeFormatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
        m_UptimeFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropLeading;

        m_IsRight = true;
        memset(&m_MemoryInfo, 0, sizeof(m_MemoryInfo));
        memset(&m_CPULoad, 0, sizeof(m_CPULoad));
        m_Uptime = {};

        [self updateData];
        [self createControls];
        [self updateControls];

        m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval:2. // 2 sec update
                                                         target:self
                                                       selector:@selector(updateByTimer:)
                                                       userInfo:nil
                                                        repeats:YES];
        [m_UpdateTimer setDefaultTolerance];
        self.wantsLayer = true;
    }
    return self;
}

- (BOOL)isOpaque
{
    return YES;
}

- (BOOL)canDrawSubviewsIntoLayer
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    [NSColor.windowBackgroundColor set];
    NSRectFill(dirtyRect);
}

- (void)viewDidMoveToSuperview
{
    if( self.superview == nil )
        [m_UpdateTimer invalidate];
}

- (void)createControls
{
    const auto text_font = [NSFont labelFontOfSize:11];
    const auto digits_font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    const auto tf_right_aligned_for_digits = [digits_font] {
        auto tf = CreateStockTF();
        tf.alignment = NSTextAlignmentRight;
        tf.font = digits_font;
        return tf;
    };
    const auto tf_for_text = [text_font] {
        auto tf = CreateStockTF();
        tf.font = text_font;
        return tf;
    };
    const auto line_separator = [] {
        NSBox *const line = [[NSBox alloc] initWithFrame:NSRect()];
        line.translatesAutoresizingMaskIntoConstraints = NO;
        line.boxType = NSBoxCustom;
        line.borderColor = NSColor.separatorColor;
        return line;
    };

    // clear current layout
    while( [self.subviews count] > 0 )
        [[self.subviews lastObject] removeFromSuperview];

    ////////////////////////////////////////////////////////////////////////////////// Title
    NSTextField *title = CreateStockTF();
    title.stringValue = NSLocalizedString(@"Brief System Information", "Brief System Information overlay title");
    title.alignment = NSTextAlignmentCenter;
    title.font = [NSFont boldSystemFontOfSize:13];
    [self addSubview:title];

    ////////////////////////////////////////////////////////////////////////////////// CPU
    NSBox *cpu_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        cpu_box.translatesAutoresizingMaskIntoConstraints = NO;
        cpu_box.titlePosition = NSAtTop;
        cpu_box.contentViewMargins = {2, 2};
        cpu_box.title = NSLocalizedString(@"CPU", "Brief System Information cpu box title");
        [self addSubview:cpu_box];

        NSBox *line1 = line_separator();
        [cpu_box addSubview:line1];

        NSBox *line2 = line_separator();
        [cpu_box addSubview:line2];

        NSBox *line3 = line_separator();
        [cpu_box addSubview:line3];

        NSBox *line4 = line_separator();
        [cpu_box addSubview:line4];

        NSBox *line5 = line_separator();
        [cpu_box addSubview:line5];

        NSBox *line6 = line_separator();
        [cpu_box addSubview:line6];

        auto cpu_sysload_title = tf_for_text();
        cpu_sysload_title.stringValue = NSLocalizedString(@"System:", "Brief System Information system label title");
        [cpu_box addSubview:cpu_sysload_title];

        auto cpu_usrload_title = tf_for_text();
        cpu_usrload_title.stringValue = NSLocalizedString(@"User:", "Brief System Information user label title");
        [cpu_box addSubview:cpu_usrload_title];

        auto cpu_idle_title = tf_for_text();
        cpu_idle_title.stringValue = NSLocalizedString(@"Idle:", "Brief System Information idle label title");
        [cpu_box addSubview:cpu_idle_title];

        auto cpu_load_title = tf_for_text();
        cpu_load_title.stringValue = NSLocalizedString(@"Load:", "Brief System Information load label title");
        [cpu_box addSubview:cpu_load_title];

        auto cpu_threads_title = tf_for_text();
        cpu_threads_title.stringValue = NSLocalizedString(@"Threads:", "Brief System Information threads label title");
        [cpu_box addSubview:cpu_threads_title];

        auto cpu_processes_title = tf_for_text();
        cpu_processes_title.stringValue =
            NSLocalizedString(@"Processes:", "Brief System Information processes label title");
        [cpu_box addSubview:cpu_processes_title];

        auto cpu_uptime_title = tf_for_text();
        cpu_uptime_title.stringValue = NSLocalizedString(@"Uptime:", "Brief System Information uptime label title");
        [cpu_box addSubview:cpu_uptime_title];

        m_TextCPULoadSystem = tf_right_aligned_for_digits();
        m_TextCPULoadSystem.textColor = NSColor.systemRedColor;
        [cpu_box addSubview:m_TextCPULoadSystem];

        m_TextCPULoadUser = tf_right_aligned_for_digits();
        m_TextCPULoadUser.textColor = NSColor.systemBlueColor;
        [cpu_box addSubview:m_TextCPULoadUser];

        m_TextCPULoadIdle = tf_right_aligned_for_digits();
        [cpu_box addSubview:m_TextCPULoadIdle];

        m_TextCPULoadHistory = tf_right_aligned_for_digits();
        [cpu_box addSubview:m_TextCPULoadHistory];

        m_TextCPUThreads = tf_right_aligned_for_digits();
        [cpu_box addSubview:m_TextCPUThreads];

        m_TextCPUProcesses = tf_right_aligned_for_digits();
        [cpu_box addSubview:m_TextCPUProcesses];

        m_TextCPUUptime = tf_right_aligned_for_digits();
        [cpu_box addSubview:m_TextCPUUptime];

        NSDictionary *cpu_box_views = NSDictionaryOfVariableBindings(m_TextCPULoadSystem,
                                                                     m_TextCPULoadUser,
                                                                     m_TextCPULoadIdle,
                                                                     m_TextCPULoadHistory,
                                                                     m_TextCPUThreads,
                                                                     m_TextCPUProcesses,
                                                                     m_TextCPUUptime,
                                                                     cpu_sysload_title,
                                                                     cpu_usrload_title,
                                                                     cpu_idle_title,
                                                                     cpu_load_title,
                                                                     cpu_threads_title,
                                                                     cpu_processes_title,
                                                                     cpu_uptime_title,
                                                                     line1,
                                                                     line2,
                                                                     line3,
                                                                     line4,
                                                                     line5,
                                                                     line6);
        auto vis_fmt = [cpu_box, cpu_box_views](NSString *_format) {
            auto csts = [NSLayoutConstraint constraintsWithVisualFormat:_format
                                                                options:0
                                                                metrics:nil
                                                                  views:cpu_box_views];
            [cpu_box addConstraints:csts];
        };
        vis_fmt(@"|-(==8)-[cpu_sysload_title]-(==8)-[m_TextCPULoadSystem(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[cpu_usrload_title]-(==8)-[m_TextCPULoadUser(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[cpu_idle_title]-(==8)-[m_TextCPULoadIdle(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[cpu_load_title]-(==8)-[m_TextCPULoadHistory(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[cpu_threads_title]-(==8)-[m_TextCPUThreads(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[cpu_processes_title]-(==8)-[m_TextCPUProcesses(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[cpu_uptime_title]-(==8)-[m_TextCPUUptime(>=60)]-(==8)-|");
        vis_fmt(@"|-(==8)-[line1]-(==8)-|");
        vis_fmt(@"|-(==8)-[line2]-(==8)-|");
        vis_fmt(@"|-(==8)-[line3]-(==8)-|");
        vis_fmt(@"|-(==8)-[line4]-(==8)-|");
        vis_fmt(@"|-(==8)-[line5]-(==8)-|");
        vis_fmt(@"|-(==8)-[line6]-(==8)-|");
        vis_fmt(@"V:|-(==8)-"
                @"[cpu_sysload_title]-(==4)-[line1(==1)]-(==5)-"
                @"[cpu_usrload_title]-(==4)-[line2(==1)]-(==5)-"
                @"[cpu_idle_title]-(==4)-[line3(==1)]-(==5)-"
                @"[cpu_load_title]-(==4)-[line4(==1)]-(==5)-"
                @"[cpu_threads_title]-(==4)-[line5(==1)]-(==5)-"
                @"[cpu_processes_title]-(==4)-[line6(==1)]-(==5)-"
                @"[cpu_uptime_title]");
        vis_fmt(@"V:[m_TextCPULoadSystem]-(==4)-[line1]");
        vis_fmt(@"V:[m_TextCPULoadUser]-(==4)-[line2]");
        vis_fmt(@"V:[m_TextCPULoadIdle]-(==4)-[line3]");
        vis_fmt(@"V:[m_TextCPULoadHistory]-(==4)-[line4]");
        vis_fmt(@"V:[m_TextCPUThreads]-(==4)-[line5]");
        vis_fmt(@"V:[m_TextCPUProcesses]-(==4)-[line6]");
        vis_fmt(@"V:[line6]-(==5)-[m_TextCPUUptime]");
    }

    ////////////////////////////////////////////////////////////////////////////////// RAM
    NSBox *ram_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        ram_box.translatesAutoresizingMaskIntoConstraints = NO;
        ram_box.titlePosition = NSAtTop;
        ram_box.contentViewMargins = {2, 2};
        ram_box.title = NSLocalizedString(@"RAM", "Brief System Information ram box title");
        [self addSubview:ram_box];

        NSBox *line1 = line_separator();
        [ram_box addSubview:line1];

        NSBox *line2 = line_separator();
        [ram_box addSubview:line2];

        NSBox *line3 = line_separator();
        [ram_box addSubview:line3];

        NSBox *line4 = line_separator();
        [ram_box addSubview:line4];

        NSBox *line5 = line_separator();
        [ram_box addSubview:line5];

        NSBox *line6 = line_separator();
        [ram_box addSubview:line6];

        auto ram_total_title = tf_for_text();
        ram_total_title.stringValue = NSLocalizedString(@"Total:", "Brief System Information total label title");
        [ram_box addSubview:ram_total_title];

        auto ram_used_title = tf_for_text();
        ram_used_title.stringValue = NSLocalizedString(@"Used:", "Brief System Information used label title");
        [ram_box addSubview:ram_used_title];

        auto ram_swap_title = tf_for_text();
        ram_swap_title.stringValue = NSLocalizedString(@"Swap:", "Brief System Information swap label title");
        [ram_box addSubview:ram_swap_title];

        auto ram_app_title = tf_for_text();
        ram_app_title.stringValue = NSLocalizedString(@"App:", "Brief System Information app label title");
        [ram_box addSubview:ram_app_title];

        auto ram_wired_title = tf_for_text();
        ram_wired_title.stringValue = NSLocalizedString(@"Wired:", "Brief System Information wired label title");
        [ram_box addSubview:ram_wired_title];

        auto ram_compressed_title = tf_for_text();
        ram_compressed_title.stringValue =
            NSLocalizedString(@"Compressed:", "Brief System Information compressed label title");
        [ram_box addSubview:ram_compressed_title];

        auto ram_cache_title = tf_for_text();
        ram_cache_title.stringValue = NSLocalizedString(@"Cache:", "Brief System Information cache label title");
        [ram_box addSubview:ram_cache_title];

        m_TextMemTotal = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemTotal];

        m_TextMemUsed = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemUsed];

        m_TextMemSwap = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemSwap];

        m_TextMemApp = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemApp];

        m_TextMemWired = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemWired];

        m_TextMemCompressed = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemCompressed];

        m_TextMemCache = tf_right_aligned_for_digits();
        [ram_box addSubview:m_TextMemCache];

        NSDictionary *ram_box_views = NSDictionaryOfVariableBindings(m_TextMemTotal,
                                                                     m_TextMemUsed,
                                                                     m_TextMemSwap,
                                                                     m_TextMemApp,
                                                                     m_TextMemWired,
                                                                     m_TextMemCompressed,
                                                                     m_TextMemCache,
                                                                     ram_total_title,
                                                                     ram_used_title,
                                                                     ram_swap_title,
                                                                     ram_app_title,
                                                                     ram_wired_title,
                                                                     ram_compressed_title,
                                                                     ram_cache_title,
                                                                     line1,
                                                                     line2,
                                                                     line3,
                                                                     line4,
                                                                     line5,
                                                                     line6);
        auto vis_fmt = [ram_box, ram_box_views](NSString *_format) {
            auto csts = [NSLayoutConstraint constraintsWithVisualFormat:_format
                                                                options:0
                                                                metrics:nil
                                                                  views:ram_box_views];
            [ram_box addConstraints:csts];
        };
        vis_fmt(@"|-(==8)-[ram_total_title]-(==8)-[m_TextMemTotal]-(==8)-|");
        vis_fmt(@"|-(==8)-[ram_used_title]-(==8)-[m_TextMemUsed]-(==8)-|");
        vis_fmt(@"|-(==16)-[ram_app_title]-(==8)-[m_TextMemApp]-(==8)-|");
        vis_fmt(@"|-(==16)-[ram_wired_title]-(==8)-[m_TextMemWired]-(==8)-|");
        vis_fmt(@"|-(==16)-[ram_compressed_title]-(==8)-[m_TextMemCompressed]-(==8)-|");
        vis_fmt(@"|-(==8)-[ram_cache_title]-(==8)-[m_TextMemCache]-(==8)-|");
        vis_fmt(@"|-(==8)-[ram_swap_title]-(==8)-[m_TextMemSwap]-(==8)-|");
        vis_fmt(@"|-(==8)-[line1]-(==8)-|");
        vis_fmt(@"|-(==8)-[line2]-(==8)-|");
        vis_fmt(@"|-(==16)-[line3]-(==8)-|");
        vis_fmt(@"|-(==16)-[line4]-(==8)-|");
        vis_fmt(@"|-(==16)-[line5]-(==8)-|");
        vis_fmt(@"|-(==8)-[line6]-(==8)-|");
        vis_fmt(@"V:|-(==8)-"
                @"[ram_total_title]-(==4)-[line1(==1)]-(==5)-"
                @"[ram_used_title]-(==4)-[line2(==1)]-(==5)-"
                @"[ram_app_title]-(==4)-[line3(==1)]-(==5)-"
                @"[ram_wired_title]-(==4)-[line4(==1)]-(==5)-"
                @"[ram_compressed_title]-(==4)-[line5(==1)]-(==5)-"
                @"[ram_cache_title]-(==4)-[line6(==1)]-(==5)-"
                @"[ram_swap_title]");
        vis_fmt(@"V:[m_TextMemTotal]-(==4)-[line1]");
        vis_fmt(@"V:[m_TextMemUsed]-(==4)-[line2]");
        vis_fmt(@"V:[m_TextMemApp]-(==4)-[line3]");
        vis_fmt(@"V:[m_TextMemWired]-(==4)-[line4]");
        vis_fmt(@"V:[m_TextMemCompressed]-(==4)-[line5]");
        vis_fmt(@"V:[m_TextMemCache]-(==4)-[line6]");
        vis_fmt(@"V:[line6]-(==5)-[m_TextMemSwap]");
    }

    ////////////////////////////////////////////////////////////////////////////////// SYSTEM
    NSBox *system_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        system_box.translatesAutoresizingMaskIntoConstraints = NO;
        system_box.titlePosition = NSAtTop;
        system_box.contentViewMargins = {2, 2};
        system_box.title = NSLocalizedString(@"General", "Brief System Information general box title");
        [self addSubview:system_box];

        NSBox *line1 = line_separator();
        [system_box addSubview:line1];

        NSBox *line2 = line_separator();
        [system_box addSubview:line2];

        auto model_title = CreateStockTF();
        model_title.stringValue = NSLocalizedString(@"Mac Model:", "Brief System Information mac model label title");
        model_title.font = text_font;
        [system_box addSubview:model_title];

        auto computer_title = CreateStockTF();
        computer_title.stringValue =
            NSLocalizedString(@"Computer Name:", "Brief System Information computer name label title");
        computer_title.font = text_font;
        [system_box addSubview:computer_title];

        auto user_title = CreateStockTF();
        user_title.stringValue = NSLocalizedString(@"User Name:", "Brief System Information user name label title");
        user_title.font = text_font;
        [system_box addSubview:user_title];

        m_TextMachineModel = CreateStockTF();
        m_TextMachineModel.alignment = NSTextAlignmentRight;
        m_TextMachineModel.font = text_font;
        [system_box addSubview:m_TextMachineModel];

        m_TextComputerName = CreateStockTF();
        m_TextComputerName.alignment = NSTextAlignmentRight;
        m_TextComputerName.font = text_font;
        [system_box addSubview:m_TextComputerName];

        m_TextUserName = CreateStockTF();
        m_TextUserName.alignment = NSTextAlignmentRight;
        m_TextUserName.font = text_font;
        [system_box addSubview:m_TextUserName];

        NSDictionary *system_box_views = NSDictionaryOfVariableBindings(m_TextMachineModel,
                                                                        m_TextComputerName,
                                                                        m_TextUserName,
                                                                        line1,
                                                                        line2,
                                                                        model_title,
                                                                        computer_title,
                                                                        user_title);
        auto vis_fmt = [system_box, system_box_views](NSString *_format) {
            auto csts = [NSLayoutConstraint constraintsWithVisualFormat:_format
                                                                options:0
                                                                metrics:nil
                                                                  views:system_box_views];
            [system_box addConstraints:csts];
        };
        vis_fmt(@"|-(==8)-[model_title]-(==8)-[m_TextMachineModel]-(==8)-|");
        vis_fmt(@"|-(==8)-[computer_title]-(==8)-[m_TextComputerName]-(==8)-|");
        vis_fmt(@"|-(==8)-[user_title]-(==8)-[m_TextUserName]-(==8)-|");
        vis_fmt(@"|-(==8)-[line1]-(==8)-|");
        vis_fmt(@"|-(==8)-[line2]-(==8)-|");
        vis_fmt(@"V:|-(==8)-[model_title]-(==4)-[line1(==1)]-(==5)-[computer_title]"
                @"-(==4)-[line2(==1)]-(==5)-[user_title]");
        vis_fmt(@"V:[m_TextMachineModel]-(==4)-[line1]");
        vis_fmt(@"V:[m_TextComputerName]-(==4)-[line2]");
        vis_fmt(@"V:[line2]-(==5)-[m_TextUserName]");
    }

    ////////////////////////////////////////////////////////////////////////////////// STORAGE
    NSBox *storage_box = [[NSBox alloc] initWithFrame:NSRect()];
    {
        storage_box.translatesAutoresizingMaskIntoConstraints = NO;
        storage_box.titlePosition = NSAtTop;
        storage_box.contentViewMargins = {2, 2};
        storage_box.title = NSLocalizedString(@"Storage", "Brief System Information storage box title");
        [self addSubview:storage_box];

        NSBox *line1 = line_separator();
        [storage_box addSubview:line1];

        NSBox *line2 = line_separator();
        [storage_box addSubview:line2];

        auto vol_title = CreateStockTF();
        vol_title.stringValue = NSLocalizedString(@"Volume Name:", "Brief System Information volume name label title");
        vol_title.font = text_font;
        [storage_box addSubview:vol_title];

        auto bytes_title = CreateStockTF();
        bytes_title.stringValue =
            NSLocalizedString(@"Total Bytes:", "Brief System Information total bytes label title");
        bytes_title.font = text_font;
        [storage_box addSubview:bytes_title];

        auto free_title = CreateStockTF();
        free_title.stringValue = NSLocalizedString(@"Free Bytes:", "Brief System Information free bytes label title");
        free_title.font = text_font;
        [storage_box addSubview:free_title];

        m_TextVolumeName = CreateStockTF();
        m_TextVolumeName.alignment = NSTextAlignmentRight;
        m_TextVolumeName.font = text_font;
        [storage_box addSubview:m_TextVolumeName];

        m_TextVolumeTotalBytes = CreateStockTF();
        m_TextVolumeTotalBytes.alignment = NSTextAlignmentRight;
        m_TextVolumeTotalBytes.font = digits_font;
        [storage_box addSubview:m_TextVolumeTotalBytes];

        m_TextVolumeAvailBytes = CreateStockTF();
        m_TextVolumeAvailBytes.alignment = NSTextAlignmentRight;
        m_TextVolumeAvailBytes.font = digits_font;
        [storage_box addSubview:m_TextVolumeAvailBytes];

        NSDictionary *storage_views = NSDictionaryOfVariableBindings(line1,
                                                                     line2,
                                                                     vol_title,
                                                                     bytes_title,
                                                                     free_title,
                                                                     m_TextVolumeName,
                                                                     m_TextVolumeTotalBytes,
                                                                     m_TextVolumeAvailBytes);
        auto vis_fmt = [storage_box, storage_views](NSString *_format) {
            auto csts = [NSLayoutConstraint constraintsWithVisualFormat:_format
                                                                options:0
                                                                metrics:nil
                                                                  views:storage_views];
            [storage_box addConstraints:csts];
        };
        vis_fmt(@"|-(==8)-[vol_title]-(==8)-[m_TextVolumeName]-(==8)-|");
        vis_fmt(@"|-(==8)-[bytes_title]-(==8)-[m_TextVolumeTotalBytes]-(==8)-|");
        vis_fmt(@"|-(==8)-[free_title]-(==8)-[m_TextVolumeAvailBytes]-(==8)-|");

        vis_fmt(@"|-(==8)-[line1]-(==8)-|");
        vis_fmt(@"|-(==8)-[line2]-(==8)-|");
        vis_fmt(@"V:|-(==8)-[vol_title]-(==4)-[line1(==1)]-(==5)-["
                @"bytes_title]-(==4)-[line2(==1)]-(==5)-[free_title]");
        vis_fmt(@"V:[m_TextVolumeName]-(==4)-[line1]");
        vis_fmt(@"V:[m_TextVolumeTotalBytes]-(==4)-[line2]");
        vis_fmt(@"V:[line2]-(==5)-[m_TextVolumeAvailBytes]");
    }

    NSDictionary *views = NSDictionaryOfVariableBindings(title, system_box, cpu_box, ram_box, storage_box);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==8)-[title]-[system_box(==94)]-["
                                                                         @"cpu_box(==188)]-[storage_box(==94)]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[system_box]-[ram_box(==188)]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:system_box
                                                     attribute:NSLayoutAttributeLeading
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
    [self addConstraint:[NSLayoutConstraint constraintWithItem:cpu_box
                                                     attribute:NSLayoutAttributeWidth
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:ram_box
                                                     attribute:NSLayoutAttributeWidth
                                                    multiplier:1
                                                      constant:0]];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[title(>=272)]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[system_box(>=272)]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[storage_box(>=272)]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[cpu_box(>=128)]-(==16)-[ram_box(>=128)]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self centerViewHorizontally:title];
    [self centerViewHorizontally:system_box];
    [self centerViewHorizontally:storage_box];
}

- (void)centerViewHorizontally:(NSView *)_view
{
    [self addConstraint:[NSLayoutConstraint constraintWithItem:_view
                                                     attribute:NSLayoutAttributeCenterX
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeCenterX
                                                    multiplier:1.f
                                                      constant:0.f]];
}

- (void)updateByTimer:(NSTimer *) [[maybe_unused]] _the_timer
{
    [self updateData];
    [self updateControls];
}

- (void)updateData
{
    if( auto mem = nc::utility::GetMemoryInfo() )
        m_MemoryInfo = *mem;
    if( auto cpuload = nc::utility::GetCPULoad() )
        m_CPULoad = *cpuload;
    nc::utility::GetSystemOverview(m_Overview);
    m_Uptime = nc::utility::GetUptime();

    m_StatFS = {};
    if( !m_TargetVFSPath.empty() && m_TargetVFSHost.get() )
        m_StatFS = m_TargetVFSHost->StatFS(m_TargetVFSPath).value_or(VFSStatFS{});
}

- (void)updateControls
{
    m_TextCPULoadSystem.stringValue = [NSString stringWithFormat:@"%.2f %%", m_CPULoad.system * 100.];
    m_TextCPULoadUser.stringValue = [NSString stringWithFormat:@"%.2f %%", m_CPULoad.user * 100.];
    m_TextCPULoadIdle.stringValue = [NSString stringWithFormat:@"%.2f %%", m_CPULoad.idle * 100.];
    m_TextCPULoadHistory.stringValue =
        [NSString stringWithFormat:@"%.2f %.2f %.2f", m_CPULoad.history[0], m_CPULoad.history[1], m_CPULoad.history[2]];
    m_TextCPUThreads.stringValue = [NSString stringWithFormat:@"%d", m_CPULoad.threads];
    m_TextCPUProcesses.stringValue = [NSString stringWithFormat:@"%d", m_CPULoad.processes];
    m_TextCPUUptime.stringValue = [m_UptimeFormatter stringFromTimeInterval:static_cast<double>(m_Uptime.count())];

    auto &f = ByteCountFormatter::Instance();
    m_TextMemTotal.stringValue = f.ToNSString(m_MemoryInfo.total_hw, ByteCountFormatter::Adaptive8);
    m_TextMemUsed.stringValue = f.ToNSString(m_MemoryInfo.used, ByteCountFormatter::Adaptive8);
    m_TextMemApp.stringValue = f.ToNSString(m_MemoryInfo.applications, ByteCountFormatter::Adaptive8);
    m_TextMemWired.stringValue = f.ToNSString(m_MemoryInfo.wired, ByteCountFormatter::Adaptive8);
    m_TextMemCompressed.stringValue = f.ToNSString(m_MemoryInfo.compressed, ByteCountFormatter::Adaptive8);
    m_TextMemCache.stringValue = f.ToNSString(m_MemoryInfo.file_cache, ByteCountFormatter::Adaptive8);
    m_TextMemSwap.stringValue = f.ToNSString(m_MemoryInfo.swap, ByteCountFormatter::Adaptive8);

    m_TextMachineModel.stringValue = [NSString stringWithUTF8StdString:m_Overview.human_model];
    m_TextComputerName.stringValue = [NSString stringWithUTF8StdString:m_Overview.computer_name];
    m_TextUserName.stringValue = [NSString stringWithUTF8StdString:m_Overview.user_full_name];
    if( !m_StatFS.volume_name.empty() )
        m_TextVolumeName.stringValue = [NSString stringWithUTF8String:m_StatFS.volume_name.c_str()];
    else
        m_TextVolumeName.stringValue = NSLocalizedString(@"N/A", "");

    m_TextVolumeTotalBytes.stringValue =
        [m_BytesFormatter stringFromNumber:[NSNumber numberWithLong:m_StatFS.total_bytes]];
    m_TextVolumeAvailBytes.stringValue =
        [m_BytesFormatter stringFromNumber:[NSNumber numberWithLong:m_StatFS.avail_bytes]];
}

- (void)UpdateVFSTarget:(const std::string &)_path host:(std::shared_ptr<VFSHost>)_host
{
    if( m_TargetVFSHost == _host && m_TargetVFSPath == _path )
        return;

    // TODO: need to prevent inefficient updates here when volume remains the same. (?)

    m_TargetVFSPath = _path;
    m_TargetVFSHost = _host;

    // update only curresponding statistics to avoid user confusinion on non-regular updates when
    // traversing in /Volumes
    m_StatFS = {};
    if( !m_TargetVFSPath.empty() && m_TargetVFSHost.get() )
        m_StatFS = m_TargetVFSHost->StatFS(m_TargetVFSPath).value_or(VFSStatFS{});

    [self updateControls];
}

@end
