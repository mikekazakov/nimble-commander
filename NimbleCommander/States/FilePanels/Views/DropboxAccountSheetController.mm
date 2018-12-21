// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DropboxAccountSheetController.h"
#import <AppAuth.h>
#include "OIDRedirectHTTPHandler+FixedPort.h"
#include <VFS/NetDropbox.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include <NimbleCommander/Bootstrap/NCE.h>
#include <Utility/StringExtras.h>
#include <Habanero/dispatch_cpp.h>

using namespace nc;

static const auto kClientID     = [NSString stringWithUTF8String:NCE(env::dropbox_client_id)];
static const auto kClientSecret = [NSString stringWithUTF8String:NCE(env::dropbox_client_secret)];
static const auto g_LoopbackPort = (uint16_t)56789;
static const auto g_SuccessURL =
    [NSURL URLWithString:@"http://magnumbytes.com/static/dropbox_oauth_redirect.html"];
static const auto g_AuthorizationEndpoint =
    [NSURL URLWithString:@"https://www.dropbox.com/oauth2/authorize"];
static const auto g_TokenEndpoint =
    [NSURL URLWithString:@"https://api.dropbox.com/1/oauth2/token"];

namespace {

enum class State
{
    Default     = 0,
    Validating  = 1,
    Success     = 2,
    Failure     = 3
};

}

@interface DropboxAccountSheetController ()

@property (nonatomic) State state;
@property (nonatomic) bool isValid;
@property (nonatomic) bool isValidating;
@property (nonatomic) bool isSuccess;
@property (nonatomic) bool isFailure;

@property (strong, nonatomic) IBOutlet NSTextField *titleField;
@property (strong, nonatomic) IBOutlet NSTextField *accountField;
@property (strong, nonatomic) IBOutlet NSTextField *failureReasonField;
@property (strong, nonatomic) IBOutlet NSButton *connectButton;

@end

@implementation DropboxAccountSheetController
{
    OIDRedirectHTTPHandler *m_RedirectHTTPHandler;
    std::string m_Token;
    std::optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::Dropbox m_Connection;
    State m_State;
}

- (instancetype)init
{
    self = [super init];
    if( self ) {
        self.isValid = true;
        m_Connection.uuid = NetworkConnectionsManager::MakeUUID();
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    GA().PostScreenView("Dropbox Connection");

    
    if( m_Original ) {
        auto &original = m_Original->Get<NetworkConnectionsManager::Dropbox>();
        m_Connection = original;
    }

    self.titleField.stringValue = [NSString stringWithUTF8StdString:m_Connection.title];
    self.accountField.stringValue = [NSString stringWithUTF8StdString:m_Connection.account];

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;
    
    [self validate];
}

- (IBAction)onConnect:(id)sender
{
    m_Connection.title = self.titleField.stringValue.UTF8String;

    [self endSheet:NSModalResponseOK];
}

- (IBAction)onClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)onRequestAccess:(id)sender
{
    m_RedirectHTTPHandler = [[OIDRedirectHTTPHandler alloc] initWithSuccessURL:g_SuccessURL];
    const auto redirectURI = [m_RedirectHTTPHandler startHTTPListenerForPort:g_LoopbackPort
                                                                       error:nil];

    const auto configuration = [[OIDServiceConfiguration alloc]
        initWithAuthorizationEndpoint:g_AuthorizationEndpoint
        tokenEndpoint:g_TokenEndpoint];

    const auto request = [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                                       clientId:kClientID
                                                                   clientSecret:kClientSecret
                                                                          scope:nil
                                                                    redirectURL:redirectURI
                                                                   responseType:OIDResponseTypeCode
                                                                          state:nil
                                                                   codeVerifier:nil
                                                                  codeChallenge:nil
                                                            codeChallengeMethod:nil
                                                           additionalParameters:nil];

    auto callback = ^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
        [self processAuthRespone:authState error:error];
    };
    auto state = [OIDAuthState authStateByPresentingAuthorizationRequest:request callback:callback];
    m_RedirectHTTPHandler.currentAuthorizationFlow = state;
}

- (void)processAuthRespone:(OIDAuthState *)_auth error:(NSError *)_error
{
     // Brings this app to the foreground.
    [NSRunningApplication.currentApplication activateWithOptions:
        (NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
    
    // Processes the authorization response.
    if( _auth ) {
        [self acceptAccessToken:_auth.lastTokenResponse.accessToken];
    } else {
        self.state = State::Failure;
        if( _error == nil || [_error.domain isEqualToString:OIDOAuthAuthorizationErrorDomain] )
            self.failureReasonField.stringValue = NSLocalizedString(@"Unable to authorize", "");
        else
            self.failureReasonField.stringValue = _error.localizedDescription;
    }
}

- (void)acceptAccessToken:(NSString*)_token
{
    m_Token = _token.UTF8String;
    self.state = State::Validating;

    dispatch_to_background([=]{
        auto res = vfs::DropboxHost::CheckTokenAndRetrieveAccountEmail(_token.UTF8String);
        auto rc = res.first;
        auto email = res.second;
        dispatch_to_main_queue([=]{
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

- (void)setPassword:(std::string)password
{
    m_Token = password;
}

- (std::string)password
{
    return m_Token;
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection{m_Connection};
}

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (void) setState:(State)_state
{
    if( m_State == _state )
        return;
    m_State = _state;
    self.isValidating = m_State == State::Validating;
    self.isSuccess = m_State == State::Success;
    self.isFailure = m_State == State::Failure;
    [self validate];
}

- (void) validate
{
    self.isValid = (m_State == State::Default || m_State == State::Success) &&
        !m_Token.empty() &&
        !m_Connection.account.empty();
}

- (State)state
{
    return m_State;
}

@end
