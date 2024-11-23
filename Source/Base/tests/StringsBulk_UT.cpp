// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/StringsBulk.h>
#include "UnitTests_main.h"

#define PREFIX "StringsBulk "

using nc::base::StringsBulk;
using namespace std;

TEST_CASE(PREFIX "empty")
{
    const StringsBulk sb1;
    CHECK(sb1.size() == 0); // NOLINT
    CHECK(sb1.empty() == true);

    const StringsBulk sb2 = StringsBulk::Builder{}.Build();
    CHECK(sb2.size() == 0); // NOLINT
    CHECK(sb2.empty() == true);
}

TEST_CASE(PREFIX "basic")
{
    StringsBulk::Builder sbb;
    sbb.Add("Hello");
    sbb.Add(", ");
    sbb.Add("World!");
    const auto sb = sbb.Build();
    CHECK(sb.size() == 3);

    CHECK(sb[0] == "Hello"s);
    CHECK(sb[1] == ", "s);
    CHECK(sb[2] == "World!"s);
}

TEST_CASE(PREFIX "empty strings")
{
    const auto s = ""s;
    const auto n = 1000000;
    StringsBulk::Builder sbb;
    for( int i = 0; i < n; ++i )
        sbb.Add(s);
    const auto sb = sbb.Build();
    std::string out;
    for( int i = 0; i < n; ++i )
        out += sb[i];
    CHECK(out == ""); // NOLINT
}

TEST_CASE(PREFIX "invalid at")
{
    const StringsBulk sb;
    CHECK_THROWS(sb.at(1));
}

TEST_CASE(PREFIX "random strings")
{
    const auto n = 10000;
    vector<string> v;
    for( int i = 0; i < n; ++i ) {
        const auto l = rand() % 1000;
        string s(l, ' ');
        for( int j = 0; j < l; ++j )
            s[j] = static_cast<unsigned char>((j % 255) + 1);
        v.emplace_back(s);
    }
    StringsBulk::Builder sbb;
    for( int i = 0; i < n; ++i )
        sbb.Add(v[i]);

    const auto sb = sbb.Build();
    for( int i = 0; i < n; ++i ) {
        CHECK(sb[i] == v[i]);
        CHECK(sb.at(i) == v[i]);
        CHECK(sb.string_length(i) == v[i].length());
    }

    int index = 0;
    for( auto s : sb )
        CHECK(s == v[index++]);
}

TEST_CASE(PREFIX "non-owning builder")
{
    const auto n = 10000;
    vector<string> v;
    for( int i = 0; i < n; ++i ) {
        const auto l = rand() % 1000;
        string s(l, ' ');
        for( int j = 0; j < l; ++j )
            s[j] = static_cast<unsigned char>((j % 255) + 1);
        v.emplace_back(s);
    }
    StringsBulk::NonOwningBuilder sbb;
    for( int i = 0; i < n; ++i )
        sbb.Add(v[i]);

    const auto sb = sbb.Build();
    for( int i = 0; i < n; ++i ) {
        CHECK(sb[i] == v[i]);
        CHECK(sb.at(i) == v[i]);
    }

    int index = 0;
    for( auto s : sb )
        CHECK(s == v[index++]);
}

TEST_CASE(PREFIX "equality")
{
    StringsBulk::Builder sbb;
    sbb.Add("Hello");
    sbb.Add(", ");
    sbb.Add("World!");

    auto a = sbb.Build();
    auto b = sbb.Build();
    CHECK(a == b);
    CHECK(!(a != b));

    sbb.Add("Da Capo");
    auto c = sbb.Build();
    CHECK(a != c);
    CHECK(!(a == c));
    CHECK(b != c);
    CHECK(!(b == c));

    b = c;
    CHECK(b == c);
    CHECK(b != a);

    StringsBulk d{c};
    CHECK(d == c);
    CHECK(d == b);
    CHECK(d != a);

    // NOLINTBEGIN(bugprone-use-after-move)
    StringsBulk e;
    e = std::move(d);
    CHECK(e == c);
    CHECK(d.empty());
    // NOLINTEND(bugprone-use-after-move)
}
