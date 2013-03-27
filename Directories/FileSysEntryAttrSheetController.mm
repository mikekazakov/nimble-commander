//
//  FileSysEntryAttrSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 26.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/types.h>
#include <pwd.h>
#include <grp.h>
#include <vector>
#include <algorithm>
#include  <OpenDirectory/OpenDirectory.h>
#include "FileSysEntryAttrSheetController.h"
#include "Common.h"
#include "PanelData.h"
#include "filesysattr.h"


struct user_info
{
    uid_t pw_uid;
    const char *pw_name;
    const char *pw_gecos;
    inline bool operator<(const user_info &_r) const { return pw_uid < _r.pw_uid; }
};

struct group_info
{
    gid_t gr_gid;
    const char *gr_name;
    const char *gr_gecos;
    inline bool operator<(const group_info &_r) const { return gr_gid < _r.gr_gid; }
};
        
static NSInteger fsfstate_to_bs(FileSysAttrAlterCommand::fsfstate _s)
{
    if(_s == FileSysAttrAlterCommand::fsf_off) return NSOffState;
    else if(_s == FileSysAttrAlterCommand::fsf_on) return NSOnState;
    else return NSMixedState;
}

// return a long-long-time-ago date in GMT+0
static NSDate *LongTimeAgo()
{
    return [NSDate dateWithString:@"0001-01-01 00:00:00 +0000"];
}
        
@implementation FileSysEntryAttrSheetController
{
    FileSysAttrAlterCommand::fsfstate m_FSFState[FileSysAttrAlterCommand::fsf_totalcount];
    uid_t                             m_CommonUID;
    bool                              m_HasCommonUID;
    gid_t                             m_CommonGID;
    bool                              m_HasCommonGID;
    std::vector<user_info>            m_SystemUsers;
    std::vector<group_info>           m_SystemGroups;
    
    time_t                            m_ATime;
    bool                              m_HasCommonATime;
    time_t                            m_MTime;
    bool                              m_HasCommonMTime;
    time_t                            m_CTime;
    bool                              m_HasCommonCTime;
    time_t                            m_BTime;
    bool                              m_HasCommonBTime;
}

- (id)init
{
    self = [super initWithWindowNibName:@"FileSysEntryAttrSheetController"];
    return self;
}

-(void) dealloc
{
    for(const auto &i: m_SystemUsers)
    {
        free((void*)i.pw_name);
        free((void*)i.pw_gecos);
    }
    for(const auto &i: m_SystemGroups)
    {
        free((void*)i.gr_name);
        free((void*)i.gr_gecos);
    }
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self PopulateControls];
}

