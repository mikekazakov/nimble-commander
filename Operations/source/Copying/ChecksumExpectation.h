// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <vector>
#include <stdint.h>

namespace nc::ops::copying {

struct ChecksumExpectation
{
    ChecksumExpectation(int _source_ind,
                        std::string _destination,
                        const std::vector<uint8_t> &_md5 );
    std::string destination_path;
    int original_item;
    struct {
        uint8_t buf[16];
    } md5;
};

bool operator==( const ChecksumExpectation &_lhs, const std::vector<uint8_t> &_rhs ) noexcept;
bool operator==( const std::vector<uint8_t> &_rhs, const ChecksumExpectation &_lhs ) noexcept;

}
