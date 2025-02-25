// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/NetSFTP.h>
#include <Base/dispatch_cpp.h>
#include <Base/DispatchGroup.h>
#include <Base/WriteAtomically.h>
#include <set>
#include <dirent.h>

using namespace nc;
using namespace nc::vfs;
using namespace std::string_literals;

#define PREFIX "VFSSFTP "

// Ubuntu 20.04 LTS running in a Docker
static const auto g_Ubuntu2004_Address = "127.0.0.1";
static const auto g_Ubuntu2004_Port = 9022;

// User1: password only
static const auto g_Ubuntu2004_User1 = "user1";
static const auto g_Ubuntu2004_User1Passwd = "Oc6har5tOu34";

// User2: password and RSA
static const auto g_Ubuntu2004_User2 = "user2";
static const std::string_view g_Ubuntu2004_User2RSA =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "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\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User3: password and DSA
static const auto g_Ubuntu2004_User3 = "user3";
static const std::string_view g_Ubuntu2004_User3DSA =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABsQAAAAdzc2gtZH\n"
    "NzAAAAgQCJILZJB/Mc9wuSlN0BhgjbNoIgBINskSbKzQeEhWl+CQIoFdUDh7TYiWLProIC\n"
    "Q2O1H1/7pW3I3EtAAW/X/sfBEYNMi7GyBIzUmDCZ5i5GK0p7Ehhsse7+GxC1ty2L1PPRR8\n"
    "qv1cPQPl0PjMgvOLnHsPfDUWGN29OfGA6aaocfawAAABUAgi2rJ3GGv1A88jI3mHTPIEKM\n"
    "uRkAAACAG2sX+8migHJStVNYBwpcZH1haYktTOKctK204CRKhXEoAcmE6rQD4PtiQaGcG1\n"
    "xdVyF1MXpDr1wYh/qBGt2VYYvNZYPHgsy2mkdJ6Zjghk0BXxwFqNnh4kCfQomFeG8DHEBX\n"
    "Hh2ofUUk64Jd1lV1aiWs7KNT+PNlXJVNs4JbaBgAAACAdE9FH/O6iCLQWZrCSWfoI+5o8Q\n"
    "JIgxce7aRKBGe+WoVwZ9fJbhURNzjdYT4SlLMfRG2fCBsO5rQ236So2heOHLKdKgvfQOHF\n"
    "4gtWT0baGMMbFu8a6ezo/7jhMUb6K7NDM6hqG4tklQ9Xg20bolNbD0u2Uvn1BsLAL/zC8d\n"
    "YWkMAAAAH4WTWZZ1k1mWcAAAAHc3NoLWRzcwAAAIEAiSC2SQfzHPcLkpTdAYYI2zaCIASD\n"
    "bJEmys0HhIVpfgkCKBXVA4e02Iliz66CAkNjtR9f+6VtyNxLQAFv1/7HwRGDTIuxsgSM1J\n"
    "gwmeYuRitKexIYbLHu/hsQtbcti9Tz0UfKr9XD0D5dD4zILzi5x7D3w1FhjdvTnxgOmmqH\n"
    "H2sAAAAVAIItqydxhr9QPPIyN5h0zyBCjLkZAAAAgBtrF/vJooByUrVTWAcKXGR9YWmJLU\n"
    "zinLSttOAkSoVxKAHJhOq0A+D7YkGhnBtcXVchdTF6Q69cGIf6gRrdlWGLzWWDx4LMtppH\n"
    "SemY4IZNAV8cBajZ4eJAn0KJhXhvAxxAVx4dqH1FJOuCXdZVdWolrOyjU/jzZVyVTbOCW2\n"
    "gYAAAAgHRPRR/zuogi0Fmawkln6CPuaPECSIMXHu2kSgRnvlqFcGfXyW4VETc43WE+EpSz\n"
    "H0RtnwgbDua0Nt+kqNoXjhyynSoL30DhxeILVk9G2hjDGxbvGuns6P+44TFG+iuzQzOoah\n"
    "uLZJUPV4NtG6JTWw9LtlL59QbCwC/8wvHWFpDAAAAAFB0dt9FqcE+qv1xZstiDGQnb4B1E\n"
    "AAAAIG1pZ3VuQE1pY2hhZWxzLU1CUC0xMy0yMDIwLmxvY2FsAQID\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User4: password and ECDSA
