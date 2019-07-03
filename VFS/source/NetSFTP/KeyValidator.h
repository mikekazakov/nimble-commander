// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

namespace nc::vfs::sftp {

class KeyValidator
{
public:
    KeyValidator( const std::string &_private_key_path, const std::string &_passphrase );
    
    bool Validate() const;

private:
    std::string m_KeyPath;
    std::string m_Passphrase;
};

}