- (void) PopulateControls
{
    // TODO: totally different logic branch with "proceed with directories checkbox"

    [[self OwnerReadCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_usr_r] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OwnerReadCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_usr_r])];

    [[self OwnerWriteCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_usr_w] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OwnerWriteCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_usr_w])];

    [[self OwnerExecCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_usr_x] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OwnerExecCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_usr_x])];
    
    [[self GroupReadCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_grp_r] == FileSysAttrAlterCommand::fsf_mixed];
    [[self GroupReadCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_grp_r])];

    [[self GroupWriteCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_grp_w] == FileSysAttrAlterCommand::fsf_mixed];
    [[self GroupWriteCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_grp_w])];
    
    [[self GroupExecCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_grp_x] == FileSysAttrAlterCommand::fsf_mixed];
    [[self GroupExecCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_grp_x])];
    
    [[self OthersReadCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_oth_r] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OthersReadCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_oth_r])];

    [[self OthersWriteCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_oth_w] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OthersWriteCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_oth_w])];

    [[self OthersExecCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_oth_x] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OthersExecCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_oth_x])];

    [[self SetUIDCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_suid] == FileSysAttrAlterCommand::fsf_mixed];
    [[self SetUIDCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_suid])];

    [[self SetGIDCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_sgid] == FileSysAttrAlterCommand::fsf_mixed];
    [[self SetGIDCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_sgid])];    
    
    [[self StickyCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_unix_sticky] == FileSysAttrAlterCommand::fsf_mixed];
    [[self StickyCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_unix_sticky])];

    [[self NoDumpCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_uf_nodump] == FileSysAttrAlterCommand::fsf_mixed];
    [[self NoDumpCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_uf_nodump])];

    [[self UserImmutableCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_uf_immutable] == FileSysAttrAlterCommand::fsf_mixed];
    [[self UserImmutableCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_uf_immutable])];

    [[self UserAppendCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_uf_append] == FileSysAttrAlterCommand::fsf_mixed];
    [[self UserAppendCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_uf_append])];

    [[self OpaqueCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_uf_opaque] == FileSysAttrAlterCommand::fsf_mixed];
    [[self OpaqueCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_uf_opaque])];
    
    [[self HiddenCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_uf_hidden] == FileSysAttrAlterCommand::fsf_mixed];
    [[self HiddenCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_uf_hidden])];

    [[self ArchivedCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_sf_archived] == FileSysAttrAlterCommand::fsf_mixed];
    [[self ArchivedCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_sf_archived])];

    [[self SystemImmutableCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_sf_immutable] == FileSysAttrAlterCommand::fsf_mixed];
    [[self SystemImmutableCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_sf_immutable])];

    [[self SystemAppendCheck] setAllowsMixedState:
     m_FSFState[FileSysAttrAlterCommand::fsf_sf_append] == FileSysAttrAlterCommand::fsf_mixed];
    [[self SystemAppendCheck] setState:fsfstate_to_bs(m_FSFState[FileSysAttrAlterCommand::fsf_sf_append])];
    
    // UID/GID section
    NSSize menu_pic_size;
    menu_pic_size.width = menu_pic_size.height = [[NSFont menuFontOfSize:0] pointSize];
    
    NSImage *img_user = [NSImage imageNamed:NSImageNameUser];
    [img_user setSize:menu_pic_size];
    [[self UsersPopUpButton] removeAllItems];
    for(const auto &i: m_SystemUsers)
    {
        NSString *ent = [NSString stringWithFormat:@"%@ (%d) - %@",
                         [NSString stringWithUTF8String:i.pw_name],
                         i.pw_uid,
                         [NSString stringWithUTF8String:i.pw_gecos]
                        ];
        [[self UsersPopUpButton] addItemWithTitle:ent];
        [[[self UsersPopUpButton] lastItem] setImage:img_user];
        if(m_HasCommonUID && m_CommonUID == i.pw_uid)
            [[self UsersPopUpButton] selectItemAtIndex:[[self UsersPopUpButton] numberOfItems]-1 ];
    }
    
    if(!m_HasCommonUID)
    {
        [[self UsersPopUpButton] addItemWithTitle:@"[Mixed]"];
        [[[self UsersPopUpButton] lastItem] setImage:img_user];        
        [[self UsersPopUpButton] selectItemAtIndex:[[self UsersPopUpButton] numberOfItems]-1 ];
    }
    
    NSImage *img_group = [NSImage imageNamed:NSImageNameUserGroup];
    [img_group setSize:menu_pic_size];
    [[self GroupsPopUpButton] removeAllItems];
    for(const auto &i: m_SystemGroups)
    {
        NSString *ent = [NSString stringWithFormat:@"%@ (%d) - %@",
                         [NSString stringWithUTF8String:i.gr_name],
                         i.gr_gid,
                         [NSString stringWithUTF8String:i.gr_gecos]
                         ];
        [[self GroupsPopUpButton] addItemWithTitle:ent];
        [[[self GroupsPopUpButton] lastItem] setImage:img_group];
        if(m_HasCommonGID && m_CommonGID == i.gr_gid)
            [[self GroupsPopUpButton] selectItemAtIndex:[[self GroupsPopUpButton] numberOfItems]-1 ];
    }
    
    if(!m_HasCommonGID)
    {
        [[self GroupsPopUpButton] addItemWithTitle:@"[Mixed]"];
        [[[self GroupsPopUpButton] lastItem] setImage:img_group];        
        [[self GroupsPopUpButton] selectItemAtIndex:[[self GroupsPopUpButton] numberOfItems]-1 ];
    }
    
    // Time section
    [[self ATimePicker] setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [[self ATimePicker] setDateValue: m_HasCommonATime ?
     [NSDate dateWithTimeIntervalSince1970:m_ATime+[[NSTimeZone defaultTimeZone]secondsFromGMT]] :
     LongTimeAgo()];

    [[self MTimePicker] setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [[self MTimePicker] setDateValue: m_HasCommonMTime ?
     [NSDate dateWithTimeIntervalSince1970:m_MTime+[[NSTimeZone defaultTimeZone]secondsFromGMT]] :
     LongTimeAgo()];
    
    [[self CTimePicker] setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [[self CTimePicker] setDateValue: m_HasCommonCTime ?
     [NSDate dateWithTimeIntervalSince1970:m_CTime+[[NSTimeZone defaultTimeZone]secondsFromGMT]] :
     LongTimeAgo()];
    
    [[self BTimePicker] setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [[self BTimePicker] setDateValue: m_HasCommonBTime ?
     [NSDate dateWithTimeIntervalSince1970:m_BTime+[[NSTimeZone defaultTimeZone]secondsFromGMT]] :
     LongTimeAgo()];
    
    
}

- (void) LoadUsers
{
    // here we use old getpwent for users enumeration and modern OpenDirectory service for groups enumeration
    // that's because getgrent doesn't provide us with all information OSX has
    setpwent();
    while(struct passwd *ent = getpwent())
    {
        user_info curr;
        curr.pw_uid = ent->pw_uid;
        curr.pw_name = strdup(ent->pw_name);
        curr.pw_gecos = strdup(ent->pw_gecos);
        m_SystemUsers.push_back(curr);
    }
    endpwent();
    std::sort(m_SystemUsers.begin(), m_SystemUsers.end());
    
    ODSession *s = [ODSession defaultSession];
    ODNode *root = [ODNode nodeWithSession:s name:@"/Local/Default" error:nil];
    ODQuery *q = [ODQuery queryWithNode:root
                         forRecordTypes:kODRecordTypeGroups
                              attribute:nil
                              matchType:0
                            queryValues:nil
                       returnAttributes:nil
                         maximumResults:0
                                  error:nil];
    NSArray *results = [q resultsAllowingPartial:NO error:nil];
    for (ODRecord *r in results)
    {
        NSArray *gecos = [r valuesForAttribute:kODAttributeTypeFullName error:nil];
        assert([gecos count] > 0);
        NSArray *gid = [r valuesForAttribute:kODAttributeTypePrimaryGroupID error:nil];
        assert([gid count] > 0);
        group_info curr;
        curr.gr_gid = (gid_t) [[gid objectAtIndex:0] integerValue];
        curr.gr_name = strdup( [[r recordName] UTF8String] );
        curr.gr_gecos = strdup( [(NSString*)[gecos objectAtIndex:0] UTF8String] );
        m_SystemGroups.push_back(curr);
    }
    std::sort(m_SystemGroups.begin(), m_SystemGroups.end());
}

- (void)ShowSheet: (NSWindow *)_window entries: (const PanelData*)_data
{
    FileSysAttrAlterCommand::GetCommonFSFlagsState(*_data, m_FSFState);
    FileSysAttrAlterCommand::GetCommonFSUIDAndGID(*_data, m_CommonUID, m_HasCommonUID, m_CommonGID, m_HasCommonGID);
    FileSysAttrAlterCommand::GetCommonFSTimes(*_data, m_ATime, m_HasCommonATime, m_MTime, m_HasCommonMTime,
                                              m_CTime, m_HasCommonCTime, m_BTime, m_HasCommonBTime);
    
    [self LoadUsers];
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    self.ME = self;
}

- (IBAction)OnCancel:(id)sender{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

- (IBAction)OnATimeClear:(id)sender{
    [[self ATimePicker] setDateValue:LongTimeAgo()];
}
        
- (IBAction)OnATimeSet:(id)sender{
    [[self ATimePicker] setDateValue:[[NSDate date] dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
}

- (IBAction)OnMTimeClear:(id)sender{
    [[self MTimePicker] setDateValue:LongTimeAgo()];
}
        
- (IBAction)OnMTimeSet:(id)sender{
    [[self MTimePicker] setDateValue:[[NSDate date] dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
}

- (IBAction)OnCTimeClear:(id)sender{
    [[self CTimePicker] setDateValue:LongTimeAgo()];
}
        
- (IBAction)OnCTimeSet:(id)sender{
    [[self CTimePicker] setDateValue:[[NSDate date] dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
}

- (IBAction)OnBTimeClear:(id)sender{
    [[self BTimePicker] setDateValue:LongTimeAgo()];
}

- (IBAction)OnBTimeSet:(id)sender{
    [[self BTimePicker] setDateValue:[[NSDate date] dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
}
        
- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    self.ME = nil; // let ARC do it's duty
}
@end
