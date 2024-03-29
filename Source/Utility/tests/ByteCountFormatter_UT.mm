// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include <Utility/ByteCountFormatter.h>

#define PREFIX "ByteCountFormatter "

TEST_CASE(PREFIX "Just some tests")
{
    ByteCountFormatter f(false);
    auto t = ByteCountFormatter::Adaptive6;
    CHECK([f.ToNSString(0, t) isEqualToString:@"0 B"]);
    CHECK([f.ToNSString(5, t) isEqualToString:@"5 B"]);
    CHECK([f.ToNSString(20, t) isEqualToString:@"20 B"]);
    CHECK([f.ToNSString(100, t) isEqualToString:@"100 B"]);
    CHECK([f.ToNSString(999, t) isEqualToString:@"999 B"]);
    CHECK([f.ToNSString(1000, t) isEqualToString:@"1000 B"]);
    CHECK([f.ToNSString(1023, t) isEqualToString:@"1023 B"]);
    CHECK([f.ToNSString(1024, t) isEqualToString:@"1.0 KB"]);
    CHECK([f.ToNSString(1025, t) isEqualToString:@"1.0 KB"]);
    CHECK([f.ToNSString(1050, t) isEqualToString:@"1.0 KB"]);
    CHECK([f.ToNSString(1051, t) isEqualToString:@"1.0 KB"]);
    CHECK([f.ToNSString(1099, t) isEqualToString:@"1.1 KB"]);
    CHECK([f.ToNSString(6000, t) isEqualToString:@"5.9 KB"]);
    CHECK([f.ToNSString(5949, t) isEqualToString:@"5.8 KB"]);
    CHECK([f.ToNSString(1024 * 1024, t) isEqualToString:@"1.0 MB"]);
    CHECK([f.ToNSString(1024 * 1024 - 10, t) isEqualToString:@"1.0 MB"]);
    CHECK([f.ToNSString(1024 * 1024 + 10, t) isEqualToString:@"1.0 MB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024 * 1024 * 1.5), t) isEqualToString:@"1.5 MB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024 * 9.9), t) isEqualToString:@"9.9 KB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024 * 9.97), t) isEqualToString:@"10 KB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024 * 1024 * 9.97), t) isEqualToString:@"10 MB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024 * 1024 * 5.97), t) isEqualToString:@"6.0 MB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024 * 1024 * 5.90), t) isEqualToString:@"5.9 MB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 5.5), t)
        isEqualToString:@"5.5 GB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 10.5), t)
        isEqualToString:@"10 GB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 10.6), t)
        isEqualToString:@"11 GB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 156.6), t)
        isEqualToString:@"157 GB"]);
    CHECK([f.ToNSString(10138681344ull, t) isEqualToString:@"9.5 GB"]);
    CHECK([f.ToNSString(static_cast<uint64_t>(1024ull * 1024ull * 1024ull * 1024ull * 2.3), t)
        isEqualToString:@"2.3 TB"]);
    CHECK([f.ToNSString(1055872262ull, t) isEqualToString:@"1.0 GB"]);
}