static const auto g_Ubuntu2004_User4 = "user4";
static const std::string_view g_Ubuntu2004_User4ECDSA =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS\n"
    "1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQS812n7vVlY9U6qOV/7OSjV52ZErs/l\n"
    "jdECY2Mg18a+LVvIUpjmhjUPMWrcDu/do7ujZRN1TIC3wKOruwgjnuR0AAAAwCLQRKMi0E\n"
    "SjAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLzXafu9WVj1Tqo5\n"
    "X/s5KNXnZkSuz+WN0QJjYyDXxr4tW8hSmOaGNQ8xatwO792ju6NlE3VMgLfAo6u7CCOe5H\n"
    "QAAAAhAJLzFa7asp+9KxTuFZuvmB6aBLu5WixfnHe+qM2ZFP4NAAAAIG1pZ3VuQE1pY2hh\n"
    "ZWxzLU1CUC0xMy0yMDIwLmxvY2FsAQIDBAUGBw==\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User5: password and ED25519
static const auto g_Ubuntu2004_User5 = "user5";
static const std::string_view g_Ubuntu2004_User5ED25519 =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW\n"
    "QyNTUxOQAAACDM4bb72J7DYM6UNKM3kV+426AhSgVhzGxJbHQgTOFKfgAAAKgiEChtIhAo\n"
    "bQAAAAtzc2gtZWQyNTUxOQAAACDM4bb72J7DYM6UNKM3kV+426AhSgVhzGxJbHQgTOFKfg\n"
    "AAAEBqF1ElZs7VtcsZoXspzq0kz8NKVcKl1tyYqIDPanj1fMzhtvvYnsNgzpQ0ozeRX7jb\n"
    "oCFKBWHMbElsdCBM4Up+AAAAIG1pZ3VuQE1pY2hhZWxzLU1CUC0xMy0yMDIwLmxvY2FsAQ\n"
    "IDBAU=\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User6: password, sftp-only
static const auto g_Ubuntu2004_User6 = "user6";
static const auto g_Ubuntu2004_User6Passwd = "QPC89AM!SPk9";

