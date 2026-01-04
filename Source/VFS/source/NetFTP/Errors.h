// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/Error.h>

namespace nc::vfs::ftp {

inline constexpr std::string_view ErrorDomain = "VFSFTP";

struct Errors {
    static constexpr long login_denied = 1;
    static constexpr long url_malformat = 2;
    static constexpr long server_problem = 3;
    static constexpr long couldnt_resolve_proxy = 4;
    static constexpr long couldnt_resolve_host = 5;
    static constexpr long couldnt_connect = 6;
    static constexpr long access_denied = 7;
    static constexpr long operation_timeout = 8;
    static constexpr long ssl_failure = 9;
    static constexpr long unexpected_eof = 10;
    static constexpr long accept_failed = 11;
    static constexpr long weird_pass_reply = 12;
    static constexpr long weird_pasv_reply = 13;
    static constexpr long weird_227_format = 14;
    static constexpr long accept_timeout = 15;
    static constexpr long cant_get_host = 16;
    static constexpr long couldn_set_type = 17;
    static constexpr long couldn_retr_file = 18;
    static constexpr long port_failed = 19;
    static constexpr long couldn_use_rest = 20;
    static constexpr long pret_failed = 21;
    static constexpr long bad_file_list = 22;
    static constexpr long weird_server_reply = 23;
};

class ErrorDescriptionProvider : public nc::base::ErrorDescriptionProvider
{
public:
    [[nodiscard]] std::string Description(int64_t _code) const noexcept override;
    [[nodiscard]] std::string LocalizedFailureReason(int64_t _code) const noexcept override;
};

} // namespace nc::vfs::ftp
