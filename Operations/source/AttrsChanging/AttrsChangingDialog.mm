#include "AttrsChangingDialog.h"
#include <VFS/VFS.h>

using namespace nc::ops;

@interface NCOpsAttrsChangingDialog ()
@property (strong) IBOutlet NSStackView *stackView;
@property (strong) IBOutlet NSView *permissionsBlockView;
@property (strong) IBOutlet NSView *ownageBlockView;


@property (strong) IBOutlet NSButton *permUsrR;
@property (strong) IBOutlet NSButton *permUsrW;
@property (strong) IBOutlet NSButton *permUsrX;
@property (strong) IBOutlet NSButton *permGrpR;
@property (strong) IBOutlet NSButton *permGrpW;
@property (strong) IBOutlet NSButton *permGrpX;
@property (strong) IBOutlet NSButton *permOthR;
@property (strong) IBOutlet NSButton *permOthW;
@property (strong) IBOutlet NSButton *permOthX;
@property (strong) IBOutlet NSButton *permSUID;
@property (strong) IBOutlet NSButton *permSGID;
@property (strong) IBOutlet NSButton *permSticky;

@property (strong) IBOutlet NSPopUpButton *userPopup;
@property (strong) IBOutlet NSPopUpButton *groupPopup;

@property (strong) IBOutlet NSButton *processSubfolders;

@end

static AttrsChangingCommand::Permissions
    ExtractCommonPermissions( const vector<VFSListingItem> &_items );
static AttrsChangingCommand::Ownage
    ExtractCommonOwnage( const vector<VFSListingItem> &_items );


static NSString *UserToString( const VFSUser &_user );
static NSString *GroupToString( const VFSGroup &_group );

@implementation NCOpsAttrsChangingDialog
{
    vector<VFSListingItem> m_Items;
    bool m_ProcessSubfolders;
    
    AttrsChangingCommand m_Command;
    vector<VFSUser> m_Users;
    vector<VFSGroup> m_Groups;
}

@synthesize command = m_Command;

- (instancetype) initWithItems:(vector<VFSListingItem>)_items
{
    self = [super initWithWindowNibName:@"AttrsChangingDialog"];
    if( self ) {
        m_Items = move(_items);
        m_ProcessSubfolders = false;
        m_Items.front().Host()->FetchUsers(m_Users);
        m_Items.front().Host()->FetchGroups(m_Groups);
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.stackView addView:self.permissionsBlockView inGravity:NSStackViewGravityTop];
    [self.stackView addView:self.ownageBlockView inGravity:NSStackViewGravityCenter];

    [self populate];
}

- (IBAction)onOK:(id)sender
{
    m_Command.items = m_Items;
    m_Command.apply_to_subdirs = m_ProcessSubfolders;
    m_Command.permissions = [self extractPermissionsFromUI];
    m_Command.ownage = [self extractOwnageFromUI];

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)populate
{
    [self fillPermUIWithPermissions:ExtractCommonPermissions(m_Items)];
    [self fillOwnageControls:ExtractCommonOwnage(m_Items)];
}

- (void)fillPermUIWithPermissions:(const AttrsChangingCommand::Permissions&)_p
{
    const auto m = [=](NSButton *_b, optional<bool> _v) {
        const auto has_user_input = _b.tag > 0;
        if( m_ProcessSubfolders ) {
            _b.allowsMixedState = true;
            if( !has_user_input )
                _b.state = NSMixedState;
        }
        else {
            if( has_user_input ) {
                if( _b.state == NSMixedState && _v )
                    _b.state = *_v;
                _b.allowsMixedState = !bool(_v);
            }
            else {
                _b.allowsMixedState = !bool(_v);
                _b.state = _v ? *_v : NSMixedState;
            }
        }
        // these two lines are intended to remove a strange behaviour of non-redrawing NSButton
        // on 10.12.4
        _b.enabled = false;
        _b.enabled = true;
    };

    const auto fr = self.window.firstResponder;

    m( self.permUsrR,  _p.usr_r );
    m( self.permUsrW,  _p.usr_w );
    m( self.permUsrX,  _p.usr_x );
    m( self.permGrpR,  _p.grp_r );
    m( self.permGrpW,  _p.grp_w );
    m( self.permGrpX,  _p.grp_x );
    m( self.permOthR,  _p.oth_r );
    m( self.permOthW,  _p.oth_w );
    m( self.permOthX,  _p.oth_x );
    m( self.permSUID,  _p.suid  );
    m( self.permSGID,  _p.sgid  );
    m( self.permSticky,_p.sticky);
    
    [self.window makeFirstResponder:fr];
}

- (void)makeDefaultOwnerSelection:(const AttrsChangingCommand::Ownage&)_o
{
    if( m_ProcessSubfolders ) {
        [self.userPopup selectItemWithTag:-1];
    }
    else {
        if( _o.uid )
            [self.userPopup selectItemWithTag:*_o.uid];
        else
            [self.userPopup selectItemWithTag:-1];
    }
}

