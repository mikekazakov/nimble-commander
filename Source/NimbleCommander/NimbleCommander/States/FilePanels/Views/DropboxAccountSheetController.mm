// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DropboxAccountSheetController.h"
#include <VFS/NetDropbox.h>
#include <NimbleCommander/Bootstrap/NCE.h>
#include <Utility/StringExtras.h>
#include <Base/dispatch_cpp.h>

using namespace nc;
using vfs::dropbox::Authenticator;

namespace {

enum class State : uint8_t {
    Default = 0,
    Validating = 1,
    Success = 2,
    Failure = 3
};

} // namespace

@interface DropboxAccountSheetController ()

@property(nonatomic) State state;
@property(nonatomic) bool isValid;
@property(nonatomic) bool isValidating;
@property(nonatomic) bool isSuccess;
@property(nonatomic) bool isFailure;

@property(strong, nonatomic) IBOutlet NSTextField *titleField;
@property(strong, nonatomic) IBOutlet NSTextField *accountField;
@property(strong, nonatomic) IBOutlet NSTextField *failureReasonField;
@property(strong, nonatomic) IBOutlet NSButton *connectButton;

@end

@implementation DropboxAccountSheetController {
    std::shared_ptr<Authenticator> m_Authenticator;
    std::string m_Token;
    std::optional<nc::panel::NetworkConnectionsManager::Connection> m_Original;
    nc::panel::NetworkConnectionsManager::Dropbox m_Connection;
    State m_State;
}
@synthesize setupMode;
@synthesize isValid;
@synthesize isValidating;
@synthesize isSuccess;
@synthesize isFailure;
@synthesize titleField;
@synthesize accountField;
@synthesize failureReasonField;
@synthesize connectButton;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        self.isValid = true;
        m_Connection.uuid = nc::panel::NetworkConnectionsManager::MakeUUID();
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    if( m_Original ) {
        auto &original = m_Original->Get<nc::panel::NetworkConnectionsManager::Dropbox>();
        m_Connection = original;
    }

    self.titleField.stringValue = [NSString stringWithUTF8StdString:m_Connection.title];
    self.accountField.stringValue = [NSString stringWithUTF8StdString:m_Connection.account];

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;

    [self validate];
}

- (IBAction)onConnect:(id) [[maybe_unused]] _sender
{
    m_Connection.title = self.titleField.stringValue.UTF8String;

    [self endSheet:NSModalResponseOK];
}

- (IBAction)onClose:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)onRequestAccess:(id) [[maybe_unused]] _sender
{
    m_Authenticator = vfs::dropbox::MakeAuthenticator();
    Authenticator::Request request;
    request.client_id = NCE(env::dropbox_client_id);
    request.client_secret = NCE(env::dropbox_client_secret);
    request.loopback_port = static_cast<uint16_t>(56789);
    request.success_url = "https://magnumbytes.com/static/dropbox_oauth_redirect.html";
    __weak DropboxAccountSheetController *weak_self = self;
    m_Authenticator->PerformRequest(
        request,
        [weak_self](const Authenticator::Token &_token) {
            if( DropboxAccountSheetController *const me = weak_self )
                [me processAuthToken:_token];
        },
        [weak_self](int _vfs_error) {
            if( DropboxAccountSheetController *const me = weak_self )
                [me processAuthError:_vfs_error];
        });
}

- (void)processAuthToken:(const Authenticator::Token &)_token
{
    // Brings this app to the foreground.
    [NSRunningApplication.currentApplication
        activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];

    m_Token = vfs::dropbox::TokenMangler::ToMangledRefreshToken(_token.refresh_token);
    self.state = State::Validating;

    const auto access_token = _token.access_token;
    dispatch_to_background([=] {
        auto res = vfs::DropboxHost::CheckTokenAndRetrieveAccountEmail(access_token);
        auto rc = res.first;
        auto email = res.second;
        dispatch_to_main_queue([=] {
            if( rc == VFSError::Ok ) {
                self.accountField.stringValue = [NSString stringWithUTF8StdString:email];
                m_Connection.account = email;
                self.state = State::Success;
            }
            else {
                self.accountField.stringValue = @"";
                m_Connection.account = "";
                self.failureReasonField.stringValue = VFSError::ToNSError(rc).localizedDescription;
                self.state = State::Failure;
            }
        });
    });
}

- (void)processAuthError:(int)_vfs_error
{
    // Brings this app to the foreground.
    [NSRunningApplication.currentApplication
        activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
    self.state = State::Failure;
    self.failureReasonField.stringValue = VFSError::ToNSError(_vfs_error).localizedDescription;
}

- (void)setPassword:(std::string)password
{
    m_Token = password;
}

- (std::string)password
{
    return m_Token;
}

- (nc::panel::NetworkConnectionsManager::Connection)connection
{
    return nc::panel::NetworkConnectionsManager::Connection{m_Connection};
}

- (void)setConnection:(nc::panel::NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (void)setState:(State)_state
{
    if( m_State == _state )
        return;
    m_State = _state;
    self.isValidating = m_State == State::Validating;
    self.isSuccess = m_State == State::Success;
    self.isFailure = m_State == State::Failure;
    [self validate];
}

- (void)validate
{
    self.isValid =
        (m_State == State::Default || m_State == State::Success) && !m_Token.empty() && !m_Connection.account.empty();
}

- (State)state
{
    return m_State;
}

@end
