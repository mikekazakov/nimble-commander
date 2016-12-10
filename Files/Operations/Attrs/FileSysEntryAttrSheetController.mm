//
//  FileSysEntryAttrSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 26.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include  <OpenDirectory/OpenDirectory.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "FileSysEntryAttrSheetController.h"
#include "FileSysAttrChangeOperationCommand.h"

namespace {

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
    
}

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

template <class _InputIterator, class _Predicate>
static tribool
all_eq_onoff(_InputIterator __first, _InputIterator __last, _Predicate __pred)
{
    tribool firstval = indeterminate;
    if( __first != __last )
        firstval = bool(__pred(*__first));
    
    for (; __first != __last; ++__first)
        if ( bool(__pred(*__first)) != firstval )
            return indeterminate;
    return firstval;
}

static void GetCommonFSFlagsState(const vector<VFSListingItem>& _items, tribool _state[FileSysAttrAlterCommand::fsf_totalcount])
{
    using _ = FileSysAttrAlterCommand::fsflags;
    // not the most efficient way since we call UnixMode and UnixFlag a lot more than actually can, but it shouldn't be a bottleneck anytime
    _state[_::fsf_unix_usr_r]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IRUSR;          });
    _state[_::fsf_unix_usr_w]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IWUSR;          });
    _state[_::fsf_unix_usr_x]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IXUSR;          });
    _state[_::fsf_unix_grp_r]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IRGRP;          });
    _state[_::fsf_unix_grp_w]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IWGRP;          });
    _state[_::fsf_unix_grp_x]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IXGRP;          });
    _state[_::fsf_unix_oth_r]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IROTH;          });
    _state[_::fsf_unix_oth_w]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IWOTH;          });
    _state[_::fsf_unix_oth_x]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IXOTH;          });
    _state[_::fsf_unix_suid]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_ISUID;          });
    _state[_::fsf_unix_sgid]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_ISGID;          });
    _state[_::fsf_unix_sticky]     = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_ISVTX;          });
    _state[_::fsf_uf_nodump]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_NODUMP;        });
    _state[_::fsf_uf_immutable]    = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_IMMUTABLE;     });
    _state[_::fsf_uf_append]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_APPEND;        });
    _state[_::fsf_uf_opaque]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_OPAQUE;        });
    _state[_::fsf_uf_hidden]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_HIDDEN;        });
    _state[_::fsf_uf_compressed]   = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_COMPRESSED;    });
    _state[_::fsf_uf_tracked]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_TRACKED;       });
    _state[_::fsf_sf_archived]     = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & SF_ARCHIVED;      });
    _state[_::fsf_sf_immutable]    = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & SF_IMMUTABLE;     });
    _state[_::fsf_sf_append]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & SF_APPEND;        });
}

static void GetCommonFSTimes(const vector<VFSListingItem>& _items,
                             time_t &_atime, bool &_has_common_atime,
                             time_t &_mtime, bool &_has_common_mtime,
                             time_t &_ctime, bool &_has_common_ctime,
                             time_t &_btime, bool &_has_common_btime)
{
    _has_common_atime = all_of(begin(_items), end(_items), [&](auto &i){ return i.ATime() == _items.front().ATime(); });
    if( _has_common_atime )
        _atime = _items.front().ATime();
    
    _has_common_mtime = all_of(begin(_items), end(_items), [&](auto &i){ return i.MTime() == _items.front().MTime(); });
    if( _has_common_mtime )
        _mtime = _items.front().MTime();
    
    _has_common_ctime = all_of(begin(_items), end(_items), [&](auto &i){ return i.CTime() == _items.front().CTime(); });
    if( _has_common_ctime )
        _ctime = _items.front().CTime();
    
    _has_common_btime = all_of(begin(_items), end(_items), [&](auto &i){ return i.BTime() == _items.front().BTime(); });
    if( _has_common_btime )
        _btime = _items.front().BTime();
}

