// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/chained_strings.h>
#include "UnitTests_main.h"
#include <random>

using nc::base::chained_strings;
using namespace std;

#define PREFIX "chained_strings "

TEST_CASE(PREFIX "basic")
{
    chained_strings strings;

    CHECK(strings.empty() == true);
    CHECK(strings.size() == 0); // NOLINT
    CHECK_THROWS(strings.front());
    CHECK_THROWS(strings.back());
    CHECK_THROWS(strings.push_back(nullptr, 0, nullptr));
    CHECK_THROWS(strings.push_back(nullptr, nullptr));
    CHECK(strings.empty() == true);
    CHECK(strings.singleblock() == false);

    const string str("hello");
    strings.push_back(str, nullptr);
    CHECK(strings.empty() == false);
    CHECK(strings.size() == 1);
    CHECK(str == strings.front().c_str());
    CHECK(str == strings.back().c_str());
    CHECK(strings.singleblock() == true);

    for( auto i : strings )
        CHECK(str == i.c_str());

    const string long_str("this is a very long string which will presumably "
                          "never fit into built-in buffer");
    strings.push_back(long_str, nullptr);
    CHECK(strings.empty() == false);
    CHECK(strings.size() == 2);
    CHECK(str == strings.front().c_str());
    CHECK(long_str == strings.back().c_str());
    CHECK(str.size() == strings.front().size());
    CHECK(long_str.size() == strings.back().size());

    chained_strings empty;
    strings.swap(empty);
    CHECK(strings.empty() == true);
    CHECK(strings.size() == 0); // NOLINT
}

TEST_CASE(PREFIX "blocks")
{
    const int amount = 1000000;

    const string str("hello from the underworld of mallocs and frees");
    chained_strings strings;

    for( int i = 0; i < amount; ++i )
        strings.push_back(str, nullptr);

    CHECK(strings.singleblock() == false);
    CHECK(strings.size() == amount);

    unsigned total_sz = 0;
    for( auto i : strings )
        total_sz += i.size();

    CHECK(total_sz == str.size() * amount);
}

TEST_CASE(PREFIX "prefix")
{
    mt19937 mt((random_device())());
    uniform_int_distribution<int> dist(0, 100000);

    chained_strings strings;
    const chained_strings::node *pref = nullptr;
    string predicted_string;
    const int amount = 100;
    for( int i = 0; i < amount; ++i ) {
        const string rnd = to_string(dist(mt));

        predicted_string += rnd;
        strings.push_back(rnd, pref);
        pref = &strings.back();
    }

    char buffer[10000];
    strings.back().str_with_pref(buffer);

    CHECK(predicted_string == buffer);
    CHECK(predicted_string == strings.back().to_str_with_pref());
}

TEST_CASE(PREFIX "regressions")
{
    chained_strings strings;
    CHECK(begin(strings) == end(strings));
    CHECK(!(begin(strings) != end(strings)));
}
