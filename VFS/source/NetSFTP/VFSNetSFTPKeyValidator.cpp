#include "VFSNetSFTPKeyValidator.h"

#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>

VFSNetSFTPKeyValidator::VFSNetSFTPKeyValidator
    ( const char *_private_key_path, const char *_passphrase ):
    m_KeyPath(_private_key_path),
    m_Passphrase(_passphrase)
{
}

bool VFSNetSFTPKeyValidator::Validate() const
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