static void GetCommonFSUIDAndGID(const vector<VFSListingItem>& _items,
                                 uid_t &_uid,
                                 bool &_has_common_uid,
                                 gid_t &_gid,
                                 bool &_has_common_gid)
{
    _has_common_uid = all_of(begin(_items), end(_items), [&](auto &i){ return i.UnixUID() == _items.front().UnixUID(); });
    if( _has_common_uid )
        _uid = _items.front().UnixUID();
    
    _has_common_gid = all_of(begin(_items), end(_items), [&](auto &i){ return i.UnixGID() == _items.front().UnixGID(); });
    if( _has_common_gid )
        _gid = _items.front().UnixGID();
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

// not used currently
static vector<user_info> LoadUsersWithPasswd()
{
    vector<user_info> result;
    
    setpwent();
    struct passwd *p;
    while( (p = getpwent ()) != NULL ) {
        user_info curr;
        curr.pw_uid = p->pw_uid;
        curr.pw_name = [NSString stringWithUTF8String:p->pw_name];
        curr.pw_gecos = [NSString stringWithUTF8String:p->pw_gecos];
        result.emplace_back(curr);
    }
    endpwent();

    sort(begin(result), end(result), [](auto&_1, auto&_2){ return (signed)_1.pw_uid < (signed)_2.pw_uid; } );
    result.erase(unique(begin(result), end(result), [](auto&_1, auto&_2){ return _1.pw_uid == _2.pw_uid; } ), end(result));
    
    return result;
}

static vector<user_info> LoadUsersWithOD()
{
    vector<user_info> result;
    
    ODNode *root = [ODNode nodeWithSession:ODSession.defaultSession name:@"/Local/Default" error:nil];
    if(!root) {
        NSLog(@"Failed: ODNode *root = [ODNode nodeWithSession:ODSession.defaultSession name:@\"/Local/Default\" error:nil];");
        return {};
    }
    
    ODQuery *query = [ODQuery queryWithNode:root
                             forRecordTypes:kODRecordTypeUsers
                                  attribute:nil
                                  matchType:0
                                queryValues:nil
                           returnAttributes:@[kODAttributeTypeUniqueID, kODAttributeTypeFullName]
                             maximumResults:0
                                      error:nil];
    if( !query ) {
        NSLog(@"Failed: ODQuery *query = [ODQuery queryWithNode:root...");
        return {};
    }
    
    for( ODRecord *r in [query resultsAllowingPartial:NO error:nil] ) {
        NSArray *uid = [r valuesForAttribute:kODAttributeTypeUniqueID error:nil];
        if(uid == nil || uid.count == 0)
            continue; // invalid response, can't handle it
        
        NSArray *gecos = [r valuesForAttribute:kODAttributeTypeFullName error:nil];
        
        user_info curr;
        curr.pw_uid = (uid_t) [uid[0] integerValue];
        curr.pw_name = r.recordName;
        curr.pw_gecos = (gecos.count > 0) ? ((NSString*)[gecos objectAtIndex:0]) : @"";
        result.emplace_back(curr);
    }

    sort(begin(result), end(result), [](auto&_1, auto&_2){ return (signed)_1.pw_uid < (signed)_2.pw_uid; } );
    result.erase(unique(begin(result), end(result), [](auto&_1, auto&_2){ return _1.pw_uid == _2.pw_uid; } ), end(result));
    
    return result;
}

static vector<group_info> LoadGroupsWithOD()
{
    vector<group_info> result;
    
    ODNode *root = [ODNode nodeWithSession:ODSession.defaultSession name:@"/Local/Default" error:nil];
    if( !root ) {
        NSLog(@"Failed: ODNode *root = [ODNode nodeWithSession:ODSession.defaultSession name:@\"/Local/Default\" error:nil];");
        return {};
    }
    
    ODQuery *query = [ODQuery queryWithNode:root
                             forRecordTypes:kODRecordTypeGroups
                                  attribute:nil
                                  matchType:0
                                queryValues:nil
                           returnAttributes:@[kODAttributeTypePrimaryGroupID, kODAttributeTypeFullName]
                             maximumResults:0
                                      error:nil];
    if( !query ) {
        NSLog(@"Failed: ODQuery *query = [ODQuery queryWithNode:root...");
        return {};
    }
    
    for (ODRecord *r in [query resultsAllowingPartial:NO error:nil]) {
        NSArray *gid = [r valuesForAttribute:kODAttributeTypePrimaryGroupID error:nil];
        if(gid == nil || gid.count == 0)
            continue; //invalid response
        
        NSArray *gecos = [r valuesForAttribute:kODAttributeTypeFullName error:nil];
        
        group_info curr;
        curr.gr_gid = (gid_t) [gid[0] integerValue];
        curr.gr_name = r.recordName;
        curr.gr_gecos = (gecos.count > 0) ? ((NSString*)[gecos objectAtIndex:0]) : @"";
        result.emplace_back(curr);
    }
    
    sort(begin(result), end(result), [](auto&_1, auto&_2){ return (signed)_1.gr_gid < (signed)_2.gr_gid; } );
    
    return result;
}


@interface FileSysEntryAttrSheetController ()

@property (strong) IBOutlet NSButton *OwnerReadCheck;
@property (strong) IBOutlet NSButton *OwnerWriteCheck;
@property (strong) IBOutlet NSButton *OwnerExecCheck;
@property (strong) IBOutlet NSButton *GroupReadCheck;
@property (strong) IBOutlet NSButton *GroupWriteCheck;
@property (strong) IBOutlet NSButton *GroupExecCheck;
@property (strong) IBOutlet NSButton *OthersReadCheck;
@property (strong) IBOutlet NSButton *OthersWriteCheck;
@property (strong) IBOutlet NSButton *OthersExecCheck;
@property (strong) IBOutlet NSButton *StickyCheck;
@property (strong) IBOutlet NSButton *NoDumpCheck;
@property (strong) IBOutlet NSButton *UserImmutableCheck;
@property (strong) IBOutlet NSButton *UserAppendCheck;
@property (strong) IBOutlet NSButton *UserCompressedCheck;
@property (strong) IBOutlet NSButton *UserTrackedCheck;
@property (strong) IBOutlet NSButton *OpaqueCheck;
@property (strong) IBOutlet NSButton *HiddenCheck;
@property (strong) IBOutlet NSButton *ArchivedCheck;
@property (strong) IBOutlet NSButton *SystemImmutableCheck;
@property (strong) IBOutlet NSButton *SystemAppendCheck;
@property (strong) IBOutlet NSButton *SetUIDCheck;
@property (strong) IBOutlet NSButton *SetGIDCheck;
@property (strong) IBOutlet NSPopUpButton *UsersPopUpButton;
@property (strong) IBOutlet NSPopUpButton *GroupsPopUpButton;

@property (strong) IBOutlet NSButton *ATimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *ATimePicker;
@property (strong) IBOutlet NSButton *MTimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *MTimePicker;
@property (strong) IBOutlet NSButton *CTimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *CTimePicker;
@property (strong) IBOutlet NSButton *BTimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *BTimePicker;
@property (strong) IBOutlet NSButton *ProcessSubfoldersCheck;
@property (strong) IBOutlet NSTextField *Title;

@property (strong) IBOutlet NSStackView *StackView;
@property (strong) IBOutlet NSView *StackViewTop;
@property (strong) IBOutlet NSView *StackViewMiddle;
@property (strong) IBOutlet NSView *StackViewBottom;
@property (strong) IBOutlet NSView *StackViewFooter;

- (IBAction)OnApply:(id)sender;
- (IBAction)OnCancel:(id)sender;
- (IBAction)OnATimeSet:(id)sender;
- (IBAction)OnMTimeSet:(id)sender;
- (IBAction)OnCTimeSet:(id)sender;
- (IBAction)OnBTimeSet:(id)sender;
- (IBAction)OnProcessSubfolders:(id)sender;
- (IBAction)OnFlag:(id)sender;
- (IBAction)OnUIDSel:(id)sender;
- (IBAction)OnGIDSel:(id)sender;
- (IBAction)OnTimeChange:(id)sender;
- (IBAction)OnTimePickerEnabled:(id)sender;

@end

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
    
    bool                                m_UserDidEditFlags[FileSysAttrAlterCommand::fsf_totalcount];
    bool                                m_UserDidEditOthers[OtherAttrs::total];
    bool                                m_HasCommonUID;
    bool                                m_HasCommonGID;
    bool                                m_HasCommonATime;
    bool                                m_HasCommonMTime;
    bool                                m_HasCommonCTime;
    bool                                m_HasCommonBTime;
    bool                                m_ProcessSubfolders;
    vector<user_info>                   m_SystemUsers;
    vector<group_info>                  m_SystemGroups;
    shared_ptr<const vector<VFSListingItem>>    m_Items;
    shared_ptr<FileSysAttrAlterCommand>         m_Result;
}

