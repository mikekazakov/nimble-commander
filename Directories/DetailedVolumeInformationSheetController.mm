//
//  DetailedVolumeInformationSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "DetailedVolumeInformationSheetController.h"
#include "filesysinfo.h"
#include "Common.h"

@implementation DetailedVolumeInformationSheetController
{
    char                          m_Root[MAXPATHLEN];
    VolumeCapabilitiesInformation m_Capabilities;
    VolumeAttributesInformation   m_Attributes;
    NSTimer                      *m_UpdateTimer;
}

- (id)init {
    self = [super initWithWindowNibName:@"DetailedVolumeInformationSheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self PopulateControls];
    [[self window] setDefaultButtonCell:[[self OkButton] cell]];
    
    m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval: 1 // 1 sec update
                                                         target:self
                                                       selector:@selector(UpdateByTimer:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)ShowSheet: (NSWindow *)_window destpath: (const char*)_path
{
    if(FetchFileSystemRootFromPath(_path, m_Root) != 0)
        return;
    if(FetchVolumeCapabilitiesInformation(m_Root, &m_Capabilities) != 0)
        return;
    if(FetchVolumeAttributesInformation(m_Root, &m_Capabilities, &m_Attributes) != 0)
        return;

    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
         contextInfo: nil];
    self.ME = self;
}

- (void) PopulateControls
{
    [[self NameTextField] setStringValue:[NSString stringWithUTF8String:m_Attributes.name]];
    [[self MountedAtTextField] setStringValue:[NSString stringWithUTF8String:m_Attributes.mount_point]];
    [[self DeviceTextField] setStringValue:[NSString stringWithUTF8String:m_Attributes.mounted_device]];
    [[self FormatTextField] setStringValue:[NSString stringWithUTF8String:m_Attributes.fs_type_verb]];
    [[self TotalBytesTextField] setIntegerValue:m_Attributes.size];
    [[self FreeBytesTextField] setIntegerValue:m_Attributes.space_free];
    [[self AvailableBytesTextField] setIntegerValue:m_Attributes.space_avail];
    [[self UsedBytesTextField] setIntegerValue:(m_Attributes.size - m_Attributes.space_free)];
    if(m_Capabilities.attr.vol.obj_count[0]) [[self ObjectsCountTextField] setIntegerValue:m_Attributes.obj_count];
    else                                     [[self ObjectsCountTextField] setStringValue:@"N/A"];
    if(m_Capabilities.attr.vol.file_count[0])[[self FileCountTextField] setIntegerValue:m_Attributes.file_count];
    else                                     [[self FileCountTextField] setStringValue:@"N/A"];
    if(m_Capabilities.attr.vol.dir_count[0]) [[self FoldersCountTextField] setIntegerValue:m_Attributes.dir_count];
    else                                     [[self FoldersCountTextField] setStringValue:@"N/A"];
    if(m_Capabilities.attr.vol.max_obj_count[0]) [[self MaxObjectsTextField] setIntegerValue:m_Attributes.max_obj_count];
    else                                         [[self MaxObjectsTextField] setStringValue:@"N/A"];
    if(m_Capabilities.attr.vol.io_block_size[0]) [[self IOBlockSizeTextField] setIntegerValue:m_Attributes.io_block_size];
    else                                         [[self IOBlockSizeTextField] setStringValue:@"N/A"];
    if(m_Capabilities.attr.vol.min_allocation[0]) [[self MinAllocationTextField] setIntegerValue:m_Attributes.min_allocation];
    else                                          [[self MinAllocationTextField] setStringValue:@"N/A"];
    if(m_Capabilities.attr.vol.allocation_clump[0]) [[self AllocationClumpTextField] setIntegerValue:m_Attributes.allocation_clump];
    else                                            [[self AllocationClumpTextField] setStringValue:@"N/A"];
}

- (IBAction)OnOK:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::OK];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    self.ME = nil; // let ARC do it's duty
}
@end
