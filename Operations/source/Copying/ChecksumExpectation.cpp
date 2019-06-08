// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChecksumExpectation.h"

namespace nc::ops::copying {

ChecksumExpectation::ChecksumExpectation(int _source_ind,
                                         std::string _destination,
                                         const std::vector<uint8_t> &_md5 ):
    destination_path( move(_destination) ),
    original_item( _source_ind )
{
    if(_md5.size() != 16)
        throw std::invalid_argument("ChecksumExpectation: _md5 should be 16 bytes long!");
    std::copy(std::begin(_md5), std::end(_md5), std::begin(md5.buf));
}

bool operator==( const ChecksumExpectation &_lhs, const std::vector<uint8_t> &_rhs ) noexcept
{
    return _rhs.size() == 16 &&
        std::equal(std::begin(_rhs),
                   std::end(_rhs),
                   std::begin(_lhs.md5.buf));
}

bool operator==( const std::vector<uint8_t> &_rhs, const ChecksumExpectation &_lhs ) noexcept
{
    return _lhs == _rhs;
}

}
