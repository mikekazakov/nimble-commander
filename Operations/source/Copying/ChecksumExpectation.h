// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops::copying {

struct ChecksumExpectation
{
    ChecksumExpectation( int _source_ind, string _destination, const vector<uint8_t> &_md5 );
    string destination_path;
    int original_item;
    struct {
        uint8_t buf[16];
    } md5;
};

bool operator==( const ChecksumExpectation &_lhs, const vector<uint8_t> &_rhs ) noexcept;
bool operator==( const vector<uint8_t> &_rhs, const ChecksumExpectation &_lhs ) noexcept;

}
