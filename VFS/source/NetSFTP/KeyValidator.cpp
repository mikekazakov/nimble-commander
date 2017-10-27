// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "KeyValidator.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#pragma clang diagnostic pop

namespace nc::vfs::sftp {

KeyValidator::KeyValidator( const char *_private_key_path, const char *_passphrase ):
    m_KeyPath(_private_key_path),
    m_Passphrase(_passphrase)
{
}

bool KeyValidator::Validate() const
{
    if( m_KeyPath == nullptr )
        return false;

    BIO* bp = BIO_new_file(m_KeyPath, "r");
    if( bp == nullptr )
        return false;
    
    if( !EVP_get_cipherbyname("des") )
        OpenSSL_add_all_ciphers();
    BIO_reset(bp);
    void *passphrase = (void*)(m_Passphrase != nullptr ? m_Passphrase : "");
    EVP_PKEY *pk = PEM_read_bio_PrivateKey(bp, NULL, NULL, passphrase);
    BIO_free(bp);
    
    if( pk == nullptr )
        return false;
    
    EVP_PKEY_free(pk);
    
    return true;
}

}
