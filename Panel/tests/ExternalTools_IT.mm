// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
// TODO: add a PanelIT target

#include "ExternalTools.h"
#include "Tests.h"
#include <VFS/Native.h>
#include <Utility/TemporaryFileStorageImpl.h>
#include <Habanero/mach_time.h>

#include <string>
#include <fstream>
#include <streambuf>
#include <fmt/core.h>
#include <fmt/std.h>
#include <iostream>

#define PREFIX "ExternalTools "

using namespace nc;
using namespace nc::panel;
using namespace std::chrono_literals;

static bool WaitForChildProcess(int _pid, std::chrono::nanoseconds _deadline, std::chrono::nanoseconds _poll_period)
{
    const auto deadline = machtime() + _deadline;
    while( true ) {
        int waitpid_status = 0;
        waitpid(_pid, &waitpid_status, WNOHANG | WUNTRACED);
        const bool dead = kill(_pid, 0) < 0;
        if( dead && errno == ESRCH )
            return true;
        if( machtime() >= deadline )
            return false;
        std::this_thread::sleep_for(_poll_period);
    }
}

TEST_CASE(PREFIX "execute a detached console app")
{
    TempTestDir dir;
    const auto basedir = dir.directory;
    const auto echopars_src = "#include <stdio.h>                     \n"  //
                              "int main(int argc, char **argv) {      \n"  //
                              "   FILE* f = fopen(argv[1], \"w\");    \n"  //
                              "   for(int i=0; i<argc; ++i)           \n"  //
                              "       fprintf(f, \"%s\\n\", argv[i]); \n"  //
                              "   fclose(f);                          \n"  //
                              "}                                        "; //
    std::ofstream(basedir / "a.c") << echopars_src;
    REQUIRE(system(fmt::format("cd {} && clang a.c -o echopars", basedir).c_str()) == 0);

    auto &root = dir.directory;
    VFSListingPtr listing;
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing(root.c_str(), listing, VFSFlags::F_NoDotDot, {}) == 0);
    data::Model model;
    model.Load(listing, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    ExternalToolExecution::Context ctx;
    ctx.left_data = &model;
    ctx.right_data = &model;
    ctx.focus = ExternalToolExecution::PanelFocus::left;
    ctx.left_cursor_pos = 0;
    ctx.right_cursor_pos = 0;
    ctx.temp_storage = &temp_storage;
    ExternalTool et;
    et.m_ExecutablePath = basedir / "echopars";

    struct TC {
        std::string params;
        std::string expected;
    } tcs[] = {
        {basedir / "test.txt", "echopars\n" + (basedir / "test.txt").string() + "\n"},
        {(basedir / "test.txt").string() + " Hello!", "echopars\n" + (basedir / "test.txt").string() + "\nHello!\n"},
        {(basedir / "test.txt").string() + " Hello, World!",
         "echopars\n" + (basedir / "test.txt").string() + "\nHello,\nWorld!\n"},
        {(basedir / "test.txt").string() + " %f", "echopars\n" + (basedir / "test.txt").string() + "\na.c\n"},
    };

    auto run = [&] {
        ExternalToolExecution ex{ctx, et};
        auto pid = ex.startDetached();
        REQUIRE(pid);
        REQUIRE(WaitForChildProcess(*pid, 5s, 1ms));
    };

    for( const TC &tc : tcs ) {
        et.m_Parameters = tc.params;
        run();
        std::ifstream file(basedir / "test.txt");
        REQUIRE(!file.fail());
        CHECK(std::string{(std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>()} == tc.expected);
    }
}

TEST_CASE(PREFIX "execute a non-existing detached console app")
{
    TempTestDir dir;

    VFSListingPtr listing;
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing("/", listing, VFSFlags::F_NoDotDot, {}) == 0);
    data::Model model;
    model.Load(listing, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(dir.directory.native(), "temp");

    ExternalToolExecution::Context ctx;
    ctx.left_data = &model;
    ctx.right_data = &model;
    ctx.focus = ExternalToolExecution::PanelFocus::left;
    ctx.left_cursor_pos = 0;
    ctx.right_cursor_pos = 0;
    ctx.temp_storage = &temp_storage;
    
    ExternalTool et;
    et.m_ExecutablePath = "/i/do/no/exist/hi";
    
    ExternalToolExecution ex{ctx, et};
    auto pid = ex.startDetached();
    CHECK( pid.has_value() == false );
}