@synthesize result = m_Result;

- (FileSysEntryAttrSheetController*)initWithItems:(const shared_ptr<const vector<VFSListingItem>>&)_items
{
    if(self = [super init]) {
        m_Items = _items;
        
        GetCommonFSFlagsState(*m_Items,
                              m_State[0].fsfstate);
        GetCommonFSUIDAndGID(*m_Items,
                             m_State[0].uid, m_HasCommonUID,
                             m_State[0].gid, m_HasCommonGID);
        GetCommonFSTimes(*m_Items,
                         m_State[0].atime, m_HasCommonATime,
                         m_State[0].mtime, m_HasCommonMTime,
                         m_State[0].ctime, m_HasCommonCTime,
                         m_State[0].btime, m_HasCommonBTime);
        m_State[1] = m_State[0];
        
        memset(m_UserDidEditFlags, 0, sizeof(m_UserDidEditFlags));
        memset(m_UserDidEditOthers, 0, sizeof(m_UserDidEditOthers));
        
        m_SystemUsers = LoadUsersWithOD();
        m_SystemGroups = LoadGroupsWithOD();
    }
    return self;
}

- (bool) hasDirectoryEntries
{
    return any_of(begin(*m_Items), end(*m_Items), [](auto &i){ return i.IsDir(); } );
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.StackView addView:self.StackViewTop inGravity:NSStackViewGravityTop];
    [self.StackView addView:self.StackViewMiddle inGravity:NSStackViewGravityCenter];
    [self.StackView addView:self.StackViewBottom inGravity:NSStackViewGravityBottom];
    [self.StackView addView:self.StackViewFooter inGravity:NSStackViewGravityBottom];
    
    // Set title.
    if (m_Items->size() == 1)
        self.Title.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Change file attributes for \u201c%@\u201d",
                                                                              "Title for file attributes sheet, single item"),
                                    [NSString stringWithUTF8String:m_Items->front().Name()]];
    else
        self.Title.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Change file attributes for %@ selected items",
                                                                              "Title for file attributes sheet, multiple items"),
                                  [NSNumber numberWithInt:(int)m_Items->size()]];
    
    [self PopulateControls];
    GoogleAnalytics::Instance().PostScreenView("Unix Attributes");
}

