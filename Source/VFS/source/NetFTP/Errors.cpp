// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Errors.h"
#include <frozen/unordered_map.h>

namespace nc::vfs::ftp {

static constinit frozen::unordered_map<long, const char *, 23> g_Messages{
    {Errors::login_denied, "The remote server denied to login."},
    {Errors::url_malformat, "URL malformat."},
    {Errors::server_problem, "Weird FTP server behaviour."},
    {Errors::couldnt_resolve_proxy, "Couldn't resolve proxy for FTP server."},
    {Errors::couldnt_resolve_host, "Couldn't resolve FTP server host."},
    {Errors::couldnt_connect, "Failed to connect to remote FTP server."},
    {Errors::access_denied, "Access to remote resource is denied."},
    {Errors::operation_timeout, "Operation timeout."},
    {Errors::ssl_failure, "FTP+SSL/TLS failure."},
    {Errors::unexpected_eof, "An unexpected end of file occured."},
    {Errors::accept_failed, "Unable to accept the server connection back."},
    {Errors::weird_pass_reply, "Incorrect response to the password."},
    {Errors::weird_pasv_reply, "Incorrect response to the PASV command."},
    {Errors::weird_227_format, "Incorrect 227-line response."},
    {Errors::accept_timeout, "Timeout waiting for the server to connect."},
    {Errors::cant_get_host, "Failed to look up the host."},
    {Errors::couldn_set_type, "Unable to set the transfer mode."},
    {Errors::couldn_retr_file, "Incorrect response to the RETR command."},
    {Errors::port_failed, "The FTP PORT command returned error. "},
    {Errors::couldn_use_rest, "The FTP REST command returned error."},
    {Errors::pret_failed, "The FTP server does not understand the PRET command."},
    {Errors::bad_file_list, "Unable to parse FTP file list."},
    {Errors::weird_server_reply, "Unable to parse the server reply."}};

std::string ErrorDescriptionProvider::Description(int64_t _code) const noexcept
{
    if( auto it = g_Messages.find(_code); it != g_Messages.end() )
        return it->second;
    else
        return fmt::format("NetFTP error ({}).", _code);
}

std::string ErrorDescriptionProvider::LocalizedFailureReason(int64_t _code) const noexcept
{
    return Description(_code);
}

} // namespace nc::vfs::ftp
