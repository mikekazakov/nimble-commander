// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/StringViewZBuf.h>
#include "UnitTests_main.h"

#define PREFIX "StringViewZBuf "

using nc::base::StringViewZBuf;
using namespace std;

TEST_CASE(PREFIX"Empty")
{
    std::string_view v{""};
    StringViewZBuf<1> zb{v};
    CHECK( v == zb.c_str() );
    CHECK( zb.empty() == true );
}

TEST_CASE(PREFIX"Short")
{
    std::string_view v{"abcd"};
    StringViewZBuf<5> zb{v};
    CHECK( v == zb.c_str() );
    CHECK( zb.empty() == false );
}

TEST_CASE(PREFIX"Long")
{
    std::string_view v{"abcde"};
    StringViewZBuf<5> zb{v};
    CHECK( v == zb.c_str() );
    CHECK( zb.empty() == false );
}
