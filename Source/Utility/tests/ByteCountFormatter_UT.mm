// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include <Utility/ByteCountFormatter.h>
#include <fmt/format.h>

#define PREFIX "ByteCountFormatter "

TEST_CASE(PREFIX "Adaptive6")
{
    const ByteCountFormatter f(false);
    struct TC {
        uint64_t size;
        NSString *expected;
    } tcs[] = {
        {.size = 0ull, .expected = @"0 B"},
        {.size = 5ull, .expected = @"5 B"},
        {.size = 20ull, .expected = @"20 B"},
        {.size = 100ull, .expected = @"100 B"},
        {.size = 999ull, .expected = @"999 B"},
        {.size = 1000ull, .expected = @"1000 B"},
        {.size = 1023ull, .expected = @"1023 B"},
        {.size = 1024ull, .expected = @"1.0 KB"},
        {.size = 1025ull, .expected = @"1.0 KB"},
        {.size = 1050ull, .expected = @"1.0 KB"},
        {.size = 1051ull, .expected = @"1.0 KB"},
        {.size = 1051ull, .expected = @"1.0 KB"},
        {.size = 1099ull, .expected = @"1.1 KB"},
        {.size = 5949ull, .expected = @"5.8 KB"},
        {.size = 6000ull, .expected = @"5.9 KB"},
        {.size = 1024ull * 1024ull, .expected = @"1.0 MB"},
        {.size = (1024ull * 1024ull) - 10, .expected = @"1.0 MB"},
        {.size = (1024ull * 1024ull) + 10, .expected = @"1.0 MB"},
        {.size = static_cast<uint64_t>(1024 * 1024 * 1.5), .expected = @"1.5 MB"},
        {.size = static_cast<uint64_t>(1024 * 9.9), .expected = @"9.9 KB"},
        {.size = static_cast<uint64_t>(1024 * 9.97), .expected = @"10 KB"},
        {.size = static_cast<uint64_t>(1024 * 1024 * 9.97), .expected = @"10 MB"},
        {.size = static_cast<uint64_t>(1024 * 1024 * 5.97), .expected = @"6.0 MB"},
        {.size = static_cast<uint64_t>(1024 * 1024 * 5.90), .expected = @"5.9 MB"},
        {.size = static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 5.5), .expected = @"5.5 GB"},
        {.size = static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 10.5), .expected = @"10 GB"},
        {.size = static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 10.6), .expected = @"11 GB"},
        {.size = static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 156.6), .expected = @"157 GB"},
        {.size = 10138681344ull, .expected = @"9.5 GB"},
        {.size = static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 1024ull * 2.3), .expected = @"2.3 TB"},
        {.size = 1055872262ull, .expected = @"1.0 GB"},
    };
    for( auto &tc : tcs ) {
        CHECK([f.ToNSString(tc.size, ByteCountFormatter::Adaptive6) isEqualToString:tc.expected]);
    }
}

TEST_CASE(PREFIX "Adaptive8")
{
    const ByteCountFormatter f(false);
    struct TC {
        uint64_t size;
        NSString *expected;
    } tcs[] = {
        {.size = 0ull, .expected = @"0 B"},
        {.size = 5ull, .expected = @"5 B"},
        {.size = 20ull, .expected = @"20 B"},
        {.size = 100ull, .expected = @"100 B"},
        {.size = 998ull, .expected = @"998 B"},
        {.size = 999ull, .expected = @"1 KB"},
        {.size = 1000ull, .expected = @"1 KB"},
        {.size = 512000ull, .expected = @"500 KB"},
        {.size = 1022975ull, .expected = @"999 KB"},
        {.size = 1022976ull, .expected = @"0.98 MB"},
        {.size = 59538145ull, .expected = @"56.78 MB"},
        {.size = 103809023ull, .expected = @"99.00 MB"},
        {.size = 103809024ull, .expected = @"0.10 GB"},
        {.size = 60967060767ull, .expected = @"56.78 GB"},
        {.size = 106300440575ull, .expected = @"99.00 GB"},
        {.size = 106300440576ull, .expected = @"0.10 TB"},
        {.size = 62430270225121ull, .expected = @"56.78 TB"},
        {.size = 108851651149823ull, .expected = @"99.00 TB"},
        {.size = 108851651149824ull, .expected = @"0.10 PB"},
        {.size = 63928596710524184ull, .expected = @"56.78 PB"},
        {.size = 111464090777419775ull, .expected = @"99.00 PB"},
        {.size = 111464090777419776ull, .expected = @""},

    };
    for( auto &tc : tcs ) {
        INFO(fmt::format("{} - {} - {}",
                         tc.size,
                         f.ToNSString(tc.size, ByteCountFormatter::Adaptive8).UTF8String,
                         tc.expected.UTF8String));
        CHECK([f.ToNSString(tc.size, ByteCountFormatter::Adaptive8) isEqualToString:tc.expected]);
    }
}

TEST_CASE(PREFIX "Fixed6")
{
    const ByteCountFormatter f(false);
    struct TC {
        uint64_t size;
        NSString *expected;
    } tcs[] = {
        {.size = 0ull, .expected = @"0"},
        {.size = 999999ull, .expected = @"999999"},
        {.size = 1000000ull, .expected = @"977 K"},
        {.size = 5120000ull, .expected = @"5000 K"},
        {.size = 10238975ull, .expected = @"9999 K"},
        {.size = 10238976ull, .expected = @"10 M"},
        {.size = 5242880000ull, .expected = @"5000 M"},
        {.size = 10484711423ull, .expected = @"9999 M"},
        {.size = 10484711424ull, .expected = @"10 G"},
        {.size = 5368709120000ull, .expected = @"5000 G"},
        {.size = 10736344498175ull, .expected = @"9999 G"},
        {.size = 10736344498176ull, .expected = @"10 T"},
        {.size = 5497558138880000ull, .expected = @"5000 T"},
        {.size = 10994016766132223ull, .expected = @"9999 T"},
        {.size = 10994016766132224ull, .expected = @"10 P"},
        {.size = 5629499534213120000ull, .expected = @"5000 P"},
        {.size = 11257873168519397375ull, .expected = @"9999 P"},
        {.size = 11257873168519397376ull, .expected = @""},
    };
    for( auto &tc : tcs ) {
        CHECK([f.ToNSString(tc.size, ByteCountFormatter::Fixed6) isEqualToString:tc.expected]);
    }
}

TEST_CASE(PREFIX "SpaceSeparated")
{
    const ByteCountFormatter f(false);
    struct TC {
        uint64_t size;
        NSString *expected;
    } tcs[] = {
        {.size = 0ull, .expected = @"0 bytes"},
        {.size = 999ull, .expected = @"999 bytes"},
        {.size = 1'000ull, .expected = @"1 000 bytes"},
        {.size = 999'999ull, .expected = @"999 999 bytes"},
        {.size = 1'000'000ull, .expected = @"1 000 000 bytes"},
        {.size = 999'999'999ull, .expected = @"999 999 999 bytes"},
        {.size = 1'000'000'000ull, .expected = @"1 000 000 000 bytes"},
        {.size = 999'999'999'999ull, .expected = @"999 999 999 999 bytes"},
        {.size = 1'000'000'000'000ull, .expected = @"1 000 000 000 000 bytes"},
        {.size = 999'999'999'999'999ull, .expected = @"999 999 999 999 999 bytes"},
        {.size = 1'000'000'000'000'000ull, .expected = @"bytes"},
    };
    for( auto &tc : tcs ) {
        CHECK([f.ToNSString(tc.size, ByteCountFormatter::SpaceSeparated) isEqualToString:tc.expected]);
    }
}
