// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Authenticator.h"
#include <VFS/VFSError.h>
#include <VFS/Log.h>
#import <AppAuth/AppAuth.h>
#import <AppAuth/OIDRedirectHTTPHandler.h>
#import <AppAuth/OIDAuthorizationRequest.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include "Aux.h"

namespace nc::vfs::dropbox {

class AuthenticatorImpl : public Authenticator, public std::enable_shared_from_this<AuthenticatorImpl>
{
public:
    void PerformRequest(const Request &_request,
                        std::function<void(const Token &_token)> _on_success,
                        std::function<void(int _vfs_error)> _on_error) override;

private:
    void Callback(OIDAuthState *_Nullable _auth_state, NSError *_Nullable _error);

    OIDRedirectHTTPHandler *m_RedirectHTTPHandler;
    Request m_Request;
    std::function<void(const Token &_token)> m_OnSuccess;
    std::function<void(int _vfs_error)> m_OnError;
};

std::shared_ptr<Authenticator> MakeAuthenticator()
{
    return std::make_shared<AuthenticatorImpl>();
}

void AuthenticatorImpl::PerformRequest(const Request &_request,
                                       std::function<void(const Token &_token)> _on_success,
                                       std::function<void(int _vfs_error)> _on_error)
{
    assert(_on_success);
    assert(_on_error);
    m_Request = _request;
    m_OnSuccess = std::move(_on_success);
    m_OnError = std::move(_on_error);

    m_RedirectHTTPHandler = [[OIDRedirectHTTPHandler alloc]
        initWithSuccessURL:[NSURL URLWithString:[NSString stringWithUTF8StdString:m_Request.success_url]]];
    const auto redirectURI = [m_RedirectHTTPHandler startHTTPListener:nil withPort:m_Request.loopback_port];

    const auto configuration = [[OIDServiceConfiguration alloc] initWithAuthorizationEndpoint:api::OAuth2Authorize
                                                                                tokenEndpoint:api::OAuth2Token];

    auto additional_params = @{@"token_access_type": @"offline"};

    const auto request = [[OIDAuthorizationRequest alloc]
        initWithConfiguration:configuration
                     clientId:[NSString stringWithUTF8StdString:m_Request.client_id]
                 clientSecret:[NSString stringWithUTF8StdString:m_Request.client_secret]
                        scope:nil
                  redirectURL:redirectURI
                 responseType:OIDResponseTypeCode
                        state:nil
                        nonce:nil
                 codeVerifier:nil
                codeChallenge:nil
          codeChallengeMethod:nil
         additionalParameters:additional_params];

    auto weak_this = weak_from_this();
    auto callback = ^(OIDAuthState *_Nullable _auth_state, NSError *_Nullable _error) {
      if( auto me = weak_this.lock() )
          me->Callback(_auth_state, _error);
    };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    auto state = [OIDAuthState authStateByPresentingAuthorizationRequest:request callback:callback];
#pragma clang diagnostic pop
    m_RedirectHTTPHandler.currentAuthorizationFlow = state;
    Log::Info("Started OAuth2 authentication process.");
}

void AuthenticatorImpl::Callback(OIDAuthState *_Nullable _auth_state, NSError *_Nullable _error)
{
    if( _auth_state != nil ) {
        Token token;
        if( auto uid = objc_cast<NSString>(_auth_state.lastTokenResponse.additionalParameters[@"uid"]) )
            token.uid = uid.UTF8String;
        if( _auth_state.lastTokenResponse.accessToken )
            token.access_token = _auth_state.lastTokenResponse.accessToken.UTF8String;
        if( _auth_state.lastTokenResponse.tokenType )
            token.token_type = _auth_state.lastTokenResponse.tokenType.UTF8String;
        if( _auth_state.lastTokenResponse.scope )
            token.scope = _auth_state.lastTokenResponse.scope.UTF8String;
        if( _auth_state.refreshToken )
            token.refresh_token = _auth_state.refreshToken.UTF8String;
        if( auto account_id = objc_cast<NSString>(_auth_state.lastTokenResponse.additionalParameters[@"account_id"]) )
            token.account_id = account_id.UTF8String;

        Log::Info("Successfully got auth token, type={}, scope={}, account_id={}, len(token)={}, "
                  "len(refresh_token)={}.",
                  token.token_type,
                  token.scope,
                  token.account_id,
                  token.access_token.length(),
                  token.refresh_token.length());
        m_OnSuccess(token);
        return;
    }
    if( _error != nil ) {
        Log::Warn("Failed to got auth token, error: {}", _error.localizedDescription.UTF8String);

        int error = VFSError::Ok;
        if( [_error.domain isEqualToString:OIDOAuthTokenErrorDomain] ||
            [_error.domain isEqualToString:OIDOAuthAuthorizationErrorDomain] ||
            [_error.domain isEqualToString:OIDOAuthTokenErrorDomain] ||
            [_error.domain isEqualToString:OIDOAuthRegistrationErrorDomain] ||
            [_error.domain isEqualToString:OIDResourceServerAuthorizationErrorDomain] ||
            [_error.domain isEqualToString:OIDHTTPErrorDomain] )
            error = VFSError::FromErrno(EAUTH);
        else
            error = VFSError::FromNSError(_error);

        m_OnError(error);
        return;
    }
}

bool TokenMangler::IsMangledRefreshToken(std::string_view _token) noexcept
{
    return _token.starts_with(refresh_token_tag);
}

std::string TokenMangler::ToMangledRefreshToken(std::string_view _token) noexcept
{
    assert(IsMangledRefreshToken(_token) == false);
    return refresh_token_tag + std::string(_token);
}

std::string TokenMangler::FromMangledRefreshToken(std::string_view _token) noexcept
{
    if( !IsMangledRefreshToken(_token) )
        return {};
    _token.remove_prefix(std::string_view(refresh_token_tag).length());
    return std::string(_token);
}

} // namespace nc::vfs::dropbox