// User7: password-protected RSA
static const auto g_Ubuntu2004_User7 = "user7";
static const auto g_Ubuntu2004_User7Passwd = "ptBd980Bi2*W";
static const std::string_view g_Ubuntu2004_User7RSA =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "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\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User8: password-protected DSA
static const auto g_Ubuntu2004_User8 = "user8";
static const auto g_Ubuntu2004_User8Passwd = "*d8U@HjhjX03";
static const std::string_view g_Ubuntu2004_User8DSA =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABCqT2RY/f\n"
    "fM8TxXz+vB/BDNAAAAEAAAAAEAAAGzAAAAB3NzaC1kc3MAAACBAM+0BkbiP1JyuaDl5Us/\n"
    "4xAmuiT8BYGMBgCiAeEuXL/6IzYq1WSrPjSipKZbt9+fPgTY6aVLLCPEaU5I3I5Rk6arEL\n"
    "D/EOkAyZGaquPpXqZr+fVS9kYdpWOYdpjF0k0oCpbpAsBXvtThAMQjLwTSNTyq7nh7qJZk\n"
    "2EMvoBMGSlHfAAAAFQCQYDJ/8QQIxw8tWIWzGxMSLY7JgwAAAIEAoMWDAd55CH73gKwBZT\n"
    "PhQFSg7WdYG+QxkySefBrG0SHF5c82wGFlhRC5hICq5vv9+C57BPT1FeemNfekXg1QkO4e\n"
    "7QYX9ro7OW9SVRghP23NVOetwKU0J8SnriGptXvXALQLXLyamkzwEetGzIfesOEHfRGQuo\n"
    "+7XQTQ4q5rDAYAAACBAMrvlHLGJpVudfxVvsF1Z51RWXLQJWqx04vAqJcsc52Fy+p46Ein\n"
    "mdPRdCpWd1z+TNktwW3/pgPxd+6GYF/H6c8Psep2SSwMgxzJwRMeqmX3qT9MUWok6FFcLy\n"
    "IuRjr7JOLghTmYND0sGmL2heCcT/B/BHHMAOjyAZbzYVf4xeWNAAACADuXGi7X+gAqVJhY\n"
    "L6umGzIgRolDvjlf+u2dYEyg599zX1bLUvmuNRqH3u45fdvISfRu4x/XXjHjyW5Wm4encK\n"
    "+dOUcZuS4TYUSq9UaNgVpPE3ELQ5h+s0wsNwW7gCvPHjd5C7EQnMOXYMRsu/u3jy302G1o\n"
    "QgoPczYFURkU0NzBPyzU3eCDk6+r+94sm79AO8XTBCZcjUXpyn07ZsMAyzIkRBKD04hQun\n"
    "WaflXbUe4SvsG5sGF+CD0P9qioLilqlXwsXpILrl4sMHgte5RDy/930L+Zrz9hD5LqUSzG\n"
    "2bjNeAsiqXKyVv2xnql4oxopAKOSfy6s50RPgXMoSbD3Lj7WPagmP45Jdr4RQnP5vbHk93\n"
    "v7Zqy1g+57ROv2XYY2AHXVpFT7qt3zLSuFNAKZ11DvENS2aosv3b8j7d0Bgdp4PQDqmk4e\n"
    "i/ZQtlUjPPy4VvleQCyxUKRcMe1mLSWawzgXIYXWVHMjnW6pxdMNxgmSOgFKVutSoyWBPJ\n"
    "8QJpcwm6qIfVVs2kLNV+g+7MsxX+BWQod+qytDFCJ/7jf+9HXac3KCm/j2bGenma7MwtqW\n"
    "l23MHqMdQlo3ppJivEfCtWrX7L3RnSZiYCCxNCGLM5+DS5e7MfEhNAkrZ97AUwyK0ZCE7x\n"
    "/94CT5GWdcwq7C75U6Kd+zXSkk76UohTW/3dB/\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User9: password-protected ECDSA
static const auto g_Ubuntu2004_User9 = "user9";
static const auto g_Ubuntu2004_User9Passwd = "xf2pGC*Bc64W";
static const std::string_view g_Ubuntu2004_User9ECDSA =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABDnncxRQM\n"
    "7NrCCDKsLUEKOAAAAAEAAAAAEAAABoAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlz\n"
    "dHAyNTYAAABBBHCQH8BJn7QKBnPizD+fmM6RNbhpGGpPZ+YaMmCxCx2hI/UN6k9mKEMhia\n"
    "PxUSfpcJjq2Qj/jkTcKzOA5GgraO0AAADA6GeECVKbb7+qqLW02G21pA252YY6s/ZZBenE\n"
    "Rq+Gm32s33s/dF4OLCzl1OwOtUd5buOcWi16jdD5UmsClPgxVXwTjeI2aw6PQvtWEiBYgV\n"
    "OJ4s/760ZnGFKVCVkkiqNGxEEcx+w7aPL2LW4EGyQMX8qIEktLm7ToI2tglaL5vTcgYNLG\n"
    "NqvcNanaolJyINJ/iEPaMuLAm2NgZRIsTMoa2PLBchOuMyO9h04M21znHOSPwbZU25sWjx\n"
    "oY+GJX67xD\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// User10: password-protected ED25519
static const auto g_Ubuntu2004_User10 = "user10";
static const auto g_Ubuntu2004_User10Passwd = "YJH8G#oV6P2G";
static const std::string_view g_Ubuntu2004_User10ED25519 =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABAiOJoI0B\n"
    "SGmMQy/b6d03qdAAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIEVyr5jry9GdvxXO\n"
    "5IySySIWmJbyglBLfrxaorba+wfEAAAAsDU1L1aNMprNNTRhmUGo92DxXCfoF0Wkz2tYlR\n"
    "LvPaVFpv1p0elTa9hEbU7inAryj39G16ZVxBetyea7nTcNf/RzqVkrmDxXxMw+JI68jxo7\n"
    "JB6CgiE6EXLBbLV4+ar+GvTXJtWrmHC91Iv/sE2jyaBkZdfI+G43ATN7aYi8M8KOGW57LE\n"
    "h823bwHH3o6wOJJ2js4i95xNpCsOHIRyg7Dy2EP8lJ2Is6c3+IaX4N2xoi\n"
    "-----END OPENSSH PRIVATE KEY-----\n";

