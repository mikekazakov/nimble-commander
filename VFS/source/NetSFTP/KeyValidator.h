// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::vfs::sftp {

class KeyValidator
{
public:
    KeyValidator( const char *_private_key_path, const char *_passphrase );
    
    bool Validate() const;

private:
    const char *m_KeyPath;
    const char *m_Passphrase;
};

}
