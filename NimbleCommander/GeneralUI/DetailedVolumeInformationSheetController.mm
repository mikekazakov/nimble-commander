// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/VolumeInformation.h>
#include <Utility/NSTimer+Tolerance.h>
#include <Utility/NativeFSManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "DetailedVolumeInformationSheetController.h"

@interface DetailedVolumeInformationSheetController ()

@property (nonatomic) IBOutlet NSButton *OkButton;
@property (nonatomic) IBOutlet NSTextField *NameTextField;
@property (nonatomic) IBOutlet NSTextField *MountedAtTextField;
@property (nonatomic) IBOutlet NSTextField *DeviceTextField;
@property (nonatomic) IBOutlet NSTextField *FormatTextField;
@property (nonatomic) IBOutlet NSTextField *TotalBytesTextField;
@property (nonatomic) IBOutlet NSTextField *FreeBytesTextField;
@property (nonatomic) IBOutlet NSTextField *AvailableBytesTextField;
@property (nonatomic) IBOutlet NSTextField *UsedBytesTextField;
@property (nonatomic) IBOutlet NSTextField *ObjectsCountTextField;
@property (nonatomic) IBOutlet NSTextField *FileCountTextField;
@property (nonatomic) IBOutlet NSTextField *FoldersCountTextField;
@property (nonatomic) IBOutlet NSTextField *MaxObjectsTextField;
@property (nonatomic) IBOutlet NSTextField *IOBlockSizeTextField;
@property (nonatomic) IBOutlet NSTextField *MinAllocationTextField;
@property (nonatomic) IBOutlet NSTextField *AllocationClumpTextField;
@property (nonatomic) IBOutlet NSTextView *AdvancedTextView;

@end


@implementation DetailedVolumeInformationSheetController
{
    string                        m_Root;
    VolumeCapabilitiesInformation m_Capabilities;
    VolumeAttributesInformation   m_Attributes;
    NSTimer                      *m_UpdateTimer;
}

static NSString* Bool2ToString(const bool b[2])
{
    // guess that if FS don't support something on interface level then it also doesn't support it on layout level
    if(b[0] == false)
        return @"no";
    return [NSString stringWithFormat:@"yes native: %@", b[1] ? @"yes" : @"no"];
}

