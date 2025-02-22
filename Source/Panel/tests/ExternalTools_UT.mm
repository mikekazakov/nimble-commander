// Copyright (C) 2022-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalTools.h"
#include "Tests.h"
#include <VFS/Native.h>
#include <Config/ConfigImpl.h>
#include <Config/NonPersistentOverwritesStorage.h>
#include <Utility/TemporaryFileStorageImpl.h>
#include <string>
#include <fstream>
#include <streambuf>

#define PREFIX "ExternalTools "

using namespace nc;
using namespace nc::panel;

using Params = ExternalToolsParameters;
using Step = ExternalToolsParameters::Step;
using Location = ExternalToolsParameters::Location;
using SelectedItems = ExternalToolsParameters::SelectedItems;
using FI = ExternalToolsParameters::FileInfo;

static void touch(const std::filesystem::path &p)
{
    const int fd = open(p.c_str(), O_RDWR | O_CREAT | S_IRUSR | S_IWUSR);
    CHECK(fd > 0);
    close(fd);
}

TEST_CASE(PREFIX "Parsing empty produces no parameters")
{
    const auto params = ExternalToolsParametersParser::Parse("").value();
    CHECK(params.StepsAmount() == 0);
    CHECK(params.Steps().empty());
}

TEST_CASE(PREFIX "Parsing - errors")
{
    const char *invalids[] = {
        "%",   // non-terminated percent command
        "%\"", // non-terminated enter value
        "%\"?" // enter value with broken quotes
    };
    for( auto invalid : invalids ) {
        INFO(invalid);
        auto r = ExternalToolsParametersParser::Parse(invalid);
        CHECK(!r);
        CHECK(!r.error().empty());
    }
}

TEST_CASE(PREFIX "Parsing - text")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("blah").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "blah");
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("foo\\ blah\\ !").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "foo blah !");
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%%").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "%");
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("foo%%bar").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "foo%bar");
    }
}

TEST_CASE(PREFIX "Parsing - dialog value")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%?").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::EnterValue, 0});
        REQUIRE(p.GetEnterValue(0).name.empty());
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%\"hello\"?").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::EnterValue, 0});
        REQUIRE(p.GetEnterValue(0).name == "hello");
    }
}

TEST_CASE(PREFIX "Parsing - directory path")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%-r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %-r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - current path")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%-p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %-p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%-f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %-f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename without extension")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%-n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %-n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename extension")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%-e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser::Parse("%- %-e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - selected filenames")
{
    {
        const auto p = ExternalToolsParametersParser::Parse("%F").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::SelectedItems, 0});
        REQUIRE(p.GetSelectedItems(0) == SelectedItems{Location::Source, FI::Filename, 0, true});
    }
}

