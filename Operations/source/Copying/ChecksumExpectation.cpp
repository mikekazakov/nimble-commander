// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChecksumExpectation.h"

namespace nc::ops::copying {

ChecksumExpectation::ChecksumExpectation(int _source_ind,
                                         string _destination,
                                         const vector<uint8_t> &_md5 ):
    original_item( _source_ind ),
    destination_path( move(_destination) )
{
    if(_md5.size() != 16)
        throw invalid_argument("ChecksumExpectation: _md5 should be 16 bytes long!");
    copy(begin(_md5), end(_md5), begin(md5.buf));
}

bool operator==( const ChecksumExpectation &_lhs, const vector<uint8_t> &_rhs ) noexcept
{
    return _rhs.size() == 16 && equal(begin(_rhs), end(_rhs), begin(_lhs.md5.buf));
}

bool operator==( const vector<uint8_t> &_rhs, const ChecksumExpectation &_lhs ) noexcept
{
    return _lhs == _rhs;
}

}
