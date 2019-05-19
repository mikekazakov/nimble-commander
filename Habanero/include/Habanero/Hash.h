// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>
#include <string>
#include <stdint.h>

namespace nc::base {

class Hash
{
public:
    enum Mode {
        Adler32,
        CRC32,
        MD2,
        MD4,
        MD5,
        SHA1_160,
        SHA2_224,
        SHA2_256,
        SHA2_384,
        SHA2_512,
    };
    
    Hash(Mode _mode);
    
    Hash& Feed(const void *_data, size_t _size);
    std::vector<uint8_t> Final();
    
    static std::string Hex(const std::vector<uint8_t> &_d);
    
private:
    Mode    m_Mode;
    uint8_t m_Stuff[1024];
};

}
