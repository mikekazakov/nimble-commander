//
//  FileSysEntryAttrSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 26.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/types.h>
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>
#include <vector>
#include <algorithm>
#include  <OpenDirectory/OpenDirectory.h>
#include "FileSysEntryAttrSheetController.h"
#include "Common.h"
#include "PanelData.h"
#include "filesysattr.h"
#include "chained_strings.h"
#include "DispatchQueue.h"
#include "sysinfo.h"

struct user_info
{
    uid_t pw_uid;
    NSString *pw_name;
    NSString *pw_gecos;
};

struct group_info
{
    gid_t gr_gid;
    NSString *gr_name;
    NSString *gr_gecos;
};
        
inline static NSInteger tribool_to_state(tribool _s)
{
    if(_s == false) return NSOffState;
    else if(_s == true) return NSOnState;
    else return NSMixedState;
}

inline static tribool state_to_tribool(NSButton *_b)
{
    NSInteger state = _b.state;
    if(state == NSOffState) return false;
    if(state == NSOnState)  return true;
    return indeterminate;
}

// return a long-long-time-ago date in GMT+0
static NSDate *LongTimeAgo()
{
    return [NSDate dateWithString:@"0001-01-01 00:00:00 +0000"];
}

static NSInteger ZeroSecsFromGMT()
{
    //    NSInteger secsfromgmt = [[NSTimeZone defaultTimeZone]secondsFromGMT];
//    bool b = [[NSTimeZone defaultTimeZone] isDaylightSavingTime];
//    NSTimeInterval off = [[NSTimeZone defaultTimeZone] daylightSavingTimeOffsetForDate:[NSDate date]];
    return [[NSTimeZone defaultTimeZone]secondsFromGMTForDate:[NSDate date]];
}

// TODO: still buggy for __SOME__ files check me twice again!!!!!
// this weirness appears only for daylight saving timezones
static NSInteger ZeroSecsFromGMTEpoc()
{
    NSTimeInterval off = [[NSTimeZone defaultTimeZone] daylightSavingTimeOffsetForDate:[NSDate date]];
    return [[NSTimeZone defaultTimeZone]secondsFromGMTForDate:[NSDate date]] - off;
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
        tribool                           fsfstate[FileSysAttrAlterCommand::fsf_totalcount];
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
    vector<user_info>            m_SystemUsers;
    vector<group_info>           m_SystemGroups;
    chained_strings              m_Files;
    string                              m_RootPath;

    shared_ptr<FileSysAttrAlterCommand>    m_Result;
    FileSysEntryAttrSheetCompletionHandler m_Handler;
}

@synthesize Result = m_Result;