- (void)makeDefaultGroupSelection:(const AttrsChangingCommand::Ownage&)_o
{
    if( m_ProcessSubfolders ) {
        [self.groupPopup selectItemWithTag:-1];
    }
    else {
        if( _o.gid )
            [self.groupPopup selectItemWithTag:*_o.gid];
        else
            [self.groupPopup selectItemWithTag:-1];
    }
}

static NSImage *UserIcon()
{
    static const auto icon = []{
        const auto img = [NSImage imageNamed:NSImageNameUser];
        img.size = NSMakeSize([NSFont menuFontOfSize:0].pointSize,
                              [NSFont menuFontOfSize:0].pointSize);
        return img;
    }();
    return icon;
}

static NSImage *GroupIcon()
{
    static const auto icon = []{
        const auto img = [NSImage imageNamed:NSImageNameUserGroup];
        img.size = NSMakeSize([NSFont menuFontOfSize:0].pointSize,
                              [NSFont menuFontOfSize:0].pointSize);
        return img;
    }();
    return icon;
}

static const auto g_MixedOwnageTitle = @"[???]";

- (void)fillOwner:(const AttrsChangingCommand::Ownage&)_o
{
    const auto popup = self.userPopup;
    const auto previous_selection = popup.tag > 0 ?
        optional<long>{popup.selectedTag} :
        optional<long>{};
    [popup removeAllItems];
    for( const auto &i: m_Users ) {
        const auto entry = UserToString(i);
        [popup addItemWithTitle:entry];
        popup.lastItem.tag = i.uid;
        popup.lastItem.image = UserIcon();
    }
    
    if( !_o.uid || m_ProcessSubfolders ) {
        [popup addItemWithTitle:g_MixedOwnageTitle];
        popup.lastItem.tag = -1;
        popup.lastItem.image = UserIcon();
    }
    
    if( !previous_selection || ![popup selectItemWithTag:*previous_selection] )
        [self makeDefaultOwnerSelection:_o];
}

- (void)fillGroup:(const AttrsChangingCommand::Ownage&)_o
{
    const auto popup = self.groupPopup;
    const auto previous_selection = popup.tag > 0 ?
        optional<long>{self.groupPopup.selectedTag} :
        optional<long>{};
    
    [popup removeAllItems];
    for( const auto &i: m_Groups ) {
        const auto entry = GroupToString(i);
        [popup addItemWithTitle:entry];
        popup.lastItem.tag = i.gid;
        popup.lastItem.image = GroupIcon();
    }
    
    if( !_o.gid || m_ProcessSubfolders ) {
        [popup addItemWithTitle:g_MixedOwnageTitle];
        popup.lastItem.tag = -1;
        popup.lastItem.image = GroupIcon();
    }
    if( !previous_selection || ![popup selectItemWithTag:*previous_selection] )
        [self makeDefaultGroupSelection:_o];
}

- (void)fillOwnageControls:(const AttrsChangingCommand::Ownage&)_o
{
    [self fillOwner:_o];
    [self fillGroup:_o];
}

- (optional<AttrsChangingCommand::Permissions>) extractPermissionsFromUI
{
    AttrsChangingCommand::Permissions p;

    auto m = [](NSButton *_b, optional<bool> &_v) {
        const auto state = _b.state;
        if( state == NSOnState )
            _v = true;
        else if( state == NSOffState )
            _v = false;
    };
    
    m( self.permUsrR,  p.usr_r );
    m( self.permUsrW,  p.usr_w );
    m( self.permUsrX,  p.usr_x );
    m( self.permGrpR,  p.grp_r );
    m( self.permGrpW,  p.grp_w );
    m( self.permGrpX,  p.grp_x );
    m( self.permOthR,  p.oth_r );
    m( self.permOthW,  p.oth_w );
    m( self.permOthX,  p.oth_x );
    m( self.permSUID,  p.suid  );
    m( self.permSGID,  p.sgid  );
    m( self.permSticky,p.sticky);

    if( !p.usr_r && !p.usr_w && !p.usr_x && !p.grp_r && !p.grp_w && !p.grp_x &&
        !p.oth_r && !p.oth_w && !p.oth_x && !p.suid  && !p.sgid  && !p.sticky )
        return nullopt;

    const auto common = ExtractCommonPermissions(m_Items);
    if( !m_ProcessSubfolders &&
        p.usr_r == common.usr_r &&
        p.usr_w == common.usr_w &&
        p.usr_x == common.usr_x &&
        p.grp_r == common.grp_r &&
        p.grp_w == common.grp_w &&
        p.grp_x == common.grp_x &&
        p.oth_r == common.oth_r &&
        p.oth_w == common.oth_w &&
        p.oth_x == common.oth_x &&
        p.suid  == common.suid  &&
        p.sgid  == common.sgid  &&
        p.sticky== common.sticky )
        return nullopt;
    
    return p;
}

