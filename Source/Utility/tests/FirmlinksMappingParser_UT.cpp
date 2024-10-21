// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FirmlinksMappingParser.h"
#include "UnitTests_main.h"
#include <fstream>

using nc::utility::FirmlinksMappingParser;
#define PREFIX "nc::utility::FirmlinksMappingParser "

TEST_CASE(PREFIX "Works against predefined mapping")
{
    const auto mapping = "/AppleInternal\x09"
                         "AppleInternal\x0A"
                         "/Applications\x09"
                         "Applications\x0A"
                         "/Library\x09"
                         "Library\x0A"
                         "/System/Library/Caches\x09"
                         "System/Library/Caches\x0A"
                         "/System/Library/Assets\x09"
                         "System/Library/Assets\x0A"
                         "/System/Library/PreinstalledAssets\x09"
                         "System/Library/PreinstalledAssets\x0A"
                         "/System/Library/AssetsV2\x09"
                         "System/Library/AssetsV2\x0A"
                         "/System/Library/PreinstalledAssetsV2\x09"
                         "System/Library/PreinstalledAssetsV2\x0A"
                         "/System/Library/CoreServices/CoreTypes.bundle/Contents/Library\x09"
                         "System/Library/CoreServices/CoreTypes.bundle/Contents/Library\x0A"
                         "/System/Library/Speech\x09"
                         "System/Library/Speech\x0A"
                         "/Users\x09"
                         "Users\x0A"
                         "/Volumes\x09"
                         "Volumes\x0A"
                         "/cores\x09"
                         "cores\x0A"
                         "/opt\x09"
                         "opt\x0A"
                         "/private\x09"
                         "private\x0A"
                         "/usr/local\x09"
                         "usr/local\x0A"
                         "/usr/libexec/cups\x09"
                         "usr/libexec/cups\x0A"
                         "/usr/share/snmp\x09"
                         "usr/share/snmp";

    auto parsed = FirmlinksMappingParser::Parse(mapping);

    REQUIRE(parsed.size() == 18);
    using L = FirmlinksMappingParser::Firmlink;
    CHECK(parsed[0] == L{"/AppleInternal", "AppleInternal"});
    CHECK(parsed[1] == L{"/Applications", "Applications"});
    CHECK(parsed[2] == L{"/Library", "Library"});
    CHECK(parsed[3] == L{"/System/Library/Caches", "System/Library/Caches"});
    CHECK(parsed[4] == L{"/System/Library/Assets", "System/Library/Assets"});
    CHECK(parsed[5] == L{"/System/Library/PreinstalledAssets", "System/Library/PreinstalledAssets"});
    CHECK(parsed[6] == L{"/System/Library/AssetsV2", "System/Library/AssetsV2"});
    CHECK(parsed[7] == L{"/System/Library/PreinstalledAssetsV2", "System/Library/PreinstalledAssetsV2"});
    CHECK(parsed[8] == L{"/System/Library/CoreServices/CoreTypes.bundle/Contents/Library",
                         "System/Library/CoreServices/CoreTypes.bundle/Contents/Library"});
    CHECK(parsed[9] == L{"/System/Library/Speech", "System/Library/Speech"});
    CHECK(parsed[10] == L{"/Users", "Users"});
    CHECK(parsed[11] == L{"/Volumes", "Volumes"});
    CHECK(parsed[12] == L{"/cores", "cores"});
    CHECK(parsed[13] == L{"/opt", "opt"});
    CHECK(parsed[14] == L{"/private", "private"});
    CHECK(parsed[15] == L{"/usr/local", "usr/local"});
    CHECK(parsed[16] == L{"/usr/libexec/cups", "usr/libexec/cups"});
    CHECK(parsed[17] == L{"/usr/share/snmp", "usr/share/snmp"});
}

TEST_CASE(PREFIX "Works against system mapping")
{
    // not a "unit" test per se, but doesn't worth making another IT for this...
    const auto path = "/usr/share/firmlinks";
    std::ifstream in(path, std::ios::in | std::ios::binary);
    REQUIRE(in);
    std::string mapping;
    in.seekg(0, std::ios::end);
    mapping.resize(in.tellg());
    in.seekg(0, std::ios::beg);
    in.read(mapping.data(), mapping.size());
    in.close();

    auto parsed = FirmlinksMappingParser::Parse(mapping);

    CHECK(!parsed.empty());
}