// Root user: ED25519
static const auto g_Ubuntu2004_root = "root";
static const std::string_view g_Ubuntu2004_RootED25519 = g_Ubuntu2004_User5ED25519;

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User1_Pwd()
{
    return std::make_shared<SFTPHost>(
        g_Ubuntu2004_Address, g_Ubuntu2004_User1, g_Ubuntu2004_User1Passwd, "", g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User2_RSA()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User2RSA.data()), g_Ubuntu2004_User2RSA.length()}));
    return std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User2, "", path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User3_DSA()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User3DSA.data()), g_Ubuntu2004_User3DSA.length()}));
    return std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User3, "", path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User4_ECDSA()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User4ECDSA.data()), g_Ubuntu2004_User4ECDSA.length()}));
    return std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User4, "", path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User5_ED25519()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path,
        {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User5ED25519.data()), g_Ubuntu2004_User5ED25519.length()}));
    return std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User5, "", path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User6_Passwd()
{
    return std::make_shared<SFTPHost>(
        g_Ubuntu2004_Address, g_Ubuntu2004_User6, g_Ubuntu2004_User6Passwd, "", g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User7_RSA_Passwd()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User7RSA.data()), g_Ubuntu2004_User7RSA.length()}));
    return std::make_shared<SFTPHost>(
        g_Ubuntu2004_Address, g_Ubuntu2004_User7, g_Ubuntu2004_User7Passwd, path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User8_DSA_Passwd()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User8DSA.data()), g_Ubuntu2004_User8DSA.length()}));
    return std::make_shared<SFTPHost>(
        g_Ubuntu2004_Address, g_Ubuntu2004_User8, g_Ubuntu2004_User8Passwd, path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User9_ECDSA_Passwd()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User9ECDSA.data()), g_Ubuntu2004_User9ECDSA.length()}));
    return std::make_shared<SFTPHost>(
        g_Ubuntu2004_Address, g_Ubuntu2004_User9, g_Ubuntu2004_User9Passwd, path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_User10_ED25519_Passwd()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path,
        {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User10ED25519.data()), g_Ubuntu2004_User10ED25519.length()}));
    return std::make_shared<SFTPHost>(
        g_Ubuntu2004_Address, g_Ubuntu2004_User10, g_Ubuntu2004_User10Passwd, path, g_Ubuntu2004_Port);
}

static std::shared_ptr<SFTPHost> hostForUbuntu2004_Root_ED25519()
{
    const TestDir td;
    const auto path = td.directory / "key";
    REQUIRE(nc::base::WriteAtomically(
        path,
        {reinterpret_cast<const std::byte *>(g_Ubuntu2004_RootED25519.data()), g_Ubuntu2004_RootED25519.length()}));
    return std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_root, "", path, g_Ubuntu2004_Port);
}