- (void) PopulateControls
{
    self.ProcessSubfoldersCheck.hidden = !self.hasDirectoryEntries;
    NSString *mixed_title = NSLocalizedString(@"[Mixed]", "Combo box element available when multiple elements are selected with different values");
    
    typedef FileSysAttrAlterCommand _;
    auto doflag = [=](_::fsflags flag, NSButton *ctrl) {
        ctrl.allowsMixedState = m_ProcessSubfolders ?
            true :
            indeterminate(m_State[0].fsfstate[flag]);
        ctrl.state = m_ProcessSubfolders ?
            tribool_to_state(m_UserDidEditFlags[flag] ?
                             m_State[1].fsfstate[flag] :
                             indeterminate):
            tribool_to_state(m_State[1].fsfstate[flag]);
    };
    doflag(_::fsf_unix_usr_r  , _OwnerReadCheck);
    doflag(_::fsf_unix_usr_w  , _OwnerWriteCheck);
    doflag(_::fsf_unix_usr_x  , _OwnerExecCheck);
    doflag(_::fsf_unix_grp_r  , _GroupReadCheck);
    doflag(_::fsf_unix_grp_w  , _GroupWriteCheck);
    doflag(_::fsf_unix_grp_x  , _GroupExecCheck);
    doflag(_::fsf_unix_oth_r  , _OthersReadCheck);
    doflag(_::fsf_unix_oth_w  , _OthersWriteCheck);
    doflag(_::fsf_unix_oth_x  , _OthersExecCheck);
    doflag(_::fsf_unix_suid   , _SetUIDCheck);
    doflag(_::fsf_unix_sgid   , _SetGIDCheck);
    doflag(_::fsf_unix_sticky , _StickyCheck);
    doflag(_::fsf_uf_nodump   , _NoDumpCheck);
    doflag(_::fsf_uf_immutable, _UserImmutableCheck);
    doflag(_::fsf_uf_append   , _UserAppendCheck);
    doflag(_::fsf_uf_opaque   , _OpaqueCheck);
    doflag(_::fsf_uf_hidden   , _HiddenCheck);
    doflag(_::fsf_uf_compressed,_UserCompressedCheck);
    doflag(_::fsf_uf_tracked  , _UserTrackedCheck);
    doflag(_::fsf_sf_archived , _ArchivedCheck);
    doflag(_::fsf_sf_immutable, _SystemImmutableCheck);
    doflag(_::fsf_sf_append   , _SystemAppendCheck);

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
        [self.UsersPopUpButton addItemWithTitle:mixed_title];
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
        [self.GroupsPopUpButton addItemWithTitle:mixed_title];
        self.GroupsPopUpButton.lastItem.image = img_group;
        if(!m_ProcessSubfolders || !m_UserDidEditOthers[OtherAttrs::gid])
            [self.GroupsPopUpButton selectItem:self.GroupsPopUpButton.lastItem];
    }
    
    

    // Time section
    NSDate* current_date = NSDate.date;
    auto turn_on = [=](NSDatePicker *_picker, NSButton *_enabler, time_t _time) {
        [self setTimePickerOn:_picker withEnabler:_enabler andDate:[NSDate dateWithTimeIntervalSince1970:_time]];
    };
    auto turn_off = [=](NSDatePicker *_picker, NSButton *_enabler, time_t _time) {
        [self setTimePickerOff:_picker withEnabler:_enabler andDate:[NSDate dateWithTimeIntervalSince1970:_time]];
    };
    
    if( (!m_ProcessSubfolders && m_HasCommonATime) || m_UserDidEditOthers[OtherAttrs::atime] )
        turn_on(self.ATimePicker, self.ATimePickerEnabled, m_State[1].atime);
    else
        turn_off(self.ATimePicker, self.ATimePickerEnabled, m_HasCommonATime ? m_State[1].atime : current_date.timeIntervalSince1970);

    if( (!m_ProcessSubfolders && m_HasCommonMTime) || m_UserDidEditOthers[OtherAttrs::mtime] )
        turn_on(self.MTimePicker, self.MTimePickerEnabled, m_State[1].mtime);
    else
        turn_off(self.MTimePicker, self.MTimePickerEnabled, m_HasCommonMTime ? m_State[1].mtime : current_date.timeIntervalSince1970);

    if( (!m_ProcessSubfolders && m_HasCommonCTime) || m_UserDidEditOthers[OtherAttrs::ctime] )
        turn_on(self.CTimePicker, self.CTimePickerEnabled, m_State[1].ctime);
    else
        turn_off(self.CTimePicker, self.CTimePickerEnabled, m_HasCommonCTime ? m_State[1].ctime : current_date.timeIntervalSince1970);

    if( (!m_ProcessSubfolders && m_HasCommonBTime) || m_UserDidEditOthers[OtherAttrs::btime] )
        turn_on(self.BTimePicker, self.BTimePickerEnabled, m_State[1].btime);
    else
        turn_off(self.BTimePicker, self.BTimePickerEnabled, m_HasCommonBTime ? m_State[1].btime : current_date.timeIntervalSince1970);
}