- (id)init
{
    self = [super initWithWindowNibName:@"FileSysEntryAttrSheetController"];
    if(self) {
        
        memset(m_UserDidEditFlags, 0, sizeof(m_UserDidEditFlags));
        memset(m_UserDidEditOthers, 0, sizeof(m_UserDidEditOthers));
                
        DispatchGroup dg;
        dg.Run( [=]{ [self LoadUsers]; } );
        dg.Run( [=]{ [self LoadGroups]; } );
        dg.Wait();
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Set title.
    if (m_Files.size() == 1)
        [self.Title setStringValue:[NSString stringWithFormat:@"Change file attributes for %@",
                                    [NSString stringWithUTF8String:m_Files.front().c_str()]]];
    else
        [self.Title setStringValue:[NSString stringWithFormat:@"Change file attributes for %i "
                                    "selected items", m_Files.size()]];
    
    [self PopulateControls];
}

- (void) PopulateControls
{
    self.ProcessSubfoldersCheck.hidden = !m_HasDirectoryEntries;

#define DOFLAG(_f, _c)\
     self._c.allowsMixedState = m_ProcessSubfolders ? true :\
        bool(m_State[0].fsfstate[FileSysAttrAlterCommand::_f] == indeterminate);\
    self._c.state = m_ProcessSubfolders ?\
        tribool_to_state(m_UserDidEditFlags[FileSysAttrAlterCommand::_f] ? m_State[1].fsfstate[FileSysAttrAlterCommand::_f] : indeterminate):\
        tribool_to_state(m_State[1].fsfstate[FileSysAttrAlterCommand::_f]);
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
    menu_pic_size.width = menu_pic_size.height = [NSFont menuFontOfSize:0].pointSize;

    NSImage *img_user = [NSImage imageNamed:NSImageNameUser];
    img_user.size = menu_pic_size;
    [self.UsersPopUpButton removeAllItems];
    for(const auto &i: m_SystemUsers) {
        NSString *ent = [NSString stringWithFormat:@"%@ (%d) - %@", i.pw_name, i.pw_uid, i.pw_gecos];
        [self.UsersPopUpButton addItemWithTitle:ent];
        self.UsersPopUpButton.lastItem.image = img_user;
        
        if(m_ProcessSubfolders) {
            if(m_HasCommonUID && m_UserDidEditOthers[OtherAttrs::uid] && m_State[1].uid == i.pw_uid )
                [self.UsersPopUpButton selectItem:self.UsersPopUpButton.lastItem];
        }
        else {
            if(m_HasCommonUID && m_State[1].uid == i.pw_uid)
                [self.UsersPopUpButton selectItem:self.UsersPopUpButton.lastItem];
        }
    }
    
    if(!m_HasCommonUID || m_ProcessSubfolders) {
        [self.UsersPopUpButton addItemWithTitle:@"[Mixed]"];
        self.UsersPopUpButton.lastItem.image = img_user;
        
        if(!m_ProcessSubfolders || !m_UserDidEditOthers[OtherAttrs::uid])
            [self.UsersPopUpButton selectItem:self.UsersPopUpButton.lastItem];
    }
    
    NSImage *img_group = [NSImage imageNamed:NSImageNameUserGroup];
    img_group.size = menu_pic_size;
    [self.GroupsPopUpButton removeAllItems];
    for(const auto &i: m_SystemGroups) {
        NSString *ent = [NSString stringWithFormat:@"%@ (%d) - %@", i.gr_name, i.gr_gid, i.gr_gecos];
        [self.GroupsPopUpButton addItemWithTitle:ent];
        self.GroupsPopUpButton.lastItem.image = img_group;
        if(m_ProcessSubfolders) {
            if(m_HasCommonGID && m_UserDidEditOthers[OtherAttrs::gid] && m_State[1].gid == i.gr_gid )
                [self.GroupsPopUpButton selectItem:self.GroupsPopUpButton.lastItem];
        }
        else {
            if(m_HasCommonGID && m_State[1].gid == i.gr_gid)
                [self.GroupsPopUpButton selectItem:self.GroupsPopUpButton.lastItem];
        }
    }
    
    if(!m_HasCommonGID || m_ProcessSubfolders) {
        [self.GroupsPopUpButton addItemWithTitle:@"[Mixed]"];
        self.GroupsPopUpButton.lastItem.image = img_group;
        if(!m_ProcessSubfolders || !m_UserDidEditOthers[OtherAttrs::gid])
            [self.GroupsPopUpButton selectItem:self.GroupsPopUpButton.lastItem];
    }
    
    

    // Time section
//    NSInteger secsfromgmt = [[NSTimeZone defaultTimeZone]secondsFromGMT];
//    NSInteger secsfromgmt = [[NSTimeZone defaultTimeZone]secondsFromGMTForDate:[NSDate date]];
//    NSInteger secsfromgmt = ZeroSecsFromGMT();
    NSInteger secsfromgmt = ZeroSecsFromGMTEpoc();    

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
    m_SystemUsers.clear();
    ODNode *root = [ODNode nodeWithSession:ODSession.defaultSession name:@"/Local/Default" error:nil];
    assert(root);
    ODQuery *q = [ODQuery queryWithNode:root
                         forRecordTypes:kODRecordTypeUsers
                              attribute:nil
                              matchType:0
                            queryValues:nil
                       returnAttributes:nil
                         maximumResults:0
                                  error:nil];
    assert(q);
    for (ODRecord *r in [q resultsAllowingPartial:NO error:nil]) {
        
        NSArray *uid = [r valuesForAttribute:kODAttributeTypeUniqueID error:nil];
        if(uid.count == 0) continue; // invalid response, can't handle it
        
        NSArray *gecos = [r valuesForAttribute:kODAttributeTypeFullName error:nil];
        
        user_info curr;
        curr.pw_uid = (uid_t) [uid[0] integerValue];
        curr.pw_name = r.recordName;
        curr.pw_gecos = (gecos.count > 0) ? ((NSString*)[gecos objectAtIndex:0]) : @"";
        m_SystemUsers.emplace_back(curr);
    }
    sort(begin(m_SystemUsers), end(m_SystemUsers), [](auto&_1, auto&_2){ return (signed)_1.pw_uid < (signed)_2.pw_uid; } );
}

- (void) LoadGroups
{
    m_SystemGroups.clear();
    ODNode *root = [ODNode nodeWithSession:ODSession.defaultSession name:@"/Local/Default" error:nil];
    assert(root);
    ODQuery *q = [ODQuery queryWithNode:root
                         forRecordTypes:kODRecordTypeGroups
                              attribute:nil
                              matchType:0
                            queryValues:nil
                       returnAttributes:nil
                         maximumResults:0
                                  error:nil];
    assert(q);
    for (ODRecord *r in [q resultsAllowingPartial:NO error:nil]) {
        NSArray *gid = [r valuesForAttribute:kODAttributeTypePrimaryGroupID error:nil];
        if(gid.count == 0) continue; //invalid response
        
        NSArray *gecos = [r valuesForAttribute:kODAttributeTypeFullName error:nil];
        
        group_info curr;
        curr.gr_gid = (gid_t) [gid[0] integerValue];
        curr.gr_name = r.recordName;
        curr.gr_gecos = (gecos.count > 0) ? ((NSString*)[gecos objectAtIndex:0]) : @"";
        m_SystemGroups.emplace_back(curr);
    }
    sort(begin(m_SystemGroups), end(m_SystemGroups), [](auto&_1, auto&_2){ return (signed)_1.gr_gid < (signed)_2.gr_gid; });
}

- (void)ShowSheet: (NSWindow *)_window selentries: (const PanelData*)_data handler: (FileSysEntryAttrSheetCompletionHandler) handler
{
    FileSysAttrAlterCommand::GetCommonFSFlagsState(*_data, m_State[0].fsfstate);
    FileSysAttrAlterCommand::GetCommonFSUIDAndGID(*_data, m_State[0].uid, m_HasCommonUID, m_State[0].gid, m_HasCommonGID);
    FileSysAttrAlterCommand::GetCommonFSTimes(*_data, m_State[0].atime, m_HasCommonATime, m_State[0].mtime, m_HasCommonMTime,
                                              m_State[0].ctime, m_HasCommonCTime, m_State[0].btime, m_HasCommonBTime);
    memcpy(&m_State[1], &m_State[0], sizeof(m_State[0]));
    
    m_HasDirectoryEntries = _data->Stats().selected_dirs_amount > 0;
    m_Files.swap(_data->StringsFromSelectedEntries());
    m_RootPath = _data->DirectoryPathWithTrailingSlash();
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    self.ME = self;
    m_Handler = handler;
}
        
- (void)ShowSheet: (NSWindow *)_window data: (const PanelData*)_data index: (unsigned)_ind handler: (FileSysEntryAttrSheetCompletionHandler) handler
{
    auto &item = *_data->EntryAtRawPosition(_ind);
    typedef FileSysAttrAlterCommand _;
    m_State[0].fsfstate[_::fsf_unix_usr_r] = item.UnixMode() & S_IRUSR;
    m_State[0].fsfstate[_::fsf_unix_usr_w] = item.UnixMode() & S_IWUSR;
    m_State[0].fsfstate[_::fsf_unix_usr_x] = item.UnixMode() & S_IXUSR;
    m_State[0].fsfstate[_::fsf_unix_grp_r] = item.UnixMode() & S_IRGRP;
    m_State[0].fsfstate[_::fsf_unix_grp_w] = item.UnixMode() & S_IWGRP;
    m_State[0].fsfstate[_::fsf_unix_grp_x] = item.UnixMode() & S_IXGRP;
    m_State[0].fsfstate[_::fsf_unix_oth_r] = item.UnixMode() & S_IROTH;
    m_State[0].fsfstate[_::fsf_unix_oth_w] = item.UnixMode() & S_IWOTH;
    m_State[0].fsfstate[_::fsf_unix_oth_x] = item.UnixMode() & S_IXOTH;
    m_State[0].fsfstate[_::fsf_unix_suid]  = item.UnixMode() & S_ISUID;
    m_State[0].fsfstate[_::fsf_unix_sgid]  = item.UnixMode() & S_ISGID;
    m_State[0].fsfstate[_::fsf_unix_sticky]= item.UnixMode() & S_ISVTX;
    m_State[0].fsfstate[_::fsf_uf_nodump]    = item.UnixFlags() & UF_NODUMP;
    m_State[0].fsfstate[_::fsf_uf_immutable] = item.UnixFlags() & UF_IMMUTABLE;
    m_State[0].fsfstate[_::fsf_uf_append]    = item.UnixFlags() & UF_APPEND;
    m_State[0].fsfstate[_::fsf_uf_opaque]    = item.UnixFlags() & UF_OPAQUE;
    m_State[0].fsfstate[_::fsf_uf_hidden]    = item.UnixFlags() & UF_HIDDEN;
    m_State[0].fsfstate[_::fsf_sf_archived]  = item.UnixFlags() & SF_ARCHIVED;
    m_State[0].fsfstate[_::fsf_sf_immutable] = item.UnixFlags() & SF_IMMUTABLE;
    m_State[0].fsfstate[_::fsf_sf_append]    = item.UnixFlags() & SF_APPEND;
    m_State[0].uid = item.UnixUID();
    m_State[0].gid = item.UnixGID();
    m_State[0].atime = item.ATime();
    m_State[0].mtime = item.MTime();
    m_State[0].ctime = item.CTime();
    m_State[0].btime = item.BTime();
    m_HasCommonUID = m_HasCommonGID = m_HasCommonATime = m_HasCommonMTime = m_HasCommonCTime = m_HasCommonBTime = true;
    memcpy(&m_State[1], &m_State[0], sizeof(m_State[0]));

    m_HasDirectoryEntries = item.IsDir();
    m_Files.swap(chained_strings(item.Name()));
    m_RootPath = _data->DirectoryPathWithTrailingSlash();
    
    [self LoadUsers];
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    self.ME = self;
    m_Handler = handler;
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
    [[self ATimePicker] setDateValue:[cur dateByAddingTimeInterval:ZeroSecsFromGMT()]];
    m_State[1].atime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::atime] = true;
}

