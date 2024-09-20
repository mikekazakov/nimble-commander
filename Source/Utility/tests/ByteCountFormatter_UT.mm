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
        {0ull, @"0 B"},
        {5ull, @"5 B"},
        {20ull, @"20 B"},
        {100ull, @"100 B"},
        {999ull, @"999 B"},
        {1000ull, @"1000 B"},
        {1023ull, @"1023 B"},
        {1024ull, @"1.0 KB"},
        {1025ull, @"1.0 KB"},
        {1050ull, @"1.0 KB"},
        {1051ull, @"1.0 KB"},
        {1051ull, @"1.0 KB"},
        {1099ull, @"1.1 KB"},
        {5949ull, @"5.8 KB"},
        {6000ull, @"5.9 KB"},
        {1024ull * 1024ull, @"1.0 MB"},
        {1024ull * 1024ull - 10, @"1.0 MB"},
        {1024ull * 1024ull + 10, @"1.0 MB"},
        {static_cast<uint64_t>(1024 * 1024 * 1.5), @"1.5 MB"},
        {static_cast<uint64_t>(1024 * 9.9), @"9.9 KB"},
        {static_cast<uint64_t>(1024 * 9.97), @"10 KB"},
        {static_cast<uint64_t>(1024 * 1024 * 9.97), @"10 MB"},
        {static_cast<uint64_t>(1024 * 1024 * 5.97), @"6.0 MB"},
        {static_cast<uint64_t>(1024 * 1024 * 5.90), @"5.9 MB"},
        {static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 5.5), @"5.5 GB"},
        {static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 10.5), @"10 GB"},
        {static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 10.6), @"11 GB"},
        {static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 156.6), @"157 GB"},
        {10138681344ull, @"9.5 GB"},
        {static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 1024ull * 2.3), @"2.3 TB"},
        {1055872262ull, @"1.0 GB"},
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
        {0ull, @"0 B"},
        {5ull, @"5 B"},
        {20ull, @"20 B"},
        {100ull, @"100 B"},
        {998ull, @"998 B"},
        {999ull, @"1 KB"},
        {1000ull, @"1 KB"},
        {512000ull, @"500 KB"},
        {1022975ull, @"999 KB"},
        {1022976ull, @"0.98 MB"},
        {59538145ull, @"56.78 MB"},
        {103809023ull, @"99.00 MB"},
        {103809024ull, @"0.10 GB"},
        {60967060767ull, @"56.78 GB"},
        {106300440575ull, @"99.00 GB"},
        {106300440576ull, @"0.10 TB"},
        {62430270225121ull, @"56.78 TB"},
        {108851651149823ull, @"99.00 TB"},
        {108851651149824ull, @"0.10 PB"},
        {63928596710524184ull, @"56.78 PB"},
        {111464090777419775ull, @"99.00 PB"},
        {111464090777419776ull, @""},

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
        {0ull, @"0"},
        {999999ull, @"999999"},
        {1000000ull, @"977 K"},
        {5120000ull, @"5000 K"},
        {10238975ull, @"9999 K"},
        {10238976ull, @"10 M"},
        {5242880000ull, @"5000 M"},
        {10484711423ull, @"9999 M"},
        {10484711424ull, @"10 G"},
        {5368709120000ull, @"5000 G"},
        {10736344498175ull, @"9999 G"},
        {10736344498176ull, @"10 T"},
        {5497558138880000ull, @"5000 T"},
        {10994016766132223ull, @"9999 T"},
        {10994016766132224ull, @"10 P"},
        {5629499534213120000ull, @"5000 P"},
        {11257873168519397375ull, @"9999 P"},
        {11257873168519397376ull, @""},
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
        {0ull, @"0 bytes"},
        {999ull, @"999 bytes"},
        {1'000ull, @"1 000 bytes"},
        {999'999ull, @"999 999 bytes"},
        {1'000'000ull, @"1 000 000 bytes"},
        {999'999'999ull, @"999 999 999 bytes"},
        {1'000'000'000ull, @"1 000 000 000 bytes"},
        {999'999'999'999ull, @"999 999 999 999 bytes"},
        {1'000'000'000'000ull, @"1 000 000 000 000 bytes"},
        {999'999'999'999'999ull, @"999 999 999 999 999 bytes"},
        {1'000'000'000'000'000ull, @"bytes"},
    };
    for( auto &tc : tcs ) {
        CHECK([f.ToNSString(tc.size, ByteCountFormatter::SpaceSeparated) isEqualToString:tc.expected]);
    }
}
