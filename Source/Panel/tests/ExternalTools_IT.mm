// Copyright (C) 2023-2025 Michael Kazakov. Subject to GNU General Public License version 3.
// TODO: add a PanelIT target

#include "ExternalTools.h"
#include "Tests.h"
#include <VFS/Native.h>
#include <Utility/TemporaryFileStorageImpl.h>
#include <Base/mach_time.h>

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
    if( _pid < 0 )
        return true;
    const auto deadline = nc::base::machtime() + _deadline;
    while( true ) {
        int waitpid_status = 0;
        waitpid(_pid, &waitpid_status, WNOHANG | WUNTRACED);
        const bool dead = kill(_pid, 0) < 0;
        if( dead && errno == ESRCH )
            return true;
        if( nc::base::machtime() >= deadline )
            return false;
        std::this_thread::sleep_for(_poll_period);
    }
}

TEST_CASE(PREFIX "execute a detached console app")
{
    const TempTestDir dir;
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
    std::ofstream(basedir / "z z") << "aaa";

    auto &root = dir.directory;
    const VFSListingPtr listing =
        TestEnv().vfs_native->FetchDirectoryListing(root.c_str(), VFSFlags::F_NoDotDot).value();
    data::Model model;
    model.Load(listing, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    ExternalToolExecution::Context ctx;
    ctx.left_data = &model;
    ctx.right_data = &model;
    ctx.focus = ExternalToolExecution::PanelFocus::left;
    ctx.left_cursor_pos = 0;
    ctx.right_cursor_pos = 2;
    ctx.temp_storage = &temp_storage;
    ExternalTool et;
    et.m_ExecutablePath = basedir / "echopars";

    struct TC {
        std::string params;
        std::string expected;
    } const tcs[] = {
        {.params = basedir / "test.txt",                                                            //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\n"},                        //
        {.params = (basedir / "test.txt").string() + " Hello!",                                     //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\nHello!\n"},                //
        {.params = (basedir / "test.txt").string() + " Hello, World!",                              //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\nHello,\nWorld!\n"},        //
        {.params = (basedir / "test.txt").string() + " first second",                               //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\nfirst\nsecond\n"},         //
        {.params = (basedir / "test.txt").string() + R"( "first" "second")",                        //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\n\"first\"\n\"second\"\n"}, //
        {.params = (basedir / "test.txt").string() + " first\\ second",                             //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\nfirst second\n"},          //
        {.params = (basedir / "test.txt").string() + " %f",                                         //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\na.c\n"},                   //
        {.params = (basedir / "test.txt").string() + " %-f",                                        //
         .expected = "echopars\n" + (basedir / "test.txt").string() + "\nz z\n"},                   //
    };

    auto run = [&] {
        ExternalToolExecution ex{ctx, et};
        auto pid = ex.StartDetached();
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

TEST_CASE(PREFIX "execute a non-existing app")
{
    const TempTestDir dir;

    const VFSListingPtr listing = TestEnv().vfs_native->FetchDirectoryListing("/", VFSFlags::F_NoDotDot).value();
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

    {
        const ExternalToolExecution ex{ctx, et};
        auto pid = ex.StartDetachedFork();
        CHECK(pid.has_value() == false);
        CHECK(pid.error().empty() == false);
    }
    {
        ExternalToolExecution ex{ctx, et};
        auto pid = ex.StartDetachedUI();
        CHECK(pid.has_value() == false);
        CHECK(pid.error().empty() == false);
    }
}

TEST_CASE(PREFIX "execute a ui app", "[!mayfail]")
{
    const TempTestDir dir;
    const auto basedir = dir.directory;

    const auto minimal_src = "#include <Cocoa/Cocoa.h>                                                           \n" //
                             "FILE *f;                                                                           \n" //
                             "@interface D : NSObject <NSApplicationDelegate> @end                               \n" //
                             "@implementation D                                                                  \n" //
                             "- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls \n" //
                             "{ for(NSURL* url in urls) fprintf(f, \"U-%s\\n\", url.fileSystemRepresentation); } \n" //
                             "- (void)applicationDidFinishLaunching:(NSNotification *)notification               \n" //
                             "{ exit(0); }                                                                       \n" //
                             "@end                                                                               \n" //
                             "int main(int argc, const char * argv[]) {                                          \n" //
                             "    f = fopen(argv[1], \"wt\");                                                    \n" //
                             "    for(int i = 0; i < argc; ++i) fprintf(f, \"A-%s\\n\", argv[i]);                \n" //
                             "    NSApplication.sharedApplication.delegate = [D new];                            \n" //
                             "    [NSApplication.sharedApplication run]; }                                       \n";
    const auto plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>   \n" //
                       "<plist version=\"1.0\">                      \n" //
                       "<dict>                                       \n" //
                       "    <key>CFBundleInfoDictionaryVersion</key> \n" //
                       "    <string>6.0</string>                     \n" //
                       "    <key>CFBundlePackageType</key>           \n" //
                       "    <string>APPL</string>                    \n" //
                       "    <key>CFBundleExecutable</key>            \n" //
                       "    <string>minimal</string>                 \n" //
                       "    <key>CFBundleSignature</key>             \n" //
                       "    <string>\?\?\?\?</string>                \n" //
                       "</dict>                                      \n" //
                       "</plist>                                     \n";
    std::filesystem::create_directories(basedir / "minimal.app/Contents/MacOS");
    std::ofstream(basedir / "minimal.app/Contents/Info.plist") << plist;
    std::ofstream(basedir / "minimal.app/Contents/MacOS/minimal.mm") << minimal_src;
    REQUIRE(system(fmt::format("cd {} && clang++ -ObjC -o minimal -framework Cocoa minimal.mm",
                               basedir / "minimal.app/Contents/MacOS")
                       .c_str()) == 0);

    auto &root = dir.directory;
    const VFSListingPtr listing =
        TestEnv().vfs_native->FetchDirectoryListing(root.c_str(), VFSFlags::F_NoDotDot).value();
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
    et.m_ExecutablePath = basedir / "minimal.app";

    struct TC {
        std::string params;
        std::string expected;
        ExternalTool::GUIArgumentInterpretation interp =
            ExternalTool::GUIArgumentInterpretation::PassExistingPathsAsURLs;
    } const tcs[] = {
        // one argument
        {.params = basedir / "test.txt",
         .expected = fmt::format("A-{}\nA-{}\n",
                                 (basedir / "minimal.app/Contents/MacOS/minimal").string(),
                                 (basedir / "test.txt").string())},
        // two arguments
        {.params = (basedir / "test.txt").string() + " Hello!",
         .expected = fmt::format("A-{}\nA-{}\nA-Hello!\n",
                                 (basedir / "minimal.app/Contents/MacOS/minimal").string(),
                                 (basedir / "test.txt").string())},
        // one argument and an url
        {.params = basedir / "test.txt /bin",
         .expected = fmt::format("A-{}\nA-{}\nU-/bin\n",
                                 (basedir / "minimal.app/Contents/MacOS/minimal").string(),
                                 (basedir / "test.txt").string())},
        // one argument and two urls
        {.params = basedir / "test.txt /bin /System",
         .expected = fmt::format("A-{}\nA-{}\nU-/bin\nU-/System\n",
                                 (basedir / "minimal.app/Contents/MacOS/minimal").string(),
                                 (basedir / "test.txt").string())},
        // one argument and two path, but paths are interpreted as arguments
        {.params = basedir / "test.txt /bin /System",
         .expected = fmt::format("A-{}\nA-{}\nA-/bin\nA-/System\n",
                                 (basedir / "minimal.app/Contents/MacOS/minimal").string(),
                                 (basedir / "test.txt").string()),
         .interp = ExternalTool::GUIArgumentInterpretation::PassAllAsArguments},
    };

    auto run = [&] {
        ExternalToolExecution ex{ctx, et};
        auto pid = ex.StartDetachedUI();
        REQUIRE(pid); // <-- Flaky!
        REQUIRE(WaitForChildProcess(*pid, 5s, 1ms));
    };

    for( const TC &tc : tcs ) {
        et.m_Parameters = tc.params;
        et.m_GUIArgumentInterpretation = tc.interp;
        run();
        std::ifstream file(basedir / "test.txt");
        REQUIRE(!file.fail());
        CHECK(std::string{(std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>()} == tc.expected);
        std::filesystem::remove(basedir / "test.txt");
    }
}
