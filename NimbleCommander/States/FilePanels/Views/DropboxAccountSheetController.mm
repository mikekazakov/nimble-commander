#include "DropboxAccountSheetController.h"
#import <AppAuth.h>
#include "OIDRedirectHTTPHandler+FixedPort.h"
#include <VFS/NetDropbox.h>

static const auto kClientID = @"ics7strw94rj93l";
static const auto kClientSecret = @"jz0dp0x27yw1cg3";
static const uint16_t g_LoopbackPort = 56789;
static const auto g_SuccessURL =
    [NSURL URLWithString:@"http://openid.github.io/AppAuth-iOS/redirect/"];
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
@property (nonatomic) bool isValidating;
@property (nonatomic) bool isSuccess;
@property (nonatomic) bool isFailure;

@property (strong) IBOutlet NSTextField *accountField;
@property (strong) IBOutlet NSTextField *failureReasonField;

@end

@implementation DropboxAccountSheetController
{
    OIDRedirectHTTPHandler *m_RedirectHTTPHandler;
    string m_Token;
    NetworkConnectionsManager::Dropbox m_Connection;
    State m_State;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (IBAction)onConnect:(id)sender
{
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
            self.failureReasonField.stringValue = @"Unable to authorize";
        else
            self.failureReasonField.stringValue = _error.localizedDescription;
    }
}

- (void)acceptAccessToken:(NSString*)_token
{
    m_Token = _token.UTF8String;
    self.state = State::Validating;

    dispatch_to_background([=]{
        auto res = VFSNetDropboxHost::CheckTokenAndRetrieveAccountEmail(_token.UTF8String);
        auto rc = res.first;
        auto email = res.second;
        if( rc == VFSError::Ok ) {
            dispatch_to_main_queue([=]{
                self.accountField.stringValue = [NSString stringWithUTF8StdString:email];
                m_Connection.account = email;
                
                self.state = State::Success;
            });
        }
        else {
            dispatch_to_main_queue([=]{
                self.accountField.stringValue = @"";
                self.failureReasonField.stringValue = VFSError::ToNSError(rc).localizedDescription;
                m_Connection.account = "";
                self.state = State::Failure;
            });
        }
    });
}

- (void)setPassword:(string)password
{
    m_Token = password;
}

- (string)password
{
    return m_Token;
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection{m_Connection};
}

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    // TODO:
}

- (void) setState:(State)_state
{
    if( m_State == _state )
        return;
    m_State = _state;
    self.isValidating = m_State == State::Validating;
    self.isSuccess = m_State == State::Success;
    self.isFailure = m_State == State::Failure;
}

- (State)state
{
    return m_State;
}

@end