- (IBAction)OnTimePickerEnabled:(id)sender
{
    auto button = objc_cast<NSButton>(sender);
    if(!button)
        return;
    bool on = button.state == NSOnState;
    if( button == self.ATimePickerEnabled ) {
        if( on )
            [self setTimePickerOn:self.ATimePicker
                      withEnabler:button
                          andDate:((m_HasCommonATime) || m_UserDidEditOthers[OtherAttrs::atime]) ?
                            [NSDate dateWithTimeIntervalSince1970:m_State[1].atime] :
                            NSDate.date
             ];
        else
            [self setTimePickerOff:self.ATimePicker withEnabler:button andDate:nil];
        m_UserDidEditOthers[OtherAttrs::atime] = on;
    }
    if( button == self.MTimePickerEnabled ) {
        if( on )
            [self setTimePickerOn:self.MTimePicker
                      withEnabler:button
                          andDate:((m_HasCommonMTime) || m_UserDidEditOthers[OtherAttrs::mtime]) ?
                            [NSDate dateWithTimeIntervalSince1970:m_State[1].mtime] :
                            NSDate.date
             ];
        else
            [self setTimePickerOff:self.MTimePicker withEnabler:button andDate:nil];
        m_UserDidEditOthers[OtherAttrs::mtime] = on;
    }
    if( button == self.CTimePickerEnabled ) {
        if( on )
            [self setTimePickerOn:self.CTimePicker
                      withEnabler:button
                          andDate:((m_HasCommonCTime) || m_UserDidEditOthers[OtherAttrs::ctime]) ?
             [NSDate dateWithTimeIntervalSince1970:m_State[1].ctime] :
             NSDate.date
             ];
        else
            [self setTimePickerOff:self.CTimePicker withEnabler:button andDate:nil];
        m_UserDidEditOthers[OtherAttrs::ctime] = on;
    }
    if( button == self.BTimePickerEnabled ) {
        if( on )
            [self setTimePickerOn:self.BTimePicker
                      withEnabler:button
                          andDate:((m_HasCommonBTime) || m_UserDidEditOthers[OtherAttrs::btime]) ?
             [NSDate dateWithTimeIntervalSince1970:m_State[1].btime] :
             NSDate.date
             ];
        else
            [self setTimePickerOff:self.BTimePicker withEnabler:button andDate:nil];
        m_UserDidEditOthers[OtherAttrs::btime] = on;
    }
}

