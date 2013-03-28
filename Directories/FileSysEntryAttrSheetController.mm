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
    inline bool operator<(const user_info &_r) const { return (signed)pw_uid < (signed)_r.pw_uid; }
};

struct group_info
{
    gid_t gr_gid;
    const char *gr_name;
    const char *gr_gecos;
    inline bool operator<(const group_info &_r) const { return (signed)gr_gid < (signed)_r.gr_gid; }
};
        
static NSInteger fsfstate_to_bs(FileSysAttrAlterCommand::fsfstate _s)
{
    if(_s == FileSysAttrAlterCommand::fsf_off) return NSOffState;
    else if(_s == FileSysAttrAlterCommand::fsf_on) return NSOnState;
    else return NSMixedState;
}

static FileSysAttrAlterCommand::fsfstate bs_to_fsfstate(NSButton *_b)
{
    NSInteger state = [_b state];
    if(state == NSOffState) return FileSysAttrAlterCommand::fsf_off;
    if(state == NSOnState)  return FileSysAttrAlterCommand::fsf_on;
    return FileSysAttrAlterCommand::fsf_mixed;
}

// return a long-long-time-ago date in GMT+0
static NSDate *LongTimeAgo()
{
    return [NSDate dateWithString:@"0001-01-01 00:00:00 +0000"];
}

struct OtherAttrs
{
    enum
    {
        uid=0,
        gid=1,
        atime=2,
        mtime=3,
        ctime=4,
        btime=5,
        total
    };
};
        
@implementation FileSysEntryAttrSheetController
{
    struct
    {
        FileSysAttrAlterCommand::fsfstate fsfstate[FileSysAttrAlterCommand::fsf_totalcount];
        uid_t                             uid;
        gid_t                             gid;
        time_t                            atime;
        time_t                            mtime;
        time_t                            ctime;
        time_t                            btime;
    } m_State[2]; // [0] is real situation, [1] is user-choosed variants ( initially [0]==[1] )
    
    bool                              m_UserDidEditFlags[FileSysAttrAlterCommand::fsf_totalcount];
    bool                              m_UserDidEditOthers[OtherAttrs::total];
    bool                              m_HasCommonUID;
    bool                              m_HasCommonGID;
    bool                              m_HasCommonATime;
    bool                              m_HasCommonMTime;
    bool                              m_HasCommonCTime;
    bool                              m_HasCommonBTime;
    bool                              m_HasDirectoryEntries;
    bool                              m_ProcessSubfolders;
    std::vector<user_info>            m_SystemUsers;
    std::vector<group_info>           m_SystemGroups;
}