- (IBAction)OnMTimeClear:(id)sender{
    [[self MTimePicker] setDateValue:LongTimeAgo()];
    m_UserDidEditOthers[OtherAttrs::mtime] = false;
}
        
- (IBAction)OnMTimeSet:(id)sender{
    NSDate *cur = [NSDate date];
    [[self MTimePicker] setDateValue:[cur dateByAddingTimeInterval:ZeroSecsFromGMT()]];
    m_State[1].mtime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::mtime] = true;
}

- (IBAction)OnCTimeClear:(id)sender{
    [[self CTimePicker] setDateValue:LongTimeAgo()];
    m_UserDidEditOthers[OtherAttrs::ctime] = false;
}
        
- (IBAction)OnCTimeSet:(id)sender{
    NSDate *cur = [NSDate date];    
    [[self CTimePicker] setDateValue:[cur dateByAddingTimeInterval:ZeroSecsFromGMT()]];
    m_State[1].ctime = [cur timeIntervalSince1970];
    m_UserDidEditOthers[OtherAttrs::ctime] = true;
}

- (IBAction)OnBTimeClear:(id)sender{
    [[self BTimePicker] setDateValue:LongTimeAgo()];
    m_UserDidEditOthers[OtherAttrs::btime] = false;
}

- (IBAction)OnBTimeSet:(id)sender{
    NSDate *cur = [NSDate date];
    [[self BTimePicker] setDateValue:[cur dateByAddingTimeInterval:ZeroSecsFromGMT()]];
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
     m_State[1].fsfstate[FileSysAttrAlterCommand::_f] = state_to_tribool([self _c]); }
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
    NSInteger ind = self.UsersPopUpButton.indexOfSelectedItem;
    if(ind < m_SystemUsers.size()) {
        m_UserDidEditOthers[OtherAttrs::uid] = true;
        m_State[1].uid = m_SystemUsers[ind].pw_uid;
    }
    else {
        m_UserDidEditOthers[OtherAttrs::uid] = false;
        m_State[1].uid = m_State[0].uid; // reset selection to original value if any
    }
}
        