static void TestUbuntu2004LayoutWithHost(SFTPHost &_host)
{
    // Check the Junction Path of this host
    CHECK(_host.JunctionPath() == std::string_view(g_Ubuntu2004_Address));
    CHECK(_host.MakePathVerbose("/Blah/") == "sftp://"s + _host.User() + "@" + g_Ubuntu2004_Address + "/Blah/");

    // Get the listing of a root directory
    VFSListingPtr root_listing = _host.FetchDirectoryListing("/", 0).value();
    REQUIRE(root_listing);
    auto at = [&](VFSListingPtr _listing, std::string_view _fn) {
        auto it = std::find_if(
            _listing->begin(), _listing->end(), [_fn](const auto &_entry) { return _entry.Filename() == _fn; });
        if( it != _listing->end() )
            return *it;
        throw std::out_of_range("Not found");
    };

    // Check that all the item on the root level are there
    // clang-format off
    const std::set<std::string> expected_root_listing{".dockerenv", "bin", "boot", "dev", "etc", "home", "lib",
        "media", "mnt", "opt", "proc", "root", "run", "sbin", "srv", "sys", "tmp", "usr", "var"};
    // clang-format on
    std::set<std::string> fact_root_listing;
    std::transform(root_listing->begin(),
                   root_listing->end(),
                   std::inserter(fact_root_listing, fact_root_listing.begin()),
                   [](auto &e) { return e.Filename(); });
    for( auto filename : {"lib32", "lib64", "libx32"} ) {
        // there's a descrepancy between the Ubuntu20.04/Docker running on Arm Mac and Intel Mac - the latter also has
        // these 3 items in the root folder. Ignore them.
        fact_root_listing.erase(filename);
    }
    REQUIRE(fact_root_listing == expected_root_listing);

    // Check the entries types at the root level
    CHECK(at(root_listing, ".dockerenv").UnixMode() == (S_IFREG | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "boot").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "dev").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "etc").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "home").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "lib").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "media").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "mnt").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "opt").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "proc").UnixMode() == (S_IFDIR | S_IRUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "root").UnixMode() == (S_IFDIR | S_IRWXU));
    CHECK(at(root_listing, "run").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "sbin").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "srv").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "sys").UnixMode() == (S_IFDIR | S_IRUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    CHECK(at(root_listing, "tmp").UnixMode() == (S_IFDIR | S_ISVTX | S_IRWXU | S_IRWXG | S_IRWXO));
    CHECK(at(root_listing, "usr").UnixMode() == (S_IFDIR | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));

    // Check the raw dirent types
    CHECK(at(root_listing, ".dockerenv").UnixType() == DT_REG);
    CHECK(at(root_listing, "bin").UnixType() == DT_LNK);
    CHECK(at(root_listing, "bin").Symlink() == "usr/bin");
    CHECK(at(root_listing, "boot").UnixType() == DT_DIR);
    CHECK(at(root_listing, "dev").UnixType() == DT_DIR);
    CHECK(at(root_listing, "etc").UnixType() == DT_DIR);
    CHECK(at(root_listing, "home").UnixType() == DT_DIR);
    CHECK(at(root_listing, "lib").UnixType() == DT_LNK);
    CHECK(at(root_listing, "lib").Symlink() == "usr/lib");
    CHECK(at(root_listing, "media").UnixType() == DT_DIR);
    CHECK(at(root_listing, "mnt").UnixType() == DT_DIR);
    CHECK(at(root_listing, "opt").UnixType() == DT_DIR);
    CHECK(at(root_listing, "proc").UnixType() == DT_DIR);
    CHECK(at(root_listing, "root").UnixType() == DT_DIR);
    CHECK(at(root_listing, "run").UnixType() == DT_DIR);
    CHECK(at(root_listing, "sbin").UnixType() == DT_LNK);
    CHECK(at(root_listing, "sbin").Symlink() == "usr/sbin");
    CHECK(at(root_listing, "srv").UnixType() == DT_DIR);
    CHECK(at(root_listing, "sys").UnixType() == DT_DIR);
    CHECK(at(root_listing, "tmp").UnixType() == DT_DIR);
    CHECK(at(root_listing, "usr").UnixType() == DT_DIR);
}

TEST_CASE(PREFIX "auth via plain password")
{
    auto host = hostForUbuntu2004_User1_Pwd();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user1");
}

TEST_CASE(PREFIX "auth via RSA key")
{
    auto host = hostForUbuntu2004_User2_RSA();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user2");
}

TEST_CASE(PREFIX "auth via DSA key")
{
    auto host = hostForUbuntu2004_User3_DSA();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user3");
}

TEST_CASE(PREFIX "auth via ECDSA key")
{
    auto host = hostForUbuntu2004_User4_ECDSA();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user4");
}

TEST_CASE(PREFIX "auth via ED25519 key")
{
    auto host = hostForUbuntu2004_User5_ED25519();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user5");
}

TEST_CASE(PREFIX "auth via password for SSH-less SFTP")
{
    auto host = hostForUbuntu2004_User6_Passwd();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user6");
}

TEST_CASE(PREFIX "auth via password-protected RSA key")
{
    auto host = hostForUbuntu2004_User7_RSA_Passwd();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user7");
}

TEST_CASE(PREFIX "auth via password-protected DSA key")
{
    auto host = hostForUbuntu2004_User8_DSA_Passwd();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user8");
}