- (id)init
{
    self = [super initWithWindowNibName:@"FileSysEntryAttrSheetController"];
    memset(m_UserDidEditFlags, 0, sizeof(m_UserDidEditFlags));
    memset(m_UserDidEditOthers, 0, sizeof(m_UserDidEditOthers));
    
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
    [[self ProcessSubfoldersCheck] setHidden:!m_HasDirectoryEntries];

#define DOFLAG(_f, _c)\
    [[self _c] setAllowsMixedState: m_ProcessSubfolders ? true:\
     m_State[0].fsfstate[FileSysAttrAlterCommand::_f] == FileSysAttrAlterCommand::fsf_mixed];\
    [[self _c] setState: m_ProcessSubfolders ?\
     fsfstate_to_bs(m_UserDidEditFlags[FileSysAttrAlterCommand::_f] ?\
                    m_State[1].fsfstate[FileSysAttrAlterCommand::_f] :\
                    FileSysAttrAlterCommand::fsf_mixed) :\
     fsfstate_to_bs(m_State[1].fsfstate[FileSysAttrAlterCommand::_f])\
     ];
    DOFLAG(fsf_unix_usr_r  , OwnerReadCheck);
    DOFLAG(fsf_unix_usr_w  , OwnerWriteCheck);
    DOFLAG(fsf_unix_usr_x  , OwnerExecCheck);
    DOFLAG(fsf_unix_grp_r  , GroupReadCheck);
    DOFLAG(fsf_unix_grp_w  , GroupWriteCheck);
    DOFLAG(fsf_unix_grp_x  , GroupExecCheck);
    DOFLAG(fsf_unix_oth_r  , OthersReadCheck);
    DOFLAG(fsf_unix_oth_w  , OthersWriteCheck);
    DOFLAG(fsf_unix_oth_x  , OthersExecCheck);
    DOFLAG(fsf_unix_suid   , SetUIDCheck);
    DOFLAG(fsf_unix_sgid   , SetGIDCheck);
    DOFLAG(fsf_unix_sticky , StickyCheck);
    DOFLAG(fsf_uf_nodump   , NoDumpCheck);
    DOFLAG(fsf_uf_immutable, UserImmutableCheck);
    DOFLAG(fsf_uf_append   , UserAppendCheck);
    DOFLAG(fsf_uf_opaque   , OpaqueCheck);
    DOFLAG(fsf_uf_hidden   , HiddenCheck);
    DOFLAG(fsf_sf_archived , ArchivedCheck);
    DOFLAG(fsf_sf_immutable, SystemImmutableCheck);
    DOFLAG(fsf_sf_append   , SystemAppendCheck);
#undef DOFLAG

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
        
        if(m_ProcessSubfolders)
        {
            if(m_HasCommonUID && m_UserDidEditOthers[OtherAttrs::uid] && m_State[1].uid == i.pw_uid )
                [[self UsersPopUpButton] selectItemAtIndex:[[self UsersPopUpButton] numberOfItems]-1 ];
        }
        else
        {
            if(m_HasCommonUID && m_State[1].uid == i.pw_uid)
                [[self UsersPopUpButton] selectItemAtIndex:[[self UsersPopUpButton] numberOfItems]-1 ];
        }
    }
    
    if(!m_HasCommonUID || m_ProcessSubfolders)
    {
        [[self UsersPopUpButton] addItemWithTitle:@"[Mixed]"];
        [[[self UsersPopUpButton] lastItem] setImage:img_user];
        
        if(!m_ProcessSubfolders || !m_UserDidEditOthers[OtherAttrs::uid])
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
        if(m_ProcessSubfolders)
        {
            if(m_HasCommonGID && m_UserDidEditOthers[OtherAttrs::gid] && m_State[1].gid == i.gr_gid )
                [[self GroupsPopUpButton] selectItemAtIndex:[[self GroupsPopUpButton] numberOfItems]-1 ];
        }
        else
        {
            if(m_HasCommonGID && m_State[1].gid == i.gr_gid)
                [[self GroupsPopUpButton] selectItemAtIndex:[[self GroupsPopUpButton] numberOfItems]-1 ];
        }
    }
    
    if(!m_HasCommonGID || m_ProcessSubfolders)
    {
        [[self GroupsPopUpButton] addItemWithTitle:@"[Mixed]"];
        [[[self GroupsPopUpButton] lastItem] setImage:img_group];
        if(!m_ProcessSubfolders || !m_UserDidEditOthers[OtherAttrs::gid])
            [[self GroupsPopUpButton] selectItemAtIndex:[[self GroupsPopUpButton] numberOfItems]-1 ];
    }
    
    

    // Time section
    NSInteger secsfromgmt = [[NSTimeZone defaultTimeZone]secondsFromGMT];

#define DOTIME(_v1, _v2, _c)\
    [[self _c] setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];\
    [[self _c] setDateValue: (!m_ProcessSubfolders && _v1) || m_UserDidEditOthers[OtherAttrs::_v2] ?\
     [NSDate dateWithTimeIntervalSince1970:m_State[1]._v2+secsfromgmt] :\
     LongTimeAgo() ];
    DOTIME(m_HasCommonATime, atime, ATimePicker);
    DOTIME(m_HasCommonMTime, mtime, MTimePicker);
    DOTIME(m_HasCommonCTime, ctime, CTimePicker);
    DOTIME(m_HasCommonBTime, btime, BTimePicker);
#undef DOTIME

}