- (IBAction)OnCancel:(id)sender{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnATimeSet:(id)sender
{
    NSDate *cur = NSDate.date;
    [self setTimePickerOn:self.ATimePicker withEnabler:self.ATimePickerEnabled andDate:cur];
    m_State[1].atime = cur.timeIntervalSince1970;
    m_UserDidEditOthers[OtherAttrs::atime] = true;
}

- (void)setTimePickerOff:(NSDatePicker *)picker withEnabler:(NSButton *)enabler andDate:(NSDate*)date
{
    if(date)
        picker.dateValue = date;
    picker.enabled = false;
    picker.textColor = NSColor.disabledControlTextColor;
    enabler.state = NSOffState;
}

- (void)setTimePickerOn:(NSDatePicker *)picker withEnabler:(NSButton *)enabler andDate:(NSDate*)date
{
    if(date)
        picker.dateValue = date;
    picker.enabled = true;
    picker.textColor = NSColor.controlTextColor;
    enabler.state = NSOnState;
}

- (IBAction)OnMTimeSet:(id)sender
{
    NSDate *cur = NSDate.date;
    [self setTimePickerOn:self.MTimePicker withEnabler:self.MTimePickerEnabled andDate:cur];
    m_State[1].mtime = cur.timeIntervalSince1970;
    m_UserDidEditOthers[OtherAttrs::mtime] = true;
}

- (IBAction)OnCTimeSet:(id)sender
{
    NSDate *cur = NSDate.date;
    [self setTimePickerOn:self.CTimePicker withEnabler:self.CTimePickerEnabled andDate:cur];
    m_State[1].ctime = cur.timeIntervalSince1970;
    m_UserDidEditOthers[OtherAttrs::ctime] = true;
}

- (IBAction)OnBTimeSet:(id)sender
{
    NSDate *cur = NSDate.date;
    [self setTimePickerOn:self.BTimePicker withEnabler:self.BTimePickerEnabled andDate:cur];
    m_State[1].btime = cur.timeIntervalSince1970;
    m_UserDidEditOthers[OtherAttrs::btime] = true;
}

- (IBAction)OnProcessSubfolders:(id)sender
{
    m_ProcessSubfolders = self.ProcessSubfoldersCheck.state == NSOnState;
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
    DOFLAG(fsf_uf_tracked  , UserTrackedCheck);
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
    NSDatePicker *picker = objc_cast<NSDatePicker>(sender);
    if( !picker )
        return;
    
    NSDate *date = picker.dateValue;
    if(sender == self.ATimePicker) {
        m_UserDidEditOthers[OtherAttrs::atime] = true;
        m_State[1].atime = date.timeIntervalSince1970;
    }
    else if(sender == self.MTimePicker) {
        m_UserDidEditOthers[OtherAttrs::mtime] = true;
        m_State[1].mtime = date.timeIntervalSince1970;
    }
    else if(sender == self.CTimePicker) {
        m_UserDidEditOthers[OtherAttrs::ctime] = true;
        m_State[1].ctime = date.timeIntervalSince1970;
    }
    else if(sender == self.BTimePicker) {
        m_UserDidEditOthers[OtherAttrs::btime] = true;
        m_State[1].btime = date.timeIntervalSince1970;
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
    DOFLAG(fsf_uf_tracked  , UserTrackedCheck);    
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

    if( m_UserDidEditOthers[OtherAttrs::uid] )
        m_Result->uid = m_State[1].uid;
    if( m_UserDidEditOthers[OtherAttrs::gid] )
        m_Result->gid = m_State[1].gid;
    if( m_UserDidEditOthers[OtherAttrs::atime] )
        m_Result->atime = m_State[1].atime;
    if( m_UserDidEditOthers[OtherAttrs::mtime] )
        m_Result->mtime = m_State[1].mtime;
    if( m_UserDidEditOthers[OtherAttrs::ctime] )
        m_Result->ctime = m_State[1].ctime;
    if( m_UserDidEditOthers[OtherAttrs::btime] )
        m_Result->btime = m_State[1].btime;
    m_Result->process_subdirs = m_ProcessSubfolders;
    m_Result->items = m_Items;
    
    [self endSheet:NSModalResponseOK];
}

@end