TEST_CASE(PREFIX "auth via password-protected ECDSA key")
{
    auto host = hostForUbuntu2004_User9_ECDSA_Passwd();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user9");
}

TEST_CASE(PREFIX "auth via password-protected ED25519 key")
{
    auto host = hostForUbuntu2004_User10_ED25519_Passwd();
    TestUbuntu2004LayoutWithHost(*host);
    CHECK(host->HomeDir() == "/home/user10");
}

TEST_CASE(PREFIX "doesn't crash on many connections")
{
    auto host = hostForUbuntu2004_User1_Pwd();

    // in this test VFS must simply not crash under this workload.
    // returning errors on this case is ok at the moment
    const nc::base::DispatchGroup grp;
    for( int i = 0; i < 100; ++i )
        grp.Run([&] { std::ignore = host->Stat("/bin/cat", 0); });
    grp.Wait();
}

TEST_CASE(PREFIX "basic read")
{
    const VFSHostPtr host = hostForUbuntu2004_User1_Pwd();
    const VFSFilePtr file = host->CreateFile("/etc/debian_version").value();
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    const auto contents = file->ReadFile();
    REQUIRE(contents);

    const std::string_view expected{"bullseye/sid\n"};
    REQUIRE(contents->size() == expected.length());
    REQUIRE(memcmp(contents->data(), expected.data(), expected.length()) == 0);
}

TEST_CASE(PREFIX "read link")
{
    const VFSHostPtr host = hostForUbuntu2004_User1_Pwd();
    const std::expected<std::string, nc::Error> link = host->ReadSymlink("/etc/os-release");
    REQUIRE(link);
    REQUIRE(*link == std::string_view("../usr/lib/os-release"));
}

TEST_CASE(PREFIX "create link")
{
    const VFSHostPtr host = hostForUbuntu2004_User1_Pwd();
    const auto lnk_path = "/home/user1/smtest";
    const auto lnk_value = "/path/to/some/rubbish";
    const auto createlink_rc = host->CreateSymlink(lnk_path, lnk_value);
    REQUIRE(createlink_rc);

    const std::expected<std::string, nc::Error> link = host->ReadSymlink(lnk_path);
    REQUIRE(link);
    CHECK(*link == std::string_view(lnk_value));
    CHECK(host->Unlink(lnk_path));
}

TEST_CASE(PREFIX "chmod")
{
    const VFSHostPtr host = hostForUbuntu2004_User1_Pwd();
    const auto path = "/home/user1/chmodtest";

    REQUIRE(VFSEasyCreateEmptyFile(path, host) == VFSError::Ok);

    VFSStat st = host->Stat(path, 0).value();
    REQUIRE(st.mode_bits.xusr == 0);

    st.mode_bits.xusr = 1;
    REQUIRE(host->SetPermissions(path, st.mode));

    st = host->Stat(path, 0).value();
    REQUIRE(st.mode_bits.xusr == 1);

    REQUIRE(host->Unlink(path));
}

TEST_CASE(PREFIX "chown")
{
    const VFSHostPtr host = hostForUbuntu2004_Root_ED25519();
    const auto path = "/root/chowntest";

    REQUIRE(VFSEasyCreateEmptyFile(path, host) == VFSError::Ok);
    VFSStat st = host->Stat(path, 0).value();

    const auto new_uid = st.uid + 1;
    const auto new_gid = st.gid + 1;
    REQUIRE(host->SetOwnership(path, new_uid, new_gid));

    st = host->Stat(path, 0).value();
    REQUIRE(st.uid == new_uid);
    REQUIRE(st.gid == new_gid);

    REQUIRE(host->Unlink(path));
}