- (optional<AttrsChangingCommand::Ownage>) extractOwnageFromUI
{
   AttrsChangingCommand::Ownage o;
   if( const auto u = self.userPopup.selectedTag; u >= 0 )
       o.uid = (uint32_t)u;
   if( const auto g = self.groupPopup.selectedTag; g >= 0 )
       o.gid = (uint32_t)g;
   
    if( !o.uid && !o.gid )
        return nullopt;
   
    const auto common = ExtractCommonOwnage(m_Items);
    if( !m_ProcessSubfolders &&
        o.uid == common.uid  &&
        o.gid == common.gid   )
        return nullopt;
    
    return o;
}

- (IBAction)onProcessSubfolder:(id)sender
{
    m_ProcessSubfolders = self.processSubfolders.state;
    [self populate];
}

- (IBAction)onPermCheckbox:(id)sender
{
    if( const auto b = objc_cast<NSButton>(sender) )
        b.tag++;
}

- (IBAction)onOwnagePopup:(id)sender
{
    if( const auto b = objc_cast<NSPopUpButton>(sender) )
        b.tag++;
}

template <class _InputIterator, class _Predicate>
static auto optional_common_value(_InputIterator _first,
                                  _InputIterator _last,
                                  _Predicate _pred)
-> optional<decay_t<decltype(_pred(*_first))>>
{
    if( _first == _last )
        return nullopt;
    
    const optional<decay_t<decltype(_pred(*_first))>> value = _pred(*(_first++));
    for(; _first != _last; ++_first )
        if( _pred(*_first) != *value )
            return nullopt;
    return value;
}

static AttrsChangingCommand::Permissions ExtractCommonPermissions
( const vector<VFSListingItem> &_items )
{
    vector<uint16_t> modes;
    for( const auto &i: _items )
        modes.emplace_back( i.UnixMode() );

    AttrsChangingCommand::Permissions p;

    const auto first = begin(modes), last = end(modes);
    p.usr_r = optional_common_value(first, last, [](auto m)->bool{ return m & S_IRUSR; });
    p.usr_w = optional_common_value(first, last, [](auto m)->bool{ return m & S_IWUSR; });
    p.usr_x = optional_common_value(first, last, [](auto m)->bool{ return m & S_IXUSR; });
    p.grp_r = optional_common_value(first, last, [](auto m)->bool{ return m & S_IRGRP; });
    p.grp_w = optional_common_value(first, last, [](auto m)->bool{ return m & S_IWGRP; });
    p.grp_x = optional_common_value(first, last, [](auto m)->bool{ return m & S_IXGRP; });
    p.oth_r = optional_common_value(first, last, [](auto m)->bool{ return m & S_IROTH; });
    p.oth_w = optional_common_value(first, last, [](auto m)->bool{ return m & S_IWOTH; });
    p.oth_x = optional_common_value(first, last, [](auto m)->bool{ return m & S_IXOTH; });
    p.suid  = optional_common_value(first, last, [](auto m)->bool{ return m & S_ISUID; });
    p.sgid  = optional_common_value(first, last, [](auto m)->bool{ return m & S_ISGID; });
    p.sticky= optional_common_value(first, last, [](auto m)->bool{ return m & S_ISVTX; });

    return p;
}

static AttrsChangingCommand::Ownage
ExtractCommonOwnage( const vector<VFSListingItem> &_items )
{
    AttrsChangingCommand::Ownage o;
    o.uid = optional_common_value(begin(_items), end(_items), [](auto &i){ return i.UnixUID(); });
    o.gid = optional_common_value(begin(_items), end(_items), [](auto &i){ return i.UnixGID(); });
    return o;
}

static NSString *UserToString( const VFSUser &_user )
{
    if( _user.gecos.empty() )
        return [NSString stringWithFormat:@"%@ (%d)",
                [NSString stringWithUTF8StdString:_user.name],
                signed(_user.uid)];
    else
        return [NSString stringWithFormat:@"%@ (%d) - %@",
                [NSString stringWithUTF8StdString:_user.name],
                signed(_user.uid),
                [NSString stringWithUTF8StdString:_user.gecos]];
}

static NSString *GroupToString( const VFSGroup &_group )
{
    if( _group.gecos.empty() )
        return [NSString stringWithFormat:@"%@ (%d)",
                [NSString stringWithUTF8StdString:_group.name],
                signed(_group.gid)];
    else
        return [NSString stringWithFormat:@"%@ (%d) - %@",
                [NSString stringWithUTF8StdString:_group.name],
                signed(_group.gid),
                [NSString stringWithUTF8StdString:_group.gecos]];
}

@end
