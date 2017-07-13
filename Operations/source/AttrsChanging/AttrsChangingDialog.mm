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

static AttrsChangingCommand::Permissions ExtractCommon( const vector<VFSListingItem> &_items );
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

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)populate
{
    [self fillPermUIWithPermissions:ExtractCommon(m_Items)];
    [self fillOwnageControls];
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

- (void)fillOwnageControls
{
//    NSSize menu_pic_size;
//    menu_pic_size.width = menu_pic_size.height = [NSFont menuFontOfSize:0].pointSize;
//
//    NSImage *img_user = [NSImage imageNamed:NSImageNameUser];
//    img_user.size = menu_pic_size;
    [self.userPopup removeAllItems];
    for( const auto &i: m_Users ) {
        const auto entry = UserToString(i);
        [self.userPopup addItemWithTitle:entry];
//        self.UsersPopUpButton.lastItem.image = img_user;
//        
//        if(m_ProcessSubfolders) {
//            if(m_HasCommonUID && m_UserDidEditOthers[OtherAttrs::uid] && m_State[1].uid == i.pw_uid )
//                [self.UsersPopUpButton selectItem:self.UsersPopUpButton.lastItem];
//        }
//        else {
//            if(m_HasCommonUID && m_State[1].uid == i.pw_uid)
//                [self.UsersPopUpButton selectItem:self.UsersPopUpButton.lastItem];
//        }
    }
    
    [self.groupPopup removeAllItems];
    for( const auto &i: m_Groups ) {
        const auto entry = GroupToString(i);
        [self.groupPopup addItemWithTitle:entry];

    }

}

- (AttrsChangingCommand::Permissions) extractPermissionsFromUI
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

    return p;
}

- (IBAction)onProcessSubfolder:(id)sender
{
    m_ProcessSubfolders = self.processSubfolders.state;
//    dispatch_to_main_queue([=]{
        [self populate];
//    });
}

- (IBAction)onPermCheckbox:(id)sender
{
    if( const auto b = objc_cast<NSButton>(sender) )
        b.tag++;
}

template <class _InputIterator, class _Predicate>
static optional<bool>
optional_common_bool_value(_InputIterator _first, _InputIterator _last, _Predicate _pred)
{
    if( _first == _last )
        return nullopt;
    
    const optional<bool> value = _pred(*(_first++));
    for(; _first != _last; ++_first )
        if( _pred(*_first) != *value )
            return nullopt;
    return value;
}

static AttrsChangingCommand::Permissions ExtractCommon( const vector<VFSListingItem> &_items )
{
    vector<uint16_t> modes;
    for( const auto &i: _items )
        modes.emplace_back( i.UnixMode() );

    AttrsChangingCommand::Permissions p;

    const auto first = begin(modes), last = end(modes);
    p.usr_r = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IRUSR); });
    p.usr_w = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IWUSR); });
    p.usr_x = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IXUSR); });
    p.grp_r = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IRGRP); });
    p.grp_w = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IWGRP); });
    p.grp_x = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IXGRP); });
    p.oth_r = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IROTH); });
    p.oth_w = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IWOTH); });
    p.oth_x = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_IXOTH); });
    p.suid  = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_ISUID); });
    p.sgid  = optional_common_bool_value(first, last, [](auto m){ return bool(m & S_ISGID); });
    p.sticky= optional_common_bool_value(first, last, [](auto m){ return bool(m & S_ISVTX); });

    return p;
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
