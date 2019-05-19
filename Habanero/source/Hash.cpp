// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/Hash.h>
#include <CommonCrypto/CommonDigest.h>
#include <zlib.h>
#include <assert.h>

namespace nc::base {

Hash::Hash(Mode _mode):
    m_Mode(_mode)
{
    switch (m_Mode) {
        case SHA1_160:  CC_SHA1_Init( (CC_SHA1_CTX*)m_Stuff ); break;
        case SHA2_224:  CC_SHA224_Init( (CC_SHA256_CTX*)m_Stuff ); break;
        case SHA2_256:  CC_SHA256_Init( (CC_SHA256_CTX*)m_Stuff ); break;
        case SHA2_384:  CC_SHA384_Init( (CC_SHA512_CTX*)m_Stuff ); break;
        case SHA2_512:  CC_SHA512_Init( (CC_SHA512_CTX*)m_Stuff ); break;
        case MD2:       CC_MD2_Init( (CC_MD2_CTX*)m_Stuff ); break;
        case MD4:       CC_MD4_Init( (CC_MD4_CTX*)m_Stuff ); break;
        case MD5:       CC_MD5_Init( (CC_MD5_CTX*)m_Stuff ); break;
        case Adler32:   *((uint32_t*)m_Stuff) = (uint32_t)adler32(0, 0, 0); break;
        case CRC32:     *((uint32_t*)m_Stuff) = (uint32_t)crc32(0, 0, 0); break;
        default: assert(0);
    }
}

Hash& Hash::Feed(const void *_data, size_t _size)
{
    switch (m_Mode) {
        case SHA1_160: 
            CC_SHA1_Update( (CC_SHA1_CTX*)m_Stuff, _data, (unsigned)_size );
            break;
        case SHA2_224:
            CC_SHA224_Update( (CC_SHA256_CTX*)m_Stuff, _data, (unsigned)_size );
            break;
        case SHA2_256:  
            CC_SHA256_Update( (CC_SHA256_CTX*)m_Stuff, _data, (unsigned)_size ); 
            break;
        case SHA2_384:  
            CC_SHA384_Update( (CC_SHA512_CTX*)m_Stuff, _data, (unsigned)_size ); 
            break;
        case SHA2_512:  
            CC_SHA512_Update( (CC_SHA512_CTX*)m_Stuff, _data, (unsigned)_size ); 
            break;
        case MD2:       
            CC_MD2_Update( (CC_MD2_CTX*)m_Stuff, _data, (unsigned)_size ); 
            break;
        case MD4:       
            CC_MD4_Update( (CC_MD4_CTX*)m_Stuff, _data, (unsigned)_size ); 
            break;
        case MD5:       
            CC_MD5_Update( (CC_MD5_CTX*)m_Stuff, _data, (unsigned)_size ); 
            break;
        case Adler32:   
            *((uint32_t*)m_Stuff) = (uint32_t)adler32(*((uint32_t*)m_Stuff), (unsigned char*)_data, (unsigned)_size); 
            break;
        case CRC32:     
            *((uint32_t*)m_Stuff) = (uint32_t)crc32(*((uint32_t*)m_Stuff), (unsigned char*)_data, (unsigned)_size); 
            break;
        default: assert(0);
    }
    return *this;
}

std::vector<uint8_t> Hash::Final()
{
    switch (m_Mode) {
        case SHA1_160: {
            std::vector<uint8_t> r(CC_SHA1_DIGEST_LENGTH);
            CC_SHA1_Final( r.data(), (CC_SHA1_CTX*)m_Stuff );
            return r;
        }
        case SHA2_224: {
            std::vector<uint8_t> r(CC_SHA224_DIGEST_LENGTH);
            CC_SHA224_Final( r.data(), (CC_SHA256_CTX*)m_Stuff );
            return r;
        }
        case SHA2_256: {
            std::vector<uint8_t> r(CC_SHA256_DIGEST_LENGTH);
            CC_SHA256_Final( r.data(), (CC_SHA256_CTX*)m_Stuff );
            return r;
        }
        case SHA2_384: {
            std::vector<uint8_t> r(CC_SHA384_DIGEST_LENGTH);
            CC_SHA384_Final( r.data(), (CC_SHA512_CTX*)m_Stuff );
            return r;
        }
        case SHA2_512: {
            std::vector<uint8_t> r(CC_SHA512_DIGEST_LENGTH);
            CC_SHA512_Final( r.data(), (CC_SHA512_CTX*)m_Stuff );
            return r;
        }
        case MD2: {
            std::vector<uint8_t> r(CC_MD2_DIGEST_LENGTH);
            CC_MD2_Final( r.data(), (CC_MD2_CTX*)m_Stuff );
            return r;
        }
        case MD4: {
            std::vector<uint8_t> r(CC_MD4_DIGEST_LENGTH);
            CC_MD4_Final( r.data(), (CC_MD4_CTX*)m_Stuff );
            return r;
        }
        case MD5: {
            std::vector<uint8_t> r(CC_MD5_DIGEST_LENGTH);
            CC_MD5_Final( r.data(), (CC_MD5_CTX*)m_Stuff );
            return r;
        }
        case Adler32:
        case CRC32:
            return std::vector<uint8_t>{ m_Stuff[3], m_Stuff[2], m_Stuff[1], m_Stuff[0] };
        default: assert(0);
    }
    return std::vector<uint8_t>();
}

std::string Hash::Hex(const std::vector<uint8_t> &_d)
{
    static const char c[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
    std::string r;
    r.reserve( _d.size() * 2 );
    for(auto i: _d) {
        r += c[(i & 0xF0) >> 4];
        r += c[i & 0x0F];
    }
    return r;
}

}