- (void) LoadUsers
{    
    {
        ODNode *root = [ODNode nodeWithSession:[ODSession defaultSession] name:@"/Local/Default" error:nil];
        ODQuery *q = [ODQuery queryWithNode:root
                             forRecordTypes:kODRecordTypeUsers
                                  attribute:nil
                                  matchType:0
                                queryValues:nil
                           returnAttributes:nil
                             maximumResults:0
                                      error:nil];
        for (ODRecord *r in [q resultsAllowingPartial:NO error:nil])
        {
            NSArray *gecos = [r valuesForAttribute:kODAttributeTypeFullName error:nil];
            assert([gecos count] > 0);
            NSArray *uid = [r valuesForAttribute:kODAttributeTypeUniqueID error:nil];
            assert([uid count] > 0);

            user_info curr;
            curr.pw_uid = (uid_t) [[uid objectAtIndex:0] integerValue];
            curr.pw_name = strdup([[r recordName] UTF8String]);
            curr.pw_gecos = strdup([(NSString*)[gecos objectAtIndex:0] UTF8String]);
            m_SystemUsers.push_back(curr);
        }
    }
    std::sort(m_SystemUsers.begin(), m_SystemUsers.end());
    
    {
        ODNode *root = [ODNode nodeWithSession:[ODSession defaultSession] name:@"/Local/Default" error:nil];
        ODQuery *q = [ODQuery queryWithNode:root
                             forRecordTypes:kODRecordTypeGroups
                                  attribute:nil
                                  matchType:0
                                queryValues:nil
                           returnAttributes:nil
                             maximumResults:0
                                      error:nil];
        for (ODRecord *r in [q resultsAllowingPartial:NO error:nil])
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
    }
    std::sort(m_SystemGroups.begin(), m_SystemGroups.end());
}

- (void)ShowSheet: (NSWindow *)_window entries: (const PanelData*)_data
{
    FileSysAttrAlterCommand::GetCommonFSFlagsState(*_data, m_State[0].fsfstate);
    FileSysAttrAlterCommand::GetCommonFSUIDAndGID(*_data, m_State[0].uid, m_HasCommonUID, m_State[0].gid, m_HasCommonGID);
    FileSysAttrAlterCommand::GetCommonFSTimes(*_data, m_State[0].atime, m_HasCommonATime, m_State[0].mtime, m_HasCommonMTime,
                                              m_State[0].ctime, m_HasCommonCTime, m_State[0].btime, m_HasCommonBTime);
    memcpy(&m_State[1], &m_State[0], sizeof(m_State[0]));
    
    m_HasDirectoryEntries = _data->GetSelectedItemsDirectoriesCount() > 0;
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
    m_UserDidEditOthers[OtherAttrs::atime] = false;
}
        
