// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Errors.h"
#include <libssh2.h>
#include <libssh2_sftp.h>
#include <frozen/unordered_map.h>
#include <fmt/format.h>

namespace nc::vfs::sftp {

static_assert(Errors::none == LIBSSH2_ERROR_NONE);
static_assert(Errors::socket_none == LIBSSH2_ERROR_SOCKET_NONE);
static_assert(Errors::banner_recv == LIBSSH2_ERROR_BANNER_RECV);
static_assert(Errors::banner_send == LIBSSH2_ERROR_BANNER_SEND);
static_assert(Errors::invalid_mac == LIBSSH2_ERROR_INVALID_MAC);
static_assert(Errors::kex_failure == LIBSSH2_ERROR_KEX_FAILURE);
static_assert(Errors::alloc == LIBSSH2_ERROR_ALLOC);
static_assert(Errors::socket_send == LIBSSH2_ERROR_SOCKET_SEND);
static_assert(Errors::key_exchange_failure == LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE);
static_assert(Errors::timeout == LIBSSH2_ERROR_TIMEOUT);
static_assert(Errors::hostkey_init == LIBSSH2_ERROR_HOSTKEY_INIT);
static_assert(Errors::hostkey_sign == LIBSSH2_ERROR_HOSTKEY_SIGN);
static_assert(Errors::decrypt == LIBSSH2_ERROR_DECRYPT);
static_assert(Errors::socket_disconnect == LIBSSH2_ERROR_SOCKET_DISCONNECT);
static_assert(Errors::proto == LIBSSH2_ERROR_PROTO);
static_assert(Errors::password_expired == LIBSSH2_ERROR_PASSWORD_EXPIRED);
static_assert(Errors::file == LIBSSH2_ERROR_FILE);
static_assert(Errors::method_none == LIBSSH2_ERROR_METHOD_NONE);
static_assert(Errors::authentication_failed == LIBSSH2_ERROR_AUTHENTICATION_FAILED);
static_assert(Errors::publickey_unverified == LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED);
static_assert(Errors::channel_outoforder == LIBSSH2_ERROR_CHANNEL_OUTOFORDER);
static_assert(Errors::channel_failure == LIBSSH2_ERROR_CHANNEL_FAILURE);
static_assert(Errors::channel_request_denied == LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED);
static_assert(Errors::channel_unknown == LIBSSH2_ERROR_CHANNEL_UNKNOWN);
static_assert(Errors::channel_window_exceeded == LIBSSH2_ERROR_CHANNEL_WINDOW_EXCEEDED);
static_assert(Errors::channel_packet_exceeded == LIBSSH2_ERROR_CHANNEL_PACKET_EXCEEDED);
static_assert(Errors::channel_closed == LIBSSH2_ERROR_CHANNEL_CLOSED);
static_assert(Errors::channel_eof_sent == LIBSSH2_ERROR_CHANNEL_EOF_SENT);
static_assert(Errors::scp_protocol == LIBSSH2_ERROR_SCP_PROTOCOL);
static_assert(Errors::zlib == LIBSSH2_ERROR_ZLIB);
static_assert(Errors::socket_timeout == LIBSSH2_ERROR_SOCKET_TIMEOUT);
static_assert(Errors::sftp_protocol == LIBSSH2_ERROR_SFTP_PROTOCOL);
static_assert(Errors::request_denied == LIBSSH2_ERROR_REQUEST_DENIED);
static_assert(Errors::method_not_supported == LIBSSH2_ERROR_METHOD_NOT_SUPPORTED);
static_assert(Errors::inval == LIBSSH2_ERROR_INVAL);
static_assert(Errors::invalid_poll_type == LIBSSH2_ERROR_INVALID_POLL_TYPE);
static_assert(Errors::publickey_protocol == LIBSSH2_ERROR_PUBLICKEY_PROTOCOL);
static_assert(Errors::eagain == LIBSSH2_ERROR_EAGAIN);
static_assert(Errors::buffer_too_small == LIBSSH2_ERROR_BUFFER_TOO_SMALL);
static_assert(Errors::bad_use == LIBSSH2_ERROR_BAD_USE);
static_assert(Errors::compress == LIBSSH2_ERROR_COMPRESS);
static_assert(Errors::out_of_boundary == LIBSSH2_ERROR_OUT_OF_BOUNDARY);
static_assert(Errors::agent_protocol == LIBSSH2_ERROR_AGENT_PROTOCOL);
static_assert(Errors::socket_recv == LIBSSH2_ERROR_SOCKET_RECV);
static_assert(Errors::encrypt == LIBSSH2_ERROR_ENCRYPT);
static_assert(Errors::bad_socket == LIBSSH2_ERROR_BAD_SOCKET);
static_assert(Errors::known_hosts == LIBSSH2_ERROR_KNOWN_HOSTS);
static_assert(Errors::channel_window_full == LIBSSH2_ERROR_CHANNEL_WINDOW_FULL);
static_assert(Errors::keyfile_auth_failed == LIBSSH2_ERROR_KEYFILE_AUTH_FAILED);
static_assert(Errors::randgen == LIBSSH2_ERROR_RANDGEN);
static_assert(Errors::missing_userauth_banner == LIBSSH2_ERROR_MISSING_USERAUTH_BANNER);
static_assert(Errors::algo_unsupported == LIBSSH2_ERROR_ALGO_UNSUPPORTED);
static_assert(Errors::mac_failure == LIBSSH2_ERROR_MAC_FAILURE);
static_assert(Errors::hash_init == LIBSSH2_ERROR_HASH_INIT);
static_assert(Errors::hash_calc == LIBSSH2_ERROR_HASH_CALC);
static_assert(Errors::fx_eof == LIBSSH2_FX_EOF);
static_assert(Errors::fx_no_such_file == LIBSSH2_FX_NO_SUCH_FILE);
static_assert(Errors::fx_permission_denied == LIBSSH2_FX_PERMISSION_DENIED);
static_assert(Errors::fx_failure == LIBSSH2_FX_FAILURE);
static_assert(Errors::fx_bad_message == LIBSSH2_FX_BAD_MESSAGE);
static_assert(Errors::fx_no_connection == LIBSSH2_FX_NO_CONNECTION);
static_assert(Errors::fx_connection_lost == LIBSSH2_FX_CONNECTION_LOST);
static_assert(Errors::fx_op_unsupported == LIBSSH2_FX_OP_UNSUPPORTED);
static_assert(Errors::fx_invalid_handle == LIBSSH2_FX_INVALID_HANDLE);
static_assert(Errors::fx_no_such_path == LIBSSH2_FX_NO_SUCH_PATH);
static_assert(Errors::fx_file_already_exists == LIBSSH2_FX_FILE_ALREADY_EXISTS);
static_assert(Errors::fx_write_protect == LIBSSH2_FX_WRITE_PROTECT);
static_assert(Errors::fx_no_media == LIBSSH2_FX_NO_MEDIA);
static_assert(Errors::fx_no_space_on_filesystem == LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM);
static_assert(Errors::fx_quota_exceeded == LIBSSH2_FX_QUOTA_EXCEEDED);
static_assert(Errors::fx_unknown_principal == LIBSSH2_FX_UNKNOWN_PRINCIPAL);
static_assert(Errors::fx_lock_conflict == LIBSSH2_FX_LOCK_CONFLICT);
static_assert(Errors::fx_dir_not_empty == LIBSSH2_FX_DIR_NOT_EMPTY);
static_assert(Errors::fx_not_a_directory == LIBSSH2_FX_NOT_A_DIRECTORY);
static_assert(Errors::fx_invalid_filename == LIBSSH2_FX_INVALID_FILENAME);
static_assert(Errors::fx_link_loop == LIBSSH2_FX_LINK_LOOP);

static constinit frozen::unordered_map<long, const char *, 76> g_Messages{
    {Errors::none, "No error."},
    {Errors::socket_none, "The socket is invalid."},
    {Errors::banner_recv, "No banner was received from the remote host."},
    {Errors::banner_send, "Unable to send banner to remote host."},
    {Errors::invalid_mac, "Invalid MAC received."},
    {Errors::kex_failure, "Encryption key exchange with the remote host failed."},
    {Errors::alloc, "An internal memory allocation call failed."},
    {Errors::socket_send, "Unable to send data on socket."},
    {Errors::key_exchange_failure, "Unrecoverable error exchanging keys."},
    {Errors::timeout, "Timed out waiting on socket."},
    {Errors::hostkey_init, "Unable to initialize hostkey subsystem."},
    {Errors::hostkey_sign, "Unable to verify hostkey signature."},
    {Errors::decrypt, "Failure in decrypting received data."},
    {Errors::socket_disconnect, "The socket was disconnected."},
    {Errors::proto, "An invalid SSH protocol response was received on the socket."},
    {Errors::password_expired, "Password expired."},
    {Errors::file, "Unable to read public key from file."},
    {Errors::method_none, "No method negotiated."},
    {Errors::authentication_failed, "Authentication using the supplied public key was not accepted."},
    {Errors::publickey_unverified, "The username/public key combination was invalid."},
    {Errors::channel_outoforder, "Channel out of order."},
    {Errors::channel_failure, "Unable to startup channel."},
    {Errors::channel_request_denied, "The remote server refused the request."},
    {Errors::channel_unknown, "Packet received for unknown channel."},
    {Errors::channel_window_exceeded, "The current receive window is full, data ignored."},
    {Errors::channel_packet_exceeded, "SFTP packet too large"},
    {Errors::channel_closed, "The channel has been closed."},
    {Errors::channel_eof_sent, "EOF has already been received, data might be ignored."},
    {Errors::scp_protocol, "Invalid data in SCP response."},
    {Errors::zlib, "(De)compression failure."},
    {Errors::socket_timeout, "Timeout waiting for response from publickey subsystem."},
    {Errors::sftp_protocol, "An invalid SFTP protocol response was received on the socket."},
    {Errors::request_denied, "The remote server refused the request."},
    {Errors::method_not_supported, "The requested method is not supported."},
    {Errors::inval, "The requested method type was invalid."},
    {Errors::invalid_poll_type, "Invalid polling descriptor."},
    {Errors::publickey_protocol, "Invalid publickey subsystem response."},
    {Errors::eagain, "Would block."},
    {Errors::buffer_too_small, "Buffer is too small."},
    {Errors::bad_use, "Illegal request."},
    {Errors::compress, "(De)compression failure."},
    {Errors::out_of_boundary, "Request is out of boundary."},
    {Errors::agent_protocol, "Unable to connect to agent pipe."},
    {Errors::socket_recv, "Unable to read from socket."},
    {Errors::encrypt, "Encryption failure."},
    {Errors::bad_socket, "Bad socket provided."},
    {Errors::known_hosts, "Failed to parse known hosts file."},
    {Errors::channel_window_full, "Receiving channel window has been exhausted."},
    {Errors::keyfile_auth_failed, "Wrong passphrase for private key."},
    {Errors::randgen, "Unable to get random bytes."},
    {Errors::missing_userauth_banner, "Missing userauth banner."},
    {Errors::algo_unsupported, "Algorithm is not supported."},
    {Errors::mac_failure, "Failed to calculate MAC."},
    {Errors::hash_init, "Unable to initialize hash context."},
    {Errors::hash_calc, "Failed to calculate hash."},
    {Errors::fx_eof, "End-of-file encountered."},
    {Errors::fx_no_such_file, "File does not exist in the server."},
    {Errors::fx_permission_denied, "The user does not have permission to perform the operation on the server."},
    {Errors::fx_failure, "Generic SFTP failure."},
    {Errors::fx_bad_message, "A badly formatted packet detected."},
    {Errors::fx_no_connection, "No SSH connection."},
    {Errors::fx_connection_lost, "The SSH Connection is lost."},
    {Errors::fx_op_unsupported, "The operation is not supported."},
    {Errors::fx_invalid_handle, "Invalid file handle."},
    {Errors::fx_no_such_path, "No such file or directory path exists."},
    {Errors::fx_file_already_exists, "File already exists."},
    {Errors::fx_write_protect, "Attempting to write a file to a write-protected or read-only file system."},
    {Errors::fx_no_media, "No media available in the remote system."},
    {Errors::fx_no_space_on_filesystem, "Insufficient free space in the file system."},
    {Errors::fx_quota_exceeded, "The storage quota of the server exceeded."},
    {Errors::fx_unknown_principal, "Owner is unknown."},
    {Errors::fx_lock_conflict, "The file is in use by another process."},
    {Errors::fx_dir_not_empty, "The directory is not empty."},
    {Errors::fx_not_a_directory, "The specified file is not a directory."},
    {Errors::fx_invalid_filename, "The filename is not valid."},
    {Errors::fx_link_loop, "Too many symbolic links encountered."}};

std::string ErrorDescriptionProvider::Description(int64_t _code) const noexcept
{
    if( auto it = g_Messages.find(_code); it != g_Messages.end() )
        return it->second;
    else
        return fmt::format("LibSSH2 error ({}).", _code);
}

std::string ErrorDescriptionProvider::LocalizedFailureReason(int64_t _code) const noexcept
{
    return Description(_code);
}

} // namespace nc::vfs::sftp
