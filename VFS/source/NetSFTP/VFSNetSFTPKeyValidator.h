#pragma once 

class VFSNetSFTPKeyValidator
{
public:
    VFSNetSFTPKeyValidator( const char *_private_key_path, const char *_passphrase );
    
    bool Validate() const;

private:
    const char *m_KeyPath;
    const char *m_Passphrase;
};
