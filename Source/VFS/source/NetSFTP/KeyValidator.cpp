// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "KeyValidator.h"
#include <libssh2.h>

namespace nc::vfs::sftp {

KeyValidator::KeyValidator(const std::string& _private_key_path, const std::string& _passphrase)
    : m_KeyPath(_private_key_path), m_Passphrase(_passphrase)
{
}

bool KeyValidator::Validate() const
{
    if (m_KeyPath.empty())
        return false;

    const auto ssh = libssh2_session_init_ex(nullptr, nullptr, nullptr, nullptr);

    const auto rc = libssh2_userauth_publickey_fromfile_ex(ssh, "", 0, nullptr, m_KeyPath.c_str(),
                                                           m_Passphrase.c_str());

    libssh2_free(ssh, nullptr);

    return rc == LIBSSH2_ERROR_SOCKET_SEND;
}

} // namespace nc::vfs::sftp
