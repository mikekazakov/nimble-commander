// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/Error.h>

namespace nc::vfs::sftp {

inline constexpr std::string_view ErrorDomain = "VFSSFTP";

struct Errors {
    static constexpr long none = 0;
    static constexpr long socket_none = -1;
    static constexpr long banner_recv = -2;
    static constexpr long banner_send = -3;
    static constexpr long invalid_mac = -4;
    static constexpr long kex_failure = -5;
    static constexpr long alloc = -6;
    static constexpr long socket_send = -7;
    static constexpr long key_exchange_failure = -8;
    static constexpr long timeout = -9;
    static constexpr long hostkey_init = -10;
    static constexpr long hostkey_sign = -11;
    static constexpr long decrypt = -12;
    static constexpr long socket_disconnect = -13;
    static constexpr long proto = -14;
    static constexpr long password_expired = -15;
    static constexpr long file = -16;
    static constexpr long method_none = -17;
    static constexpr long authentication_failed = -18;
    static constexpr long publickey_unverified = -19;
    static constexpr long channel_outoforder = -20;
    static constexpr long channel_failure = -21;
    static constexpr long channel_request_denied = -22;
    static constexpr long channel_unknown = -23;
    static constexpr long channel_window_exceeded = -24;
    static constexpr long channel_packet_exceeded = -25;
    static constexpr long channel_closed = -26;
    static constexpr long channel_eof_sent = -27;
    static constexpr long scp_protocol = -28;
    static constexpr long zlib = -29;
    static constexpr long socket_timeout = -30;
    static constexpr long sftp_protocol = -31;
    static constexpr long request_denied = -32;
    static constexpr long method_not_supported = -33;
    static constexpr long inval = -34;
    static constexpr long invalid_poll_type = -35;
    static constexpr long publickey_protocol = -36;
    static constexpr long eagain = -37;
    static constexpr long buffer_too_small = -38;
    static constexpr long bad_use = -39;
    static constexpr long compress = -40;
    static constexpr long out_of_boundary = -41;
    static constexpr long agent_protocol = -42;
    static constexpr long socket_recv = -43;
    static constexpr long encrypt = -44;
    static constexpr long bad_socket = -45;
    static constexpr long known_hosts = -46;
    static constexpr long channel_window_full = -47;
    static constexpr long keyfile_auth_failed = -48;
    static constexpr long randgen = -49;
    static constexpr long missing_userauth_banner = -50;
    static constexpr long algo_unsupported = -51;
    static constexpr long mac_failure = -52;
    static constexpr long hash_init = -53;
    static constexpr long hash_calc = -54;
    static constexpr long fx_eof = 1;
    static constexpr long fx_no_such_file = 2;
    static constexpr long fx_permission_denied = 3;
    static constexpr long fx_failure = 4;
    static constexpr long fx_bad_message = 5;
    static constexpr long fx_no_connection = 6;
    static constexpr long fx_connection_lost = 7;
    static constexpr long fx_op_unsupported = 8;
    static constexpr long fx_invalid_handle = 9;
    static constexpr long fx_no_such_path = 10;
    static constexpr long fx_file_already_exists = 11;
    static constexpr long fx_write_protect = 12;
    static constexpr long fx_no_media = 13;
    static constexpr long fx_no_space_on_filesystem = 14;
    static constexpr long fx_quota_exceeded = 15;
    static constexpr long fx_unknown_principal = 16;
    static constexpr long fx_lock_conflict = 17;
    static constexpr long fx_dir_not_empty = 18;
    static constexpr long fx_not_a_directory = 19;
    static constexpr long fx_invalid_filename = 20;
    static constexpr long fx_link_loop = 21;
};

class ErrorDescriptionProvider : public nc::base::ErrorDescriptionProvider
{
public:
    std::string Description(int64_t _code) const noexcept override;
    std::string LocalizedFailureReason(int64_t _code) const noexcept override;
};

} // namespace nc::vfs::sftp