- (IBAction)OnATimeSet:(id)sender{
    NSDate *cur = [NSDate date];
    [[self ATimePicker] setDateValue:[cur dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
    m_State[1].atime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::atime] = true;
}

- (IBAction)OnMTimeClear:(id)sender{
    [[self MTimePicker] setDateValue:LongTimeAgo()];
    m_UserDidEditOthers[OtherAttrs::mtime] = false;
}
        
- (IBAction)OnMTimeSet:(id)sender{
    NSDate *cur = [NSDate date];
    [[self MTimePicker] setDateValue:[cur dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
    m_State[1].mtime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::mtime] = true;
}

- (IBAction)OnCTimeClear:(id)sender{
    [[self CTimePicker] setDateValue:LongTimeAgo()];
    m_UserDidEditOthers[OtherAttrs::ctime] = false;
}
        
- (IBAction)OnCTimeSet:(id)sender{
    NSDate *cur = [NSDate date];    
    [[self CTimePicker] setDateValue:[cur dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
    m_State[1].ctime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::ctime] = true;
}

- (IBAction)OnBTimeClear:(id)sender{
    [[self BTimePicker] setDateValue:LongTimeAgo()];
    m_UserDidEditOthers[OtherAttrs::btime] = false;
}

- (IBAction)OnBTimeSet:(id)sender{
    NSDate *cur = [NSDate date];
    [[self BTimePicker] setDateValue:[cur dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]]];
    m_State[1].btime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::btime] = true;
}

- (IBAction)OnProcessSubfolders:(id)sender{
    m_ProcessSubfolders = [[self ProcessSubfoldersCheck] state] == NSOnState;
    [self PopulateControls];
}
        
- (IBAction)OnFlag:(id)sender
{
#define DOFLAG(_f, _c)\
    if(sender == [self _c]) {\
     m_UserDidEditFlags[FileSysAttrAlterCommand::_f] = true;\
     m_State[1].fsfstate[FileSysAttrAlterCommand::_f] = bs_to_fsfstate([self _c]); }
    DOFLAG(fsf_unix_usr_r  , OwnerReadCheck);
    DOFLAG(fsf_unix_usr_w  , OwnerWriteCheck);
    DOFLAG(fsf_unix_usr_x  , OwnerExecCheck);
    DOFLAG(fsf_unix_grp_r  , GroupReadCheck);
    DOFLAG(fsf_unix_grp_w  , GroupWriteCheck);
    DOFLAG(fsf_unix_grp_x  , GroupExecCheck);
    DOFLAG(fsf_unix_oth_r  , OthersReadCheck);
    DOFLAG(fsf_unix_oth_w  , OthersWriteCheck);
    DOFLAG(fsf_unix_oth_x  , OthersExecCheck);
    DOFLAG(fsf_unix_suid   , SetUIDCheck);
    DOFLAG(fsf_unix_sgid   , SetGIDCheck);
    DOFLAG(fsf_unix_sticky , StickyCheck);
    DOFLAG(fsf_uf_nodump   , NoDumpCheck);
    DOFLAG(fsf_uf_immutable, UserImmutableCheck);
    DOFLAG(fsf_uf_append   , UserAppendCheck);
    DOFLAG(fsf_uf_opaque   , OpaqueCheck);
    DOFLAG(fsf_uf_hidden   , HiddenCheck);
    DOFLAG(fsf_sf_archived , ArchivedCheck);
    DOFLAG(fsf_sf_immutable, SystemImmutableCheck);
    DOFLAG(fsf_sf_append   , SystemAppendCheck);
#undef DOFLAG
}

- (IBAction)OnUIDSel:(id)sender
{
    NSInteger ind = [[self UsersPopUpButton] indexOfSelectedItem];
    if(ind < m_SystemUsers.size())
    {
        m_UserDidEditOthers[OtherAttrs::uid]=true;
        m_State[1].uid = m_SystemUsers[ind].pw_uid;
    }
    else
    {
        // user choosed [mixed]
        m_UserDidEditOthers[OtherAttrs::uid]=false;
        m_State[1].uid = m_State[0].uid; // reset selection to original value if any
    }
}
        
- (IBAction)OnGIDSel:(id)sender
{
    NSInteger ind = [[self GroupsPopUpButton] indexOfSelectedItem];
    if(ind < m_SystemGroups.size())
    {
        m_UserDidEditOthers[OtherAttrs::gid]=true;
        m_State[1].gid = m_SystemGroups[ind].gr_gid;
    }
    else
    {
        // user choosed [mixed]
        m_UserDidEditOthers[OtherAttrs::gid]=false;
        m_State[1].gid = m_State[0].gid; // reset selection to original value if any
    }
}

- (IBAction)OnTimeChange:(id)sender
{
    NSInteger secsfromgmt = [[NSTimeZone defaultTimeZone]secondsFromGMT];
    if(sender == [self ATimePicker])
    {
        NSDate *date = [[[self ATimePicker] dateValue] dateByAddingTimeInterval:-secsfromgmt];
        NSTimeInterval since1970 = [date timeIntervalSince1970];
        m_UserDidEditOthers[OtherAttrs::atime] = since1970 >= 0;
        m_State[1].atime = since1970 >= 0 ? since1970 : m_State[0].atime;
    }
    else if(sender == [self MTimePicker])
    {
        NSDate *date = [[[self MTimePicker] dateValue] dateByAddingTimeInterval:-secsfromgmt];
        NSTimeInterval since1970 = [date timeIntervalSince1970];
        m_UserDidEditOthers[OtherAttrs::mtime] = since1970 >= 0;
        m_State[1].mtime = since1970 >= 0 ? since1970 : m_State[0].mtime;
    }
    else if(sender == [self CTimePicker])
    {
        NSDate *date = [[[self CTimePicker] dateValue] dateByAddingTimeInterval:-secsfromgmt];
        NSTimeInterval since1970 = [date timeIntervalSince1970];
        m_UserDidEditOthers[OtherAttrs::ctime] = since1970 >= 0;
        m_State[1].ctime = since1970 >= 0 ? since1970 : m_State[0].ctime;
    }
    else if(sender == [self BTimePicker])
    {
        NSDate *date = [[[self BTimePicker] dateValue] dateByAddingTimeInterval:-secsfromgmt];
        NSTimeInterval since1970 = [date timeIntervalSince1970];
        m_UserDidEditOthers[OtherAttrs::btime] = since1970 >= 0;
        m_State[1].btime = since1970 >= 0 ? since1970 : m_State[0].btime;
    }
}
        
- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    self.ME = nil; // let ARC do it's duty
}
@end