TEST_CASE(PREFIX "FetchUsers")
{
    const VFSHostPtr host = hostForUbuntu2004_User1_Pwd();
    const std::expected<std::vector<VFSUser>, nc::Error> users = host->FetchUsers();
    REQUIRE(users);
    const std::vector<VFSUser> expected_users{
        {.uid = 0, .name = "root", .gecos = "root"},
        {.uid = 1, .name = "daemon", .gecos = "daemon"},
        {.uid = 2, .name = "bin", .gecos = "bin"},
        {.uid = 3, .name = "sys", .gecos = "sys"},
        {.uid = 4, .name = "sync", .gecos = "sync"},
        {.uid = 5, .name = "games", .gecos = "games"},
        {.uid = 6, .name = "man", .gecos = "man"},
        {.uid = 7, .name = "lp", .gecos = "lp"},
        {.uid = 8, .name = "mail", .gecos = "mail"},
        {.uid = 9, .name = "news", .gecos = "news"},
        {.uid = 10, .name = "uucp", .gecos = "uucp"},
        {.uid = 13, .name = "proxy", .gecos = "proxy"},
        {.uid = 33, .name = "www-data", .gecos = "www-data"},
        {.uid = 34, .name = "backup", .gecos = "backup"},
        {.uid = 38, .name = "list", .gecos = "Mailing List Manager"},
        {.uid = 39, .name = "irc", .gecos = "ircd"},
        {.uid = 41, .name = "gnats", .gecos = "Gnats Bug-Reporting System (admin)"},
        {.uid = 100, .name = "_apt", .gecos = ""},
        {.uid = 101, .name = "systemd-timesync", .gecos = "systemd Time Synchronization"},
        {.uid = 102, .name = "systemd-network", .gecos = "systemd Network Management"},
        {.uid = 103, .name = "systemd-resolve", .gecos = "systemd Resolver"},
        {.uid = 104, .name = "messagebus", .gecos = ""},
        {.uid = 105, .name = "sshd", .gecos = ""},
        {.uid = 1000, .name = "user1", .gecos = ""},
        {.uid = 1001, .name = "user2", .gecos = ""},
        {.uid = 1002, .name = "user3", .gecos = ""},
        {.uid = 1003, .name = "user4", .gecos = ""},
        {.uid = 1004, .name = "user5", .gecos = ""},
        {.uid = 1005, .name = "user6", .gecos = ""},
        {.uid = 1006, .name = "user7", .gecos = ""},
        {.uid = 1007, .name = "user8", .gecos = ""},
        {.uid = 1008, .name = "user9", .gecos = ""},
        {.uid = 1009, .name = "user10", .gecos = ""},
        {.uid = 65534, .name = "nobody", .gecos = "nobody"}};
    CHECK(users == expected_users);
}

