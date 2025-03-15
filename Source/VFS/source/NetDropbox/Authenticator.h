// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <functional>
#include <string>
#include <string_view>
#include <Base/Error.h>

namespace nc::vfs::dropbox {

class Authenticator
{
public:
    struct Request {
        std::string client_id;
        std::string client_secret;
        std::string success_url;
        uint16_t loopback_port;
    };

    struct Token {
        std::string uid;
        std::string access_token;
        std::string token_type;
        std::string scope;
        std::string refresh_token;
        std::string account_id;
    };

    virtual ~Authenticator() = default;

    virtual void PerformRequest(const Request &_request,
                                std::function<void(const Token &_token)> _on_success,
                                std::function<void(Error _error)> _on_error) = 0;
};

std::shared_ptr<Authenticator> MakeAuthenticator();

struct TokenMangler {
    static constexpr const char *refresh_token_tag = "<refresh-token>";

    // Check if the token is a mangled refresh token, i.e. prefixed with refresh_token_tag
    static bool IsMangledRefreshToken(std::string_view _token) noexcept;

    // Returns a mangled refresh token, i.e. prefixed with refresh_token_tag
    static std::string ToMangledRefreshToken(std::string_view _token) noexcept;

    // Either returns a clear refresh token from a mangled refresh token, or an empty string if the
    // token wasn't mangled
    static std::string FromMangledRefreshToken(std::string_view _token) noexcept;
};

} // namespace nc::vfs::dropbox
