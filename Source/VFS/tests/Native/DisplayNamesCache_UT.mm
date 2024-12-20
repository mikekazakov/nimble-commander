// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Tests.h"
#include "../TestEnv.h"
#include "../../source/Native/DisplayNamesCache.h" // TODO: reogranize the tests to avoid this

using DNC = nc::vfs::native::DisplayNamesCache;

#define PREFIX "nc::vfs::native::DisplayNamesCache "

TEST_CASE(PREFIX "Empty cache, erroring out the IO")
{
    struct IO : DNC::IO {
        NSString *next;

        NSString *DisplayNameAtPath(NSString * /*_path*/) override
        {
            if( !next ) {
                FAIL();
                abort();
            }
            return next;
        };
        int Stat(const char * /*_path*/, struct stat * /*_st*/) override
        {
            FAIL();
            abort();
        };
    } io;
    DNC dnc{io};

    // Probe once
    SECTION("Same path returned is treated as an error")
    {
        io.next = @"/my/dir";
    }
    SECTION("Empty string is treated as an error")
    {
        io.next = @"";
    }
    CHECK(dnc.DisplayName(0, 0, "/my/dir") == std::nullopt);

    // Shouldn't probe again
    io.next = nil;
    CHECK(dnc.DisplayName(0, 0, "/my/dir") == std::nullopt);
}

TEST_CASE(PREFIX "Different devices")
{
    struct IO : DNC::IO {
        NSString *next;
        NSString *DisplayNameAtPath(NSString * /*_path*/) override
        {
            if( !next ) {
                FAIL();
                abort();
            }
            return next;
        };
        int Stat(const char * /*_path*/, struct stat * /*_st*/) override
        {
            FAIL();
            abort();
        };
    } io;
    DNC dnc{io};

    // Check that the data is correctly probed
    io.next = @"Meow!";
    CHECK(dnc.DisplayName(0, 0, "/meow") == "Meow!");
    io.next = @"Woof!";
    CHECK(dnc.DisplayName(1, 0, "/woof") == "Woof!");
    io.next = @"Hiss!";
    CHECK(dnc.DisplayName(2, 0, "/hiss") == "Hiss!");

    // Check that the data is cached
    io.next = nil;
    CHECK(dnc.DisplayName(0, 0, "/meow") == "Meow!");
    CHECK(dnc.DisplayName(1, 0, "/woof") == "Woof!");
    CHECK(dnc.DisplayName(2, 0, "/hiss") == "Hiss!");
}

TEST_CASE(PREFIX "Different inodes")
{
    struct IO : DNC::IO {
        NSString *next;
        NSString *DisplayNameAtPath(NSString * /*_path*/) override
        {
            if( !next ) {
                FAIL();
                abort();
            }
            return next;
        };
        int Stat(const char * /*_path*/, struct stat * /*_st*/) override
        {
            FAIL();
            abort();
        };
    } io;
    DNC dnc{io};

    // Check that the data is correctly probed
    io.next = @"Meow!";
    CHECK(dnc.DisplayName(0, 0, "/meow") == "Meow!");
    io.next = @"Woof!";
    CHECK(dnc.DisplayName(0, 1, "/woof") == "Woof!");
    io.next = @"Hiss!";
    CHECK(dnc.DisplayName(0, 2, "/hiss") == "Hiss!");

    // Check that the data is cached
    io.next = nil;
    CHECK(dnc.DisplayName(0, 0, "/meow") == "Meow!");
    CHECK(dnc.DisplayName(0, 1, "/woof") == "Woof!");
    CHECK(dnc.DisplayName(0, 2, "/hiss") == "Hiss!");
}

TEST_CASE(PREFIX "Per-inode collision")
{
    struct IO : DNC::IO {
        NSString *next;
        NSString *DisplayNameAtPath(NSString * /*_path*/) override
        {
            if( !next ) {
                FAIL();
                abort();
            }
            return next;
        };
        int Stat(const char * /*_path*/, struct stat * /*_st*/) override
        {
            FAIL();
            abort();
        };
    } io;
    DNC dnc{io};

    // Check that the data is correctly probed
    io.next = @"Meow!";
    CHECK(dnc.DisplayName(0, 0, "/meow") == "Meow!");
    io.next = @"Woof!";
    CHECK(dnc.DisplayName(0, 0, "/woof") == "Woof!");
    io.next = @"Hiss!";
    CHECK(dnc.DisplayName(0, 0, "/hiss") == "Hiss!");

    // Check that the data is cached
    io.next = nil;
    CHECK(dnc.DisplayName(0, 0, "/meow") == "Meow!");
    CHECK(dnc.DisplayName(0, 0, "/woof") == "Woof!");
    CHECK(dnc.DisplayName(0, 0, "/hiss") == "Hiss!");
}