TEST_CASE(PREFIX "ExternalToolExecution - generation of simple arguments")
{
    const TempTestDir dir;
    auto &root = dir.directory;
    std::filesystem::create_directory(root / "dir1");
    touch(root / "dir1/file1.txt");
    touch(root / "dir1/file2.txt");
    std::filesystem::create_directory(root / "dir2");
    touch(root / "dir2/file3.txt");
    touch(root / "dir2/file4.txt");

    const VFSListingPtr l1 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), VFSFlags::F_NoDotDot).value();
    const VFSListingPtr l2 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), VFSFlags::F_NoDotDot).value();
    data::Model left;
    data::Model right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    struct TC {
        int left_cursor;
        int right_cursor;
        std::string params_string;
        std::vector<std::string> args_expected;
    } const tcs[] = {
        {.left_cursor = 0, .right_cursor = 0, .params_string = "", .args_expected = {}},                            //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo", .args_expected = {"foo"}},                    //
        {.left_cursor = 0, .right_cursor = 0, .params_string = " foo", .args_expected = {"foo"}},                   //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "\\ foo", .args_expected = {" foo"}},                //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo ", .args_expected = {"foo"}},                   //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo\\ ", .args_expected = {"foo "}},                //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "\\ foo\\ ", .args_expected = {" foo "}},            //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo bar", .args_expected = {"foo", "bar"}},         //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "   foo   bar   ", .args_expected = {"foo", "bar"}}, //
        {.left_cursor = 0,
         .right_cursor = 0,
         .params_string = "foo bar baz",
         .args_expected = {"foo", "bar", "baz"}},                                                                     //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo\\ bar", .args_expected = {"foo bar"}},            //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%%", .args_expected = {"%"}},                         //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%%arg1 %%arg2", .args_expected = {"%arg1", "%arg2"}}, //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%%arg1%%arg2", .args_expected = {"%arg1%arg2"}},      //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo%f", .args_expected = {"foofile3.txt"}},           //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo %f", .args_expected = {"foo", "file3.txt"}},      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo  %f", .args_expected = {"foo", "file3.txt"}},     //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "foo%fbar", .args_expected = {"foofile3.txtbar"}},     //
        {.left_cursor = 0,
         .right_cursor = 0,
         .params_string = "foo %f bar",
         .args_expected = {"foo", "file3.txt", "bar"}}, //
        {.left_cursor = 0,
         .right_cursor = 0,
         .params_string = "  foo  %f  bar  ",
         .args_expected = {"foo", "file3.txt", "bar"}},                                                             //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%f,%-f", .args_expected = {"file3.txt,file1.txt"}}, //
        {.left_cursor = 0,
         .right_cursor = 0,
         .params_string = "%f %-f",
         .args_expected = {"file3.txt", "file1.txt"}}, //
        {.left_cursor = 0,
         .right_cursor = 0,
         .params_string = "%2T %f %-f",
         .args_expected = {"file3.txt", "file1.txt"}}, //
        {.left_cursor = 0,
         .right_cursor = 0,
         .params_string = "%2T %-f %f",
         .args_expected = {"file1.txt", "file3.txt"}},                                                                //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%1T %f %-f", .args_expected = {"file3.txt"}},         //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%1T %-f %f", .args_expected = {"file1.txt"}},         //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%f", .args_expected = {"file3.txt"}},                 //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%f", .args_expected = {"file4.txt"}},                 //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-f", .args_expected = {"file1.txt"}},                //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-f", .args_expected = {"file2.txt"}},                //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %f", .args_expected = {"file1.txt"}},              //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %f", .args_expected = {"file2.txt"}},              //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-f", .args_expected = {"file3.txt"}},             //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-f", .args_expected = {"file4.txt"}},             //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%n", .args_expected = {"file3"}},                     //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%n", .args_expected = {"file4"}},                     //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-n", .args_expected = {"file1"}},                    //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-n", .args_expected = {"file2"}},                    //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %n", .args_expected = {"file1"}},                  //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %n", .args_expected = {"file2"}},                  //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-n", .args_expected = {"file3"}},                 //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-n", .args_expected = {"file4"}},                 //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%e", .args_expected = {"txt"}},                       //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%e", .args_expected = {"txt"}},                       //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-e", .args_expected = {"txt"}},                      //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-e", .args_expected = {"txt"}},                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %e", .args_expected = {"txt"}},                    //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %e", .args_expected = {"txt"}},                    //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-e", .args_expected = {"txt"}},                   //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-e", .args_expected = {"txt"}},                   //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%p", .args_expected = {root / "dir2/file3.txt"}},     //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%p", .args_expected = {root / "dir2/file4.txt"}},     //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-p", .args_expected = {root / "dir1/file1.txt"}},    //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-p", .args_expected = {root / "dir1/file2.txt"}},    //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %p", .args_expected = {root / "dir1/file1.txt"}},  //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %p", .args_expected = {root / "dir1/file2.txt"}},  //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-p", .args_expected = {root / "dir2/file3.txt"}}, //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-p", .args_expected = {root / "dir2/file4.txt"}}, //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%r", .args_expected = {root / "dir2"}},               //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%r", .args_expected = {root / "dir2"}},               //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-r", .args_expected = {root / "dir1"}},              //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-r", .args_expected = {root / "dir1"}},              //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %r", .args_expected = {root / "dir1"}},            //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %r", .args_expected = {root / "dir1"}},            //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-r", .args_expected = {root / "dir2"}},           //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-r", .args_expected = {root / "dir2"}},           //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%F", .args_expected = {"file3.txt"}},                 //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%F", .args_expected = {"file4.txt"}},                 //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-F", .args_expected = {"file1.txt"}},                //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-F", .args_expected = {"file2.txt"}},                //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %F", .args_expected = {"file1.txt"}},              //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %F", .args_expected = {"file2.txt"}},              //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-F", .args_expected = {"file3.txt"}},             //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-F", .args_expected = {"file4.txt"}},             //
                                                                                                                      //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%P", .args_expected = {root / "dir2/file3.txt"}},     //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%P", .args_expected = {root / "dir2/file4.txt"}},     //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%-P", .args_expected = {root / "dir1/file1.txt"}},    //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%-P", .args_expected = {root / "dir1/file2.txt"}},    //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %P", .args_expected = {root / "dir1/file1.txt"}},  //
        {.left_cursor = 1, .right_cursor = 0, .params_string = "%- %P", .args_expected = {root / "dir1/file2.txt"}},  //
        {.left_cursor = 0, .right_cursor = 0, .params_string = "%- %-P", .args_expected = {root / "dir2/file3.txt"}}, //
        {.left_cursor = 0, .right_cursor = 1, .params_string = "%- %-P", .args_expected = {root / "dir2/file4.txt"}}, //
    };

    for( const auto &tc : tcs ) {
        INFO(tc.params_string);
        ExternalToolExecution::Context ctx;
        ctx.left_data = &left;
        ctx.right_data = &right;
        ctx.focus = ExternalToolExecution::PanelFocus::right;
        ctx.left_cursor_pos = tc.left_cursor;
        ctx.right_cursor_pos = tc.right_cursor;
        ctx.temp_storage = &temp_storage;

        ExternalTool et;
        et.m_Parameters = tc.params_string;

        const ExternalToolExecution ex{ctx, et};
        auto args = ex.BuildArguments();

        CHECK(args == tc.args_expected);
    }
}