- (IBAction)OnGIDSel:(id)sender
{
    NSInteger ind = self.GroupsPopUpButton.indexOfSelectedItem;
    if(ind < m_SystemGroups.size()) {
        m_UserDidEditOthers[OtherAttrs::gid] = true;
        m_State[1].gid = m_SystemGroups[ind].gr_gid;
    }
    else { // user chose [mixed]
        m_UserDidEditOthers[OtherAttrs::gid] = false;
        m_State[1].gid = m_State[0].gid; // reset selection to original value if any
    }
}

- (IBAction)OnTimeChange:(id)sender
{
    NSInteger secsfromgmt = ZeroSecsFromGMT();
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

- (IBAction)OnApply:(id)sender
{
    // get control's value to secure that user will get the same picture as he see it now
#define DOFLAG(_f, _c)\
m_State[1].fsfstate[FileSysAttrAlterCommand::_f] = state_to_tribool(self._c);
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
    [self OnUIDSel:nil];
    [self OnGIDSel:nil];
    [self OnTimeChange:self.ATimePicker];
    [self OnTimeChange:self.MTimePicker];
    [self OnTimeChange:self.CTimePicker];
    [self OnTimeChange:self.BTimePicker];

    // compose result
    m_Result = make_shared<FileSysAttrAlterCommand>();
    for(int i = 0; i < FileSysAttrAlterCommand::fsf_totalcount; ++i)
        m_Result->flags[i] = m_State[1].fsfstate[i];

    if((m_Result->set_uid = m_UserDidEditOthers[OtherAttrs::uid]) == true)
        m_Result->uid = m_State[1].uid;
    if((m_Result->set_gid = m_UserDidEditOthers[OtherAttrs::gid]) == true)
        m_Result->gid = m_State[1].gid;
    if((m_Result->set_atime = m_UserDidEditOthers[OtherAttrs::atime]) == true)
        m_Result->atime = m_State[1].atime;
    if((m_Result->set_mtime = m_UserDidEditOthers[OtherAttrs::mtime]) == true)
        m_Result->mtime = m_State[1].mtime;
    if((m_Result->set_ctime = m_UserDidEditOthers[OtherAttrs::ctime]) == true)
        m_Result->ctime = m_State[1].ctime;
    if((m_Result->set_btime = m_UserDidEditOthers[OtherAttrs::btime]) == true)
        m_Result->btime = m_State[1].btime;
    m_Result->process_subdirs = m_ProcessSubfolders;
    m_Result->files.swap(m_Files);
    m_Result->root_path = m_RootPath;
    
    [NSApp endSheet:[self window] returnCode:DialogResult::Apply];    
}
        
- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    m_Handler((int)returnCode);
    self.ME = nil; // let ARC do it's duty
    m_Handler = nil;
}

@end
