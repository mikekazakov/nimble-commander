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

static NSInteger fsfstate_to_bs(FileSysAttrAlterCommand::fsfstate _s)
{
    if(_s == FileSysAttrAlterCommand::fsf_off) return NSOffState;
    else if(_s == FileSysAttrAlterCommand::fsf_on) return NSOnState;
    else return NSMixedState;
}

@implementation FileSysEntryAttrSheetController
{
    FileSysAttrAlterCommand::fsfstate m_FSFState[FileSysAttrAlterCommand::fsf_totalcount];
    uid_t                             m_CommonUID;
    bool                              m_HasCommonUID;
    gid_t                             m_CommonGID;
    bool                              m_HasCommonGID;
    std::vector<user_info>            m_SystemUsers;
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
    
    
    [[self UsersPopUpButton] removeAllItems];
    for(const auto &i: m_SystemUsers)
    {
        NSString *ent = [NSString stringWithFormat:@"%@ (%d) - %@",
                         [NSString stringWithUTF8String:i.pw_name],
                         i.pw_uid,
                         [NSString stringWithUTF8String:i.pw_gecos]
                        ];
        [[self UsersPopUpButton] addItemWithTitle:ent];
        
        if(m_HasCommonUID && m_CommonUID == i.pw_uid)
            [[self UsersPopUpButton] selectItemAtIndex:[[self UsersPopUpButton] numberOfItems]-1 ];
    }
    
    if(!m_HasCommonUID)
    {
        [[self UsersPopUpButton] addItemWithTitle:@"???"];
        [[self UsersPopUpButton] selectItemAtIndex:[[self UsersPopUpButton] numberOfItems]-1 ];
    }
    
    
}

- (void) LoadUsers
{
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
    
    setgrent();
    
    while(struct group *ent = getgrent())
    {
        // TODO: find where to get gecos for group???
    }
    
    endgrent();
}

- (void)ShowSheet: (NSWindow *)_window entries: (const PanelData*)_data
{
    FileSysAttrAlterCommand::GetCommonFSFlagsState(*_data, m_FSFState);
    FileSysAttrAlterCommand::GetCommonFSUIDAndGID(*_data, m_CommonUID, m_HasCommonUID, m_CommonGID, m_HasCommonGID);
    
    [self LoadUsers];
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    self.ME = self;
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    self.ME = nil; // let ARC do it's duty
}
@end