- (void) UpdateByTimer:(NSTimer*)theTimer
{
    if(FetchVolumeAttributesInformation(m_Root.c_str(), &m_Capabilities, &m_Attributes) == 0)
        [self PopulateControls];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);

    [self PopulateControls];
    
    m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval: 1 // 1 sec update
                                                         target:self
                                                       selector:@selector(UpdateByTimer:)
                                                       userInfo:nil
                                                        repeats:YES];
    [m_UpdateTimer setDefaultTolerance];

    NSString *uuid = [NSString stringWithFormat:@"UUID:\n\t%@\n",
                      m_Capabilities.attr.vol.uuid[0]?
                        [[[NSUUID alloc] initWithUUIDBytes:m_Attributes.uuid] UUIDString]:
                        @"N/A"
                      ];
    
    NSString *formatcap = [NSString stringWithFormat:
                           @"Format capabilities:\n"
                           "\tVOL_CAP_FMT_PERSISTENTOBJECTIDS: %@\n"
                           "\tVOL_CAP_FMT_SYMBOLICLINKS: %@\n"
                           "\tVOL_CAP_FMT_HARDLINKS: %@\n"
                           "\tVOL_CAP_FMT_JOURNAL: %@\n"
                           "\tVOL_CAP_FMT_JOURNAL_ACTIVE: %@\n"
                           "\tVOL_CAP_FMT_NO_ROOT_TIMES: %@\n"
                           "\tVOL_CAP_FMT_SPARSE_FILES: %@\n"
                           "\tVOL_CAP_FMT_ZERO_RUNS: %@\n"
                           "\tVOL_CAP_FMT_CASE_SENSITIVE: %@\n"
                           "\tVOL_CAP_FMT_CASE_PRESERVING: %@\n"
                           "\tVOL_CAP_FMT_FAST_STATFS: %@\n"
                           "\tVOL_CAP_FMT_2TB_FILESIZE: %@\n"
                           "\tVOL_CAP_FMT_OPENDENYMODES: %@\n"
                           "\tVOL_CAP_FMT_HIDDEN_FILES: %@\n"
                           "\tVOL_CAP_FMT_PATH_FROM_ID: %@\n"
                           "\tVOL_CAP_FMT_NO_VOLUME_SIZES: %@\n"
                           "\tVOL_CAP_FMT_64BIT_OBJECT_IDS: %@\n"
                           "\tVOL_CAP_FMT_DECMPFS_COMPRESSION: %@\n",
                           m_Capabilities.fmt.persistent_objects_ids ? @"yes" : @"no",
                           m_Capabilities.fmt.symbolic_links ? @"yes" : @"no",
                           m_Capabilities.fmt.hard_links ? @"yes" : @"no",
                           m_Capabilities.fmt.journal ? @"yes" : @"no",
                           m_Capabilities.fmt.journal_active ? @"yes" : @"no",
                           m_Capabilities.fmt.no_root_times ? @"yes" : @"no",
                           m_Capabilities.fmt.sparse_files ? @"yes" : @"no",
                           m_Capabilities.fmt.zero_runs ? @"yes" : @"no",
                           m_Capabilities.fmt.case_sensitive ? @"yes" : @"no",
                           m_Capabilities.fmt.case_preserving ? @"yes" : @"no",
                           m_Capabilities.fmt.fast_statfs ? @"yes" : @"no",
                           m_Capabilities.fmt.filesize_2tb ? @"yes" : @"no",
                           m_Capabilities.fmt.open_deny_modes ? @"yes" : @"no",
                           m_Capabilities.fmt.hidden_files ? @"yes" : @"no",
                           m_Capabilities.fmt.path_from_id ? @"yes" : @"no",
                           m_Capabilities.fmt.no_volume_sizes ? @"yes" : @"no",
                           m_Capabilities.fmt.object_ids_64bit ? @"yes" : @"no",
                           m_Capabilities.fmt.decmpfs_compression ? @"yes" : @"no"
                           ];
    NSString *formatint = [NSString stringWithFormat:
                           @"Format interfaces:\n"
                           "\tVOL_CAP_INT_SEARCHFS: %@\n"
                           "\tVOL_CAP_INT_ATTRLIST: %@\n"
                           "\tVOL_CAP_INT_NFSEXPORT: %@\n"
                           "\tVOL_CAP_INT_READDIRATTR: %@\n"
                           "\tVOL_CAP_INT_EXCHANGEDATA: %@\n"
                           "\tVOL_CAP_INT_COPYFILE: %@\n"
                           "\tVOL_CAP_INT_ALLOCATE: %@\n"
                           "\tVOL_CAP_INT_VOL_RENAME: %@\n"
                           "\tVOL_CAP_INT_ADVLOCK: %@\n"
                           "\tVOL_CAP_INT_FLOCK: %@\n"
                           "\tVOL_CAP_INT_EXTENDED_SECURITY: %@\n"
                           "\tVOL_CAP_INT_USERACCESS: %@\n"
                           "\tVOL_CAP_INT_MANLOCK: %@\n"
                           "\tVOL_CAP_INT_EXTENDED_ATTR: %@\n"
                           "\tVOL_CAP_INT_NAMEDSTREAMS: %@\n",
                           m_Capabilities.intr.search_fs ? @"yes" : @"no",
                           m_Capabilities.intr.attr_list ? @"yes" : @"no",
                           m_Capabilities.intr.nfs_export ? @"yes" : @"no",                           
                           m_Capabilities.intr.read_dir_attr ? @"yes" : @"no",
                           m_Capabilities.intr.exchange_data ? @"yes" : @"no",
                           m_Capabilities.intr.copy_file ? @"yes" : @"no",
                           m_Capabilities.intr.allocate ? @"yes" : @"no",
                           m_Capabilities.intr.vol_rename ? @"yes" : @"no",
                           m_Capabilities.intr.adv_lock ? @"yes" : @"no",
                           m_Capabilities.intr.file_lock ? @"yes" : @"no",
                           m_Capabilities.intr.extended_security ? @"yes" : @"no",
                           m_Capabilities.intr.user_access ? @"yes" : @"no",
                           m_Capabilities.intr.mandatory_lock ? @"yes" : @"no",
                           m_Capabilities.intr.extended_attr ? @"yes" : @"no",
                           m_Capabilities.intr.named_strems ? @"yes" : @"no"                           
                           ];
    NSString *attrcmn = [NSString stringWithFormat:
                           @"Common attributes:\n"
                           "\tATTR_CMN_NAME: %@\n"
                           "\tATTR_CMN_DEVID: %@\n"
                           "\tATTR_CMN_FSID: %@\n"
                           "\tATTR_CMN_OBJTYPE: %@\n"
                           "\tATTR_CMN_OBJTAG: %@\n"
                           "\tATTR_CMN_OBJID: %@\n"
                           "\tATTR_CMN_OBJPERMANENTID: %@\n"
                           "\tATTR_CMN_PAROBJID: %@\n"
                           "\tATTR_CMN_SCRIPT: %@\n"
                           "\tATTR_CMN_CRTIME: %@\n"
                           "\tATTR_CMN_MODTIME: %@\n"
                           "\tATTR_CMN_CHGTIME: %@\n"
                           "\tATTR_CMN_ACCTIME: %@\n"
                           "\tATTR_CMN_BKUPTIME: %@\n"
                           "\tATTR_CMN_FNDRINFO: %@\n"
                           "\tATTR_CMN_OWNERID: %@\n"
                           "\tATTR_CMN_GRPID: %@\n"
                           "\tATTR_CMN_ACCESSMASK: %@\n"
                           "\tATTR_CMN_NAMEDATTRCOUNT: %@\n"
                           "\tATTR_CMN_NAMEDATTRLIST: %@\n"
                           "\tATTR_CMN_FLAGS: %@\n"
                           "\tATTR_CMN_USERACCESS: %@\n"
                           "\tATTR_CMN_EXTENDED_SECURITY: %@\n"
                           "\tATTR_CMN_UUID: %@\n"
                           "\tATTR_CMN_GRPUUID: %@\n"
                           "\tATTR_CMN_FILEID: %@\n"
                           "\tATTR_CMN_PARENTID: %@\n"
                           "\tATTR_CMN_FULLPATH: %@\n"
                           "\tATTR_CMN_ADDEDTIME: %@\n",
                           Bool2ToString(m_Capabilities.attr.cmn.name),
                           Bool2ToString(m_Capabilities.attr.cmn.dev_id),
                           Bool2ToString(m_Capabilities.attr.cmn.fs_id),
                           Bool2ToString(m_Capabilities.attr.cmn.obj_type),
                           Bool2ToString(m_Capabilities.attr.cmn.obj_tag),
                           Bool2ToString(m_Capabilities.attr.cmn.obj_id),
                           Bool2ToString(m_Capabilities.attr.cmn.obj_permanent_id),
                           Bool2ToString(m_Capabilities.attr.cmn.par_obj_id),
                           Bool2ToString(m_Capabilities.attr.cmn.script),
                           Bool2ToString(m_Capabilities.attr.cmn.cr_time),
                           Bool2ToString(m_Capabilities.attr.cmn.mod_time),
                           Bool2ToString(m_Capabilities.attr.cmn.chg_time),
                           Bool2ToString(m_Capabilities.attr.cmn.acc_time),
                           Bool2ToString(m_Capabilities.attr.cmn.bkup_time),
                           Bool2ToString(m_Capabilities.attr.cmn.fndr_info),
                           Bool2ToString(m_Capabilities.attr.cmn.owner_id),
                           Bool2ToString(m_Capabilities.attr.cmn.grp_id),
                           Bool2ToString(m_Capabilities.attr.cmn.access_mask),
                           Bool2ToString(m_Capabilities.attr.cmn.named_attr_count),
                           Bool2ToString(m_Capabilities.attr.cmn.named_attr_list),
                           Bool2ToString(m_Capabilities.attr.cmn.flags),
                           Bool2ToString(m_Capabilities.attr.cmn.user_access),
                           Bool2ToString(m_Capabilities.attr.cmn.extended_security),
                           Bool2ToString(m_Capabilities.attr.cmn.uuid),
                           Bool2ToString(m_Capabilities.attr.cmn.grp_uuid),
                           Bool2ToString(m_Capabilities.attr.cmn.file_id),
                           Bool2ToString(m_Capabilities.attr.cmn.parent_id),
                           Bool2ToString(m_Capabilities.attr.cmn.full_path),
                           Bool2ToString(m_Capabilities.attr.cmn.added_time)
                         ];
    NSString *attrvol = [NSString stringWithFormat:
                         @"Volume attributes:\n"
                         "\tATTR_VOL_FSTYPE: %@\n"
                         "\tATTR_VOL_SIGNATURE: %@\n"
                         "\tATTR_VOL_SIZE: %@\n"
                         "\tATTR_VOL_SPACEFREE: %@\n"
                         "\tATTR_VOL_SPACEAVAIL: %@\n"
                         "\tATTR_VOL_MINALLOCATION: %@\n"
                         "\tATTR_VOL_ALLOCATIONCLUMP: %@\n"
                         "\tATTR_VOL_IOBLOCKSIZE: %@\n"
                         "\tATTR_VOL_OBJCOUNT: %@\n"
                         "\tATTR_VOL_FILECOUNT: %@\n"
                         "\tATTR_VOL_DIRCOUNT: %@\n"
                         "\tATTR_VOL_MAXOBJCOUNT: %@\n"
                         "\tATTR_VOL_MOUNTPOINT: %@\n"
                         "\tATTR_VOL_NAME: %@\n"
                         "\tATTR_VOL_MOUNTFLAGS: %@\n"
                         "\tATTR_VOL_MOUNTEDDEVICE: %@\n"
                         "\tATTR_VOL_ENCODINGSUSED: %@\n"
                         "\tATTR_VOL_UUID: %@\n",
                         Bool2ToString(m_Capabilities.attr.vol.fs_type),
                         Bool2ToString(m_Capabilities.attr.vol.signature),
                         Bool2ToString(m_Capabilities.attr.vol.size),
                         Bool2ToString(m_Capabilities.attr.vol.space_free),
                         Bool2ToString(m_Capabilities.attr.vol.space_avail),
                         Bool2ToString(m_Capabilities.attr.vol.min_allocation),
                         Bool2ToString(m_Capabilities.attr.vol.allocation_clump),
                         Bool2ToString(m_Capabilities.attr.vol.io_block_size),
                         Bool2ToString(m_Capabilities.attr.vol.obj_count),
                         Bool2ToString(m_Capabilities.attr.vol.file_count),
                         Bool2ToString(m_Capabilities.attr.vol.dir_count),
                         Bool2ToString(m_Capabilities.attr.vol.max_obj_count),
                         Bool2ToString(m_Capabilities.attr.vol.mount_point),
                         Bool2ToString(m_Capabilities.attr.vol.name),
                         Bool2ToString(m_Capabilities.attr.vol.mount_flags),                         
                         Bool2ToString(m_Capabilities.attr.vol.mounted_device),
                         Bool2ToString(m_Capabilities.attr.vol.encoding_used),
                         Bool2ToString(m_Capabilities.attr.vol.uuid)
                         ];
    NSString *attrdir = [NSString stringWithFormat:
                         @"Directory attributes:\n"
                         "\tATTR_DIR_LINKCOUNT: %@\n"
                         "\tATTR_DIR_ENTRYCOUNT: %@\n"
                         "\tATTR_DIR_MOUNTSTATUS: %@\n",
                         Bool2ToString(m_Capabilities.attr.dir.link_count),
                         Bool2ToString(m_Capabilities.attr.dir.entry_count),
                         Bool2ToString(m_Capabilities.attr.dir.mount_status)
                         ];
    NSString *attrfile = [NSString stringWithFormat:
                         @"File attributes:\n"
                         "\tATTR_FILE_LINKCOUNT: %@\n"
                         "\tATTR_FILE_TOTALSIZE: %@\n"
                         "\tATTR_FILE_ALLOCSIZE: %@\n"
                         "\tATTR_FILE_IOBLOCKSIZE: %@\n"
                         "\tATTR_FILE_CLUMPSIZE: %@\n"
                         "\tATTR_FILE_DEVTYPE: %@\n"
                         "\tATTR_FILE_FILETYPE: %@\n"
                         "\tATTR_FILE_FORKCOUNT: %@\n"
                         "\tATTR_FILE_FORKLIST: %@\n"
                         "\tATTR_FILE_DATALENGTH: %@\n"
                         "\tATTR_FILE_DATAALLOCSIZE: %@\n"
                         "\tATTR_FILE_DATAEXTENTS: %@\n"
                         "\tATTR_FILE_RSRCLENGTH: %@\n"
                         "\tATTR_FILE_RSRCALLOCSIZE: %@\n"
                         "\tATTR_FILE_RSRCEXTENTS: %@\n",
                         Bool2ToString(m_Capabilities.attr.file.link_count),
                         Bool2ToString(m_Capabilities.attr.file.total_size),
                         Bool2ToString(m_Capabilities.attr.file.alloc_size),
                         Bool2ToString(m_Capabilities.attr.file.io_block_size),
                         Bool2ToString(m_Capabilities.attr.file.clump_size),
                         Bool2ToString(m_Capabilities.attr.file.dev_type),
                         Bool2ToString(m_Capabilities.attr.file.file_type),
                         Bool2ToString(m_Capabilities.attr.file.fork_count),
                         Bool2ToString(m_Capabilities.attr.file.fork_list),
                         Bool2ToString(m_Capabilities.attr.file.data_length),
                         Bool2ToString(m_Capabilities.attr.file.data_alloc_size),
                         Bool2ToString(m_Capabilities.attr.file.data_extents),
                         Bool2ToString(m_Capabilities.attr.file.rsrc_length),
                         Bool2ToString(m_Capabilities.attr.file.rsrc_alloc_size),
                         Bool2ToString(m_Capabilities.attr.file.rsrc_extents)
                         ];
    
    NSString *advstr = [NSString stringWithFormat:@"%@%@%@%@%@%@%@", uuid, formatcap, formatint, attrcmn, attrvol, attrdir, attrfile];
    [[self AdvancedTextView] setString:advstr];
    
    GA().PostScreenView("Detailed Volume Information");
}

- (void)showSheetForWindow:(NSWindow *)_window withPath: (const string&)_path
{
    if( auto volume = NativeFSManager::Instance().VolumeFromPath(_path) )
        m_Root = volume->mounted_at_path;
    
    if( FetchVolumeCapabilitiesInformation(m_Root.c_str(), &m_Capabilities) != 0 )
        return;
    if( FetchVolumeAttributesInformation(m_Root.c_str(), &m_Capabilities, &m_Attributes) != 0 )
        return;

    [self beginSheetForWindow:_window completionHandler:^(NSModalResponse returnCode) {}];
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
    [m_UpdateTimer invalidate];
    [self endSheet:NSModalResponseOK];
}

@end