TEST_CASE(PREFIX "ExternalToolExecution - generation of lists as parameters")
{
    const TempTestDir dir;
    auto &root = dir.directory;
    std::filesystem::create_directory(root / "dir1");
    touch(root / "dir1/file1.txt");
    touch(root / "dir1/file2.txt");
    touch(root / "dir1/file3.txt");
    std::filesystem::create_directory(root / "dir2");
    touch(root / "dir2/file4.txt");
    touch(root / "dir2/file5.txt");
    touch(root / "dir2/file6.txt");

    const VFSListingPtr l1 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), VFSFlags::F_NoDotDot).value();
    const VFSListingPtr l2 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), VFSFlags::F_NoDotDot).value();
    data::Model left;
    data::Model right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    struct TC {
        std::vector<int> left_selection;
        std::vector<int> right_selection;
        std::string params_string;
        std::vector<std::string> args_expected;
    } const tcs[] = {
        {.left_selection = {}, .right_selection = {}, .params_string = "%F", .args_expected = {"file1.txt"}},    //
        {.left_selection = {}, .right_selection = {}, .params_string = "%100F", .args_expected = {"file1.txt"}}, //
        {.left_selection = {}, .right_selection = {}, .params_string = "%- %F", .args_expected = {"file1.txt"}}, //
        {.left_selection = {0}, .right_selection = {}, .params_string = "%F", .args_expected = {"file1.txt"}},   //
        {.left_selection = {1}, .right_selection = {}, .params_string = "%F", .args_expected = {"file2.txt"}},   //
        {.left_selection = {2}, .right_selection = {}, .params_string = "%F", .args_expected = {"file3.txt"}},   //
        {.left_selection = {0, 1},
         .right_selection = {},
         .params_string = "%F",
         .args_expected = {"file1.txt", "file2.txt"}},                                                             //
        {.left_selection = {0, 1}, .right_selection = {}, .params_string = "%1F", .args_expected = {"file1.txt"}}, //
        {.left_selection = {0, 1},
         .right_selection = {},
         .params_string = "%2F",
         .args_expected = {"file1.txt", "file2.txt"}}, //
        {.left_selection = {0, 1},
         .right_selection = {},
         .params_string = "%3F",
         .args_expected = {"file1.txt", "file2.txt"}}, //
        {.left_selection = {1, 2},
         .right_selection = {},
         .params_string = "%F",
         .args_expected = {"file2.txt", "file3.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt"}},                                                   //
        {.left_selection = {0, 1, 2}, .right_selection = {}, .params_string = "%1F", .args_expected = {"file1.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%1T %F",
         .args_expected = {"file1.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%2F",
         .args_expected = {"file1.txt", "file2.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%2T %F",
         .args_expected = {"file1.txt", "file2.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%3F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%3T %F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt"}},                                               //
        {.left_selection = {}, .right_selection = {}, .params_string = "%-F", .args_expected = {"file4.txt"}},    //
        {.left_selection = {}, .right_selection = {}, .params_string = "%- %-F", .args_expected = {"file4.txt"}}, //
        {.left_selection = {}, .right_selection = {0}, .params_string = "%-F", .args_expected = {"file4.txt"}},   //
        {.left_selection = {}, .right_selection = {1}, .params_string = "%-F", .args_expected = {"file5.txt"}},   //
        {.left_selection = {}, .right_selection = {2}, .params_string = "%-F", .args_expected = {"file6.txt"}},   //
        {.left_selection = {},
         .right_selection = {0, 1},
         .params_string = "%-F",
         .args_expected = {"file4.txt", "file5.txt"}}, //
        {.left_selection = {},
         .right_selection = {1, 2},
         .params_string = "%-F",
         .args_expected = {"file5.txt", "file6.txt"}}, //
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%-F",
         .args_expected = {"file4.txt", "file5.txt", "file6.txt"}}, //
        {.left_selection = {},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file1.txt"}}, //
        {.left_selection = {},
         .right_selection = {},
         .params_string = "%- %P",
         .args_expected = {root / "dir1/file1.txt"}}, //
        {.left_selection = {0},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file1.txt"}}, //
        {.left_selection = {1},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file2.txt"}}, //
        {.left_selection = {2},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file3.txt"}}, //
        {.left_selection = {0, 1},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file1.txt", root / "dir1/file2.txt"}}, //
        {.left_selection = {1, 2},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file2.txt", root / "dir1/file3.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%P",
         .args_expected = {root / "dir1/file1.txt", root / "dir1/file2.txt", root / "dir1/file3.txt"}}, //
        {.left_selection = {},
         .right_selection = {},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file4.txt"}}, //
        {.left_selection = {},
         .right_selection = {},
         .params_string = "%- %-P",
         .args_expected = {root / "dir2/file4.txt"}}, //
        {.left_selection = {},
         .right_selection = {0},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file4.txt"}}, //
        {.left_selection = {},
         .right_selection = {1},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file5.txt"}}, //
        {.left_selection = {},
         .right_selection = {2},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file6.txt"}}, //
        {.left_selection = {},
         .right_selection = {0, 1},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file4.txt", root / "dir2/file5.txt"}}, //
        {.left_selection = {},
         .right_selection = {1, 2},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file5.txt", root / "dir2/file6.txt"}}, //
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%-P",
         .args_expected = {root / "dir2/file4.txt", root / "dir2/file5.txt", root / "dir2/file6.txt"}}, //
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%1T %F %-F",
         .args_expected = {"file1.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%2T %F %-F",
         .args_expected = {"file1.txt", "file2.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%3T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%4T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%5T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%6T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%7T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%0T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {.left_selection = {0, 1, 2},
         .right_selection = {0, 1, 2},
         .params_string = "%100T %F %-F",
         .args_expected = {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
    };
    for( const auto &tc : tcs ) {
        left.CustomFlagsSelectSorted(std::vector<bool>(left.SortedEntriesCount(), false));
        for( auto idx : tc.left_selection )
            left.CustomFlagsSelectSorted(idx, true);
        right.CustomFlagsSelectSorted(std::vector<bool>(right.SortedEntriesCount(), false));
        for( auto idx : tc.right_selection )
            right.CustomFlagsSelectSorted(idx, true);

        INFO(tc.params_string);
        ExternalToolExecution::Context ctx;
        ctx.left_data = &left;
        ctx.right_data = &right;
        ctx.focus = ExternalToolExecution::PanelFocus::left;
        ctx.left_cursor_pos = 0;
        ctx.right_cursor_pos = 0;
        ctx.temp_storage = &temp_storage;

        ExternalTool et;
        et.m_Parameters = tc.params_string;

        const ExternalToolExecution ex{ctx, et};
        auto args = ex.BuildArguments();

        CHECK(args == tc.args_expected);
    }
}

TEST_CASE(PREFIX "ExternalToolExecution - generation of lists as file")
{
    const TempTestDir dir;
    auto &root = dir.directory;
    std::filesystem::create_directory(root / "dir1");
    touch(root / "dir1/file1.txt");
    touch(root / "dir1/file2.txt");
    touch(root / "dir1/file3.txt");
    std::filesystem::create_directory(root / "dir2");
    touch(root / "dir2/file4.txt");
    touch(root / "dir2/file5.txt");
    touch(root / "dir2/file6.txt");

    const VFSListingPtr l1 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), VFSFlags::F_NoDotDot).value();
    const VFSListingPtr l2 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), VFSFlags::F_NoDotDot).value();
    data::Model left;
    data::Model right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    const std::string f1 = root / "dir1/file1.txt";
    const std::string f2 = root / "dir1/file2.txt";
    const std::string f3 = root / "dir1/file3.txt";
    const std::string f4 = root / "dir2/file4.txt";
    const std::string f5 = root / "dir2/file5.txt";
    const std::string f6 = root / "dir2/file6.txt";

    struct TC {
        std::vector<int> left_selection;
        std::vector<int> right_selection;
        std::string params_string;
        std::string contents_expected;
    } const tcs[] = {
        {.left_selection = {}, .right_selection = {}, .params_string = "%LF", .contents_expected = "file4.txt"},
        {.left_selection = {}, .right_selection = {}, .params_string = "%-LF", .contents_expected = "file1.txt"},
        {.left_selection = {}, .right_selection = {0}, .params_string = "%LF", .contents_expected = "file4.txt"},
        {.left_selection = {}, .right_selection = {1}, .params_string = "%LF", .contents_expected = "file5.txt"},
        {.left_selection = {}, .right_selection = {2}, .params_string = "%LF", .contents_expected = "file6.txt"},
        {.left_selection = {0}, .right_selection = {}, .params_string = "%-LF", .contents_expected = "file1.txt"},
        {.left_selection = {1}, .right_selection = {}, .params_string = "%-LF", .contents_expected = "file2.txt"},
        {.left_selection = {2}, .right_selection = {}, .params_string = "%-LF", .contents_expected = "file3.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%LF",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {},
         .right_selection = {0, 1},
         .params_string = "%LF",
         .contents_expected = "file4.txt\nfile5.txt"},
        {.left_selection = {},
         .right_selection = {1, 2},
         .params_string = "%LF",
         .contents_expected = "file5.txt\nfile6.txt"},
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%-LF",
         .contents_expected = "file1.txt\nfile2.txt\nfile3.txt"},
        {.left_selection = {0, 1},
         .right_selection = {},
         .params_string = "%-LF",
         .contents_expected = "file1.txt\nfile2.txt"},
        {.left_selection = {1, 2},
         .right_selection = {},
         .params_string = "%-LF",
         .contents_expected = "file2.txt\nfile3.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L100F",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L3F",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L2F",
         .contents_expected = "file4.txt\nfile5.txt"},
        {.left_selection = {}, .right_selection = {0, 1, 2}, .params_string = "%L1F", .contents_expected = "file4.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L0F",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%100T %LF",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%3T %LF",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%2T %LF",
         .contents_expected = "file4.txt\nfile5.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%1T %LF",
         .contents_expected = "file4.txt"},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%0T %LF",
         .contents_expected = "file4.txt\nfile5.txt\nfile6.txt"},
        {.left_selection = {}, .right_selection = {}, .params_string = "%LP", .contents_expected = f4},
        {.left_selection = {}, .right_selection = {}, .params_string = "%-LP", .contents_expected = f1},
        {.left_selection = {}, .right_selection = {0}, .params_string = "%LP", .contents_expected = f4},
        {.left_selection = {}, .right_selection = {1}, .params_string = "%LP", .contents_expected = f5},
        {.left_selection = {}, .right_selection = {2}, .params_string = "%LP", .contents_expected = f6},
        {.left_selection = {0}, .right_selection = {}, .params_string = "%-LP", .contents_expected = f1},
        {.left_selection = {1}, .right_selection = {}, .params_string = "%-LP", .contents_expected = f2},
        {.left_selection = {2}, .right_selection = {}, .params_string = "%-LP", .contents_expected = f3},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%LP",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
        {.left_selection = {}, .right_selection = {0, 1}, .params_string = "%LP", .contents_expected = f4 + "\n" + f5},
        {.left_selection = {}, .right_selection = {1, 2}, .params_string = "%LP", .contents_expected = f5 + "\n" + f6},
        {.left_selection = {0, 1, 2},
         .right_selection = {},
         .params_string = "%-LP",
         .contents_expected = f1 + "\n" + f2 + "\n" + f3},
        {.left_selection = {0, 1}, .right_selection = {}, .params_string = "%-LP", .contents_expected = f1 + "\n" + f2},
        {.left_selection = {1, 2}, .right_selection = {}, .params_string = "%-LP", .contents_expected = f2 + "\n" + f3},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L100P",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L3P",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L2P",
         .contents_expected = f4 + "\n" + f5},
        {.left_selection = {}, .right_selection = {0, 1, 2}, .params_string = "%L1P", .contents_expected = f4},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%L0P",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%100T %LP",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%3T %LP",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%2T %LP",
         .contents_expected = f4 + "\n" + f5},
        {.left_selection = {}, .right_selection = {0, 1, 2}, .params_string = "%1T %LP", .contents_expected = f4},
        {.left_selection = {},
         .right_selection = {0, 1, 2},
         .params_string = "%0T %LP",
         .contents_expected = f4 + "\n" + f5 + "\n" + f6},
    };

    for( const auto &tc : tcs ) {
        left.CustomFlagsSelectSorted(std::vector<bool>(left.SortedEntriesCount(), false));
        for( auto idx : tc.left_selection )
            left.CustomFlagsSelectSorted(idx, true);
        right.CustomFlagsSelectSorted(std::vector<bool>(right.SortedEntriesCount(), false));
        for( auto idx : tc.right_selection )
            right.CustomFlagsSelectSorted(idx, true);

        INFO(tc.params_string);
        ExternalToolExecution::Context ctx;
        ctx.left_data = &left;
        ctx.right_data = &right;
        ctx.focus = ExternalToolExecution::PanelFocus::right;
        ctx.left_cursor_pos = 0;
        ctx.right_cursor_pos = 0;
        ctx.temp_storage = &temp_storage;

        ExternalTool et;
        et.m_Parameters = tc.params_string;

        const ExternalToolExecution ex{ctx, et};
        auto args = ex.BuildArguments();
        REQUIRE(args.size() == 1);

        std::ifstream file(args[0]);
        REQUIRE(!file.fail());
        const std::string contents((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
        CHECK(contents == tc.contents_expected);
    }
}

TEST_CASE(PREFIX "ExternalToolExecution - user-input values")
{
    const TempTestDir dir;
    auto &root = dir.directory;
    std::filesystem::create_directory(root / "dir1");
    touch(root / "dir1/file1.txt");
    touch(root / "dir1/file2.txt");
    std::filesystem::create_directory(root / "dir2");
    touch(root / "dir2/file3.txt");
    touch(root / "dir2/file4.txt");

    const VFSListingPtr l1 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), VFSFlags::F_NoDotDot).value();
    const VFSListingPtr l2 =
        TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), VFSFlags::F_NoDotDot).value();
    data::Model left;
    data::Model right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");
    struct TC {
        std::vector<std::string> inputs;
        std::string params_string;
        std::vector<std::string> args_expected;
        std::vector<std::string> prompts_expected;
    } const tcs[] = {
        {.inputs = {"hello"}, .params_string = "%?", .args_expected = {"hello"}, .prompts_expected = {""}},
        {.inputs = {"hello"}, .params_string = "%?world", .args_expected = {"helloworld"}, .prompts_expected = {""}},
        {.inputs = {"hello"},
         .params_string = "%? world",
         .args_expected = {"hello", "world"},
         .prompts_expected = {""}},
        {.inputs = {"hello"},
         .params_string = "!!!%?world",
         .args_expected = {"!!!helloworld"},
         .prompts_expected = {""}},
        {.inputs = {"hello"},
         .params_string = "!!!%\"Salve!\"?world",
         .args_expected = {"!!!helloworld"},
         .prompts_expected = {"Salve!"}},
        {.inputs = {"hello", "world"},
         .params_string = "%? %?",
         .args_expected = {"hello", "world"},
         .prompts_expected = {"", ""}},
        {.inputs = {"hello", "world"},
         .params_string = "%?%?",
         .args_expected = {"helloworld"},
         .prompts_expected = {"", ""}},
        {.inputs = {"hello"},
         .params_string = "%? %f",
         .args_expected = {"hello", "file1.txt"},
         .prompts_expected = {""}},
        {.inputs = {"hello"}, .params_string = "%?%f", .args_expected = {"hellofile1.txt"}, .prompts_expected = {""}},
        {.inputs = {"hello"},
         .params_string = "%f%?%-f",
         .args_expected = {"file1.txthellofile3.txt"},
         .prompts_expected = {""}},
        {.inputs = {"hello"},
         .params_string = "%f %? %-f",
         .args_expected = {"file1.txt", "hello", "file3.txt"},
         .prompts_expected = {""}},
        {.inputs = {"hello"}, .params_string = "%\"%\"?", .args_expected = {"hello"}, .prompts_expected = {"%"}},
        {.inputs = {"hello"}, .params_string = "%\"%?\"?", .args_expected = {"hello"}, .prompts_expected = {"%?"}},
        {.inputs = {"hello"}, .params_string = "%\"%%\"?", .args_expected = {"hello"}, .prompts_expected = {"%"}},
        {.inputs = {"hello"}, .params_string = "%\"%%%%\"?", .args_expected = {"hello"}, .prompts_expected = {"%%"}},
        //        {{"hello"}, "%\"%%\\\"%%\"?", {"hello"}, {"%\"%"}}, // doesnt
        //        work now...
    };

    for( const auto &tc : tcs ) {
        INFO(tc.params_string);
        ExternalToolExecution::Context ctx;
        ctx.left_data = &left;
        ctx.right_data = &right;
        ctx.focus = ExternalToolExecution::PanelFocus::left;
        ctx.left_cursor_pos = 0;
        ctx.right_cursor_pos = 0;
        ctx.temp_storage = &temp_storage;

        ExternalTool et;
        et.m_Parameters = tc.params_string;

        ExternalToolExecution ex{ctx, et};
        CHECK(ex.RequiresUserInput());
        CHECK(ex.UserInputPrompts().size() == tc.inputs.size());
        ex.CommitUserInput(tc.inputs);

        auto args = ex.BuildArguments();
        CHECK(args == tc.args_expected);
    }
}

TEST_CASE(PREFIX "Storage refuses duplicate UUIDs")
{
    nc::config::ConfigImpl config{"{}", std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    ExternalToolsStorage stor("tools", config, ExternalToolsStorage::WriteChanges::Immediate);
    ExternalTool t;
    t.m_Title = "hi";
    t.m_UUID = nc::base::UUID::Generate();
    REQUIRE_NOTHROW(stor.InsertTool(t));
    REQUIRE_THROWS_AS(stor.InsertTool(t), std::invalid_argument);
}

TEST_CASE(PREFIX "Storage immediately writes back the invented UUIDs once the tools are loaded")
{
    const auto config_json = R"({
        "tools": [
            {
                "path": "/meow",
                "title": "Meow!"
            },
            {
                "path": "/woof",
                "title": "Woof!"
            }    
        ]
    })";
    nc::config::ConfigImpl config{"{}", std::make_shared<nc::config::NonPersistentOverwritesStorage>(config_json)};

    nc::base::UUID u1;
    nc::base::UUID u2;
    {
        const ExternalToolsStorage stor("tools", config, ExternalToolsStorage::WriteChanges::Immediate);
        REQUIRE(stor.GetAllTools().size() == 2);
        REQUIRE(stor.GetTool(0)->m_Title == "Meow!");
        REQUIRE(stor.GetTool(0)->m_ExecutablePath == "/meow");
        u1 = stor.GetTool(0)->m_UUID; // invented
        REQUIRE(stor.GetTool(1)->m_Title == "Woof!");
        REQUIRE(stor.GetTool(1)->m_ExecutablePath == "/woof");
        u2 = stor.GetTool(1)->m_UUID; // invented
    }

    {
        const ExternalToolsStorage stor("tools", config, ExternalToolsStorage::WriteChanges::Immediate);
        REQUIRE(stor.GetAllTools().size() == 2);
        REQUIRE(stor.GetTool(0)->m_Title == "Meow!");
        REQUIRE(stor.GetTool(0)->m_ExecutablePath == "/meow");
        REQUIRE(stor.GetTool(0)->m_UUID == u1); // stayed the same after reload
        REQUIRE(stor.GetTool(1)->m_Title == "Woof!");
        REQUIRE(stor.GetTool(1)->m_ExecutablePath == "/woof");
        REQUIRE(stor.GetTool(1)->m_UUID == u2); // stayed the same after reload
    }
}