TEST_CASE(PREFIX "FetchGroups")
{
    const VFSHostPtr host = hostForUbuntu2004_User1_Pwd();
    const std::expected<std::vector<VFSGroup>, nc::Error> groups = host->FetchGroups();
    REQUIRE(groups);
    const std::vector<VFSGroup> expected_groups{{.gid = 0, .name = "root", .gecos = ""},
                                                {.gid = 1, .name = "daemon", .gecos = ""},
                                                {.gid = 2, .name = "bin", .gecos = ""},
                                                {.gid = 3, .name = "sys", .gecos = ""},
                                                {.gid = 4, .name = "adm", .gecos = ""},
                                                {.gid = 5, .name = "tty", .gecos = ""},
                                                {.gid = 6, .name = "disk", .gecos = ""},
                                                {.gid = 7, .name = "lp", .gecos = ""},
                                                {.gid = 8, .name = "mail", .gecos = ""},
                                                {.gid = 9, .name = "news", .gecos = ""},
                                                {.gid = 10, .name = "uucp", .gecos = ""},
                                                {.gid = 12, .name = "man", .gecos = ""},
                                                {.gid = 13, .name = "proxy", .gecos = ""},
                                                {.gid = 15, .name = "kmem", .gecos = ""},
                                                {.gid = 20, .name = "dialout", .gecos = ""},
                                                {.gid = 21, .name = "fax", .gecos = ""},
                                                {.gid = 22, .name = "voice", .gecos = ""},
                                                {.gid = 24, .name = "cdrom", .gecos = ""},
                                                {.gid = 25, .name = "floppy", .gecos = ""},
                                                {.gid = 26, .name = "tape", .gecos = ""},
                                                {.gid = 27, .name = "sudo", .gecos = ""},
                                                {.gid = 29, .name = "audio", .gecos = ""},
                                                {.gid = 30, .name = "dip", .gecos = ""},
                                                {.gid = 33, .name = "www-data", .gecos = ""},
                                                {.gid = 34, .name = "backup", .gecos = ""},
                                                {.gid = 37, .name = "operator", .gecos = ""},
                                                {.gid = 38, .name = "list", .gecos = ""},
                                                {.gid = 39, .name = "irc", .gecos = ""},
                                                {.gid = 40, .name = "src", .gecos = ""},
                                                {.gid = 41, .name = "gnats", .gecos = ""},
                                                {.gid = 42, .name = "shadow", .gecos = ""},
                                                {.gid = 43, .name = "utmp", .gecos = ""},
                                                {.gid = 44, .name = "video", .gecos = ""},
                                                {.gid = 45, .name = "sasl", .gecos = ""},
                                                {.gid = 46, .name = "plugdev", .gecos = ""},
                                                {.gid = 50, .name = "staff", .gecos = ""},
                                                {.gid = 60, .name = "games", .gecos = ""},
                                                {.gid = 100, .name = "users", .gecos = ""},
                                                {.gid = 101, .name = "systemd-timesync", .gecos = ""},
                                                {.gid = 102, .name = "systemd-journal", .gecos = ""},
                                                {.gid = 103, .name = "systemd-network", .gecos = ""},
                                                {.gid = 104, .name = "systemd-resolve", .gecos = ""},
                                                {.gid = 105, .name = "messagebus", .gecos = ""},
                                                {.gid = 106, .name = "ssh", .gecos = ""},
                                                {.gid = 1000, .name = "user1", .gecos = ""},
                                                {.gid = 1001, .name = "user2", .gecos = ""},
                                                {.gid = 1002, .name = "user3", .gecos = ""},
                                                {.gid = 1003, .name = "user4", .gecos = ""},
                                                {.gid = 1004, .name = "user5", .gecos = ""},
                                                {.gid = 1005, .name = "user6", .gecos = ""},
                                                {.gid = 1006, .name = "user7", .gecos = ""},
                                                {.gid = 1007, .name = "user8", .gecos = ""},
                                                {.gid = 1008, .name = "user9", .gecos = ""},
                                                {.gid = 1009, .name = "user10", .gecos = ""},
                                                {.gid = 65534, .name = "nogroup", .gecos = ""}

    };
    CHECK(groups == expected_groups);
}

// I had a weird behavior of ssh, which return a permission error when reading past end-of-file.
// That behaviour occured in VFSSeqToRandomWrapper
TEST_CASE(PREFIX "RandomWrappers")
{
    auto host = hostForUbuntu2004_User2_RSA();

    const VFSFilePtr seq_file = host->CreateFile(host->HomeDir() + "/.ssh/authorized_keys").value();

    auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(seq_file);
    REQUIRE(wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock, nullptr, nullptr) == VFSError::Ok);
}

TEST_CASE(PREFIX "Invalid auth")
{
    const TestDir td;
    const auto rsa = td.directory / "rsa";
    REQUIRE(nc::base::WriteAtomically(
        rsa, {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User2RSA.data()), g_Ubuntu2004_User2RSA.length()}));
    const auto passwdrsa = td.directory / "passwdrsa";
    REQUIRE(nc::base::WriteAtomically(
        passwdrsa,
        {reinterpret_cast<const std::byte *>(g_Ubuntu2004_User7RSA.data()), g_Ubuntu2004_User7RSA.length()}));

    // invalid user
    CHECK_THROWS_AS(
        std::make_shared<SFTPHost>(g_Ubuntu2004_Address, "Somebody", "Hello, World!", "", g_Ubuntu2004_Port),
        ErrorException);

    // invalid password
    CHECK_THROWS_AS(
        std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User1, "Hello, World!", "", g_Ubuntu2004_Port),
        ErrorException);

    // invalid key
    CHECK_THROWS_AS(std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User3, "", rsa, g_Ubuntu2004_Port),
                    ErrorException);

    // invalid password for a key
    CHECK_THROWS_AS(
        std::make_shared<SFTPHost>(g_Ubuntu2004_Address, g_Ubuntu2004_User7, "Blah", passwdrsa, g_Ubuntu2004_Port),
        ErrorException);
}
