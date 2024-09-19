// Copyright (C) 2022-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalTools.h"
#include "Tests.h"
#include <VFS/Native.h>
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
    const auto params = ExternalToolsParametersParser{}.Parse("").value();
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
        auto r = ExternalToolsParametersParser{}.Parse(invalid);
        CHECK(!r);
        CHECK(!r.error().empty());
    }
}

TEST_CASE(PREFIX "Parsing - text")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("blah").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "blah");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("foo\\ blah\\ !").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "foo blah !");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%%").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "%");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("foo%%bar").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "foo%bar");
    }
}

TEST_CASE(PREFIX "Parsing - dialog value")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%?").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::EnterValue, 0});
        REQUIRE(p.GetEnterValue(0).name == "");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%\"hello\"?").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::EnterValue, 0});
        REQUIRE(p.GetEnterValue(0).name == "hello");
    }
}

TEST_CASE(PREFIX "Parsing - directory path")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %-r").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - current path")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %-p").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %-f").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename without extension")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %-n").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename extension")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%- %-e").value();
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - selected filenames")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%F").value();
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

    VFSListingPtr l1, l2;
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), l1, VFSFlags::F_NoDotDot, {}) == 0);
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), l2, VFSFlags::F_NoDotDot, {}) == 0);
    data::Model left, right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    struct TC {
        int left_cursor;
        int right_cursor;
        std::string params_string;
        std::vector<std::string> args_expected;
    } const tcs[] = {
        {0, 0, "", {}},                                          //
        {0, 0, "foo", {"foo"}},                                  //
        {0, 0, " foo", {"foo"}},                                 //
        {0, 0, "\\ foo", {" foo"}},                              //
        {0, 0, "foo ", {"foo"}},                                 //
        {0, 0, "foo\\ ", {"foo "}},                              //
        {0, 0, "\\ foo\\ ", {" foo "}},                          //
        {0, 0, "foo bar", {"foo", "bar"}},                       //
        {0, 0, "   foo   bar   ", {"foo", "bar"}},               //
        {0, 0, "foo bar baz", {"foo", "bar", "baz"}},            //
        {0, 0, "foo\\ bar", {"foo bar"}},                        //
        {0, 0, "%%", {"%"}},                                     //
        {0, 0, "%%arg1 %%arg2", {"%arg1", "%arg2"}},             //
        {0, 0, "%%arg1%%arg2", {"%arg1%arg2"}},                  //
                                                                 //
        {0, 0, "foo%f", {"foofile3.txt"}},                       //
        {0, 0, "foo %f", {"foo", "file3.txt"}},                  //
        {0, 0, "foo  %f", {"foo", "file3.txt"}},                 //
        {0, 0, "foo%fbar", {"foofile3.txtbar"}},                 //
        {0, 0, "foo %f bar", {"foo", "file3.txt", "bar"}},       //
        {0, 0, "  foo  %f  bar  ", {"foo", "file3.txt", "bar"}}, //
        {0, 0, "%f,%-f", {"file3.txt,file1.txt"}},               //
        {0, 0, "%f %-f", {"file3.txt", "file1.txt"}},            //
        {0, 0, "%2T %f %-f", {"file3.txt", "file1.txt"}},        //
        {0, 0, "%2T %-f %f", {"file1.txt", "file3.txt"}},        //
        {0, 0, "%1T %f %-f", {"file3.txt"}},                     //
        {0, 0, "%1T %-f %f", {"file1.txt"}},                     //
                                                                 //
        {0, 0, "%f", {"file3.txt"}},                             //
        {0, 1, "%f", {"file4.txt"}},                             //
        {0, 0, "%-f", {"file1.txt"}},                            //
        {1, 0, "%-f", {"file2.txt"}},                            //
        {0, 0, "%- %f", {"file1.txt"}},                          //
        {1, 0, "%- %f", {"file2.txt"}},                          //
        {0, 0, "%- %-f", {"file3.txt"}},                         //
        {0, 1, "%- %-f", {"file4.txt"}},                         //
                                                                 //
        {0, 0, "%n", {"file3"}},                                 //
        {0, 1, "%n", {"file4"}},                                 //
        {0, 0, "%-n", {"file1"}},                                //
        {1, 0, "%-n", {"file2"}},                                //
        {0, 0, "%- %n", {"file1"}},                              //
        {1, 0, "%- %n", {"file2"}},                              //
        {0, 0, "%- %-n", {"file3"}},                             //
        {0, 1, "%- %-n", {"file4"}},                             //
                                                                 //
        {0, 0, "%e", {"txt"}},                                   //
        {0, 1, "%e", {"txt"}},                                   //
        {0, 0, "%-e", {"txt"}},                                  //
        {1, 0, "%-e", {"txt"}},                                  //
        {0, 0, "%- %e", {"txt"}},                                //
        {1, 0, "%- %e", {"txt"}},                                //
        {0, 0, "%- %-e", {"txt"}},                               //
        {0, 1, "%- %-e", {"txt"}},                               //
                                                                 //
        {0, 0, "%p", {root / "dir2/file3.txt"}},                 //
        {0, 1, "%p", {root / "dir2/file4.txt"}},                 //
        {0, 0, "%-p", {root / "dir1/file1.txt"}},                //
        {1, 0, "%-p", {root / "dir1/file2.txt"}},                //
        {0, 0, "%- %p", {root / "dir1/file1.txt"}},              //
        {1, 0, "%- %p", {root / "dir1/file2.txt"}},              //
        {0, 0, "%- %-p", {root / "dir2/file3.txt"}},             //
        {0, 1, "%- %-p", {root / "dir2/file4.txt"}},             //
                                                                 //
        {0, 0, "%r", {root / "dir2"}},                           //
        {0, 1, "%r", {root / "dir2"}},                           //
        {0, 0, "%-r", {root / "dir1"}},                          //
        {1, 0, "%-r", {root / "dir1"}},                          //
        {0, 0, "%- %r", {root / "dir1"}},                        //
        {1, 0, "%- %r", {root / "dir1"}},                        //
        {0, 0, "%- %-r", {root / "dir2"}},                       //
        {0, 1, "%- %-r", {root / "dir2"}},                       //
                                                                 //
        {0, 0, "%F", {"file3.txt"}},                             //
        {0, 1, "%F", {"file4.txt"}},                             //
        {0, 0, "%-F", {"file1.txt"}},                            //
        {1, 0, "%-F", {"file2.txt"}},                            //
        {0, 0, "%- %F", {"file1.txt"}},                          //
        {1, 0, "%- %F", {"file2.txt"}},                          //
        {0, 0, "%- %-F", {"file3.txt"}},                         //
        {0, 1, "%- %-F", {"file4.txt"}},                         //
                                                                 //
        {0, 0, "%P", {root / "dir2/file3.txt"}},                 //
        {0, 1, "%P", {root / "dir2/file4.txt"}},                 //
        {0, 0, "%-P", {root / "dir1/file1.txt"}},                //
        {1, 0, "%-P", {root / "dir1/file2.txt"}},                //
        {0, 0, "%- %P", {root / "dir1/file1.txt"}},              //
        {1, 0, "%- %P", {root / "dir1/file2.txt"}},              //
        {0, 0, "%- %-P", {root / "dir2/file3.txt"}},             //
        {0, 1, "%- %-P", {root / "dir2/file4.txt"}},             //
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

    VFSListingPtr l1, l2;
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), l1, VFSFlags::F_NoDotDot, {}) == 0);
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), l2, VFSFlags::F_NoDotDot, {}) == 0);
    data::Model left, right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");

    struct TC {
        std::vector<int> left_selection;
        std::vector<int> right_selection;
        std::string params_string;
        std::vector<std::string> args_expected;
    } const tcs[] = {
        {{}, {}, "%F", {"file1.txt"}},                                                                       //
        {{}, {}, "%100F", {"file1.txt"}},                                                                    //
        {{}, {}, "%- %F", {"file1.txt"}},                                                                    //
        {{0}, {}, "%F", {"file1.txt"}},                                                                      //
        {{1}, {}, "%F", {"file2.txt"}},                                                                      //
        {{2}, {}, "%F", {"file3.txt"}},                                                                      //
        {{0, 1}, {}, "%F", {"file1.txt", "file2.txt"}},                                                      //
        {{0, 1}, {}, "%1F", {"file1.txt"}},                                                                  //
        {{0, 1}, {}, "%2F", {"file1.txt", "file2.txt"}},                                                     //
        {{0, 1}, {}, "%3F", {"file1.txt", "file2.txt"}},                                                     //
        {{1, 2}, {}, "%F", {"file2.txt", "file3.txt"}},                                                      //
        {{0, 1, 2}, {}, "%F", {"file1.txt", "file2.txt", "file3.txt"}},                                      //
        {{0, 1, 2}, {}, "%1F", {"file1.txt"}},                                                               //
        {{0, 1, 2}, {}, "%1T %F", {"file1.txt"}},                                                            //
        {{0, 1, 2}, {}, "%2F", {"file1.txt", "file2.txt"}},                                                  //
        {{0, 1, 2}, {}, "%2T %F", {"file1.txt", "file2.txt"}},                                               //
        {{0, 1, 2}, {}, "%3F", {"file1.txt", "file2.txt", "file3.txt"}},                                     //
        {{0, 1, 2}, {}, "%3T %F", {"file1.txt", "file2.txt", "file3.txt"}},                                  //
        {{}, {}, "%-F", {"file4.txt"}},                                                                      //
        {{}, {}, "%- %-F", {"file4.txt"}},                                                                   //
        {{}, {0}, "%-F", {"file4.txt"}},                                                                     //
        {{}, {1}, "%-F", {"file5.txt"}},                                                                     //
        {{}, {2}, "%-F", {"file6.txt"}},                                                                     //
        {{}, {0, 1}, "%-F", {"file4.txt", "file5.txt"}},                                                     //
        {{}, {1, 2}, "%-F", {"file5.txt", "file6.txt"}},                                                     //
        {{}, {0, 1, 2}, "%-F", {"file4.txt", "file5.txt", "file6.txt"}},                                     //
        {{}, {}, "%P", {root / "dir1/file1.txt"}},                                                           //
        {{}, {}, "%- %P", {root / "dir1/file1.txt"}},                                                        //
        {{0}, {}, "%P", {root / "dir1/file1.txt"}},                                                          //
        {{1}, {}, "%P", {root / "dir1/file2.txt"}},                                                          //
        {{2}, {}, "%P", {root / "dir1/file3.txt"}},                                                          //
        {{0, 1}, {}, "%P", {root / "dir1/file1.txt", root / "dir1/file2.txt"}},                              //
        {{1, 2}, {}, "%P", {root / "dir1/file2.txt", root / "dir1/file3.txt"}},                              //
        {{0, 1, 2}, {}, "%P", {root / "dir1/file1.txt", root / "dir1/file2.txt", root / "dir1/file3.txt"}},  //
        {{}, {}, "%-P", {root / "dir2/file4.txt"}},                                                          //
        {{}, {}, "%- %-P", {root / "dir2/file4.txt"}},                                                       //
        {{}, {0}, "%-P", {root / "dir2/file4.txt"}},                                                         //
        {{}, {1}, "%-P", {root / "dir2/file5.txt"}},                                                         //
        {{}, {2}, "%-P", {root / "dir2/file6.txt"}},                                                         //
        {{}, {0, 1}, "%-P", {root / "dir2/file4.txt", root / "dir2/file5.txt"}},                             //
        {{}, {1, 2}, "%-P", {root / "dir2/file5.txt", root / "dir2/file6.txt"}},                             //
        {{}, {0, 1, 2}, "%-P", {root / "dir2/file4.txt", root / "dir2/file5.txt", root / "dir2/file6.txt"}}, //
        {{0, 1, 2},
         {0, 1, 2},
         "%F %-F",
         {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {{0, 1, 2}, {0, 1, 2}, "%1T %F %-F", {"file1.txt"}},
        {{0, 1, 2}, {0, 1, 2}, "%2T %F %-F", {"file1.txt", "file2.txt"}},
        {{0, 1, 2}, {0, 1, 2}, "%3T %F %-F", {"file1.txt", "file2.txt", "file3.txt"}},
        {{0, 1, 2}, {0, 1, 2}, "%4T %F %-F", {"file1.txt", "file2.txt", "file3.txt", "file4.txt"}},
        {{0, 1, 2}, {0, 1, 2}, "%5T %F %-F", {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt"}},
        {{0, 1, 2},
         {0, 1, 2},
         "%6T %F %-F",
         {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {{0, 1, 2},
         {0, 1, 2},
         "%7T %F %-F",
         {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {{0, 1, 2},
         {0, 1, 2},
         "%0T %F %-F",
         {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
        {{0, 1, 2},
         {0, 1, 2},
         "%100T %F %-F",
         {"file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt", "file6.txt"}},
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

    VFSListingPtr l1, l2;
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), l1, VFSFlags::F_NoDotDot, {}) == 0);
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), l2, VFSFlags::F_NoDotDot, {}) == 0);
    data::Model left, right;
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
        {{}, {}, "%LF", "file4.txt"},
        {{}, {}, "%-LF", "file1.txt"},
        {{}, {0}, "%LF", "file4.txt"},
        {{}, {1}, "%LF", "file5.txt"},
        {{}, {2}, "%LF", "file6.txt"},
        {{0}, {}, "%-LF", "file1.txt"},
        {{1}, {}, "%-LF", "file2.txt"},
        {{2}, {}, "%-LF", "file3.txt"},
        {{}, {0, 1, 2}, "%LF", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {0, 1}, "%LF", "file4.txt\nfile5.txt"},
        {{}, {1, 2}, "%LF", "file5.txt\nfile6.txt"},
        {{0, 1, 2}, {}, "%-LF", "file1.txt\nfile2.txt\nfile3.txt"},
        {{0, 1}, {}, "%-LF", "file1.txt\nfile2.txt"},
        {{1, 2}, {}, "%-LF", "file2.txt\nfile3.txt"},
        {{}, {0, 1, 2}, "%L100F", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {0, 1, 2}, "%L3F", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {0, 1, 2}, "%L2F", "file4.txt\nfile5.txt"},
        {{}, {0, 1, 2}, "%L1F", "file4.txt"},
        {{}, {0, 1, 2}, "%L0F", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {0, 1, 2}, "%100T %LF", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {0, 1, 2}, "%3T %LF", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {0, 1, 2}, "%2T %LF", "file4.txt\nfile5.txt"},
        {{}, {0, 1, 2}, "%1T %LF", "file4.txt"},
        {{}, {0, 1, 2}, "%0T %LF", "file4.txt\nfile5.txt\nfile6.txt"},
        {{}, {}, "%LP", f4},
        {{}, {}, "%-LP", f1},
        {{}, {0}, "%LP", f4},
        {{}, {1}, "%LP", f5},
        {{}, {2}, "%LP", f6},
        {{0}, {}, "%-LP", f1},
        {{1}, {}, "%-LP", f2},
        {{2}, {}, "%-LP", f3},
        {{}, {0, 1, 2}, "%LP", f4 + "\n" + f5 + "\n" + f6},
        {{}, {0, 1}, "%LP", f4 + "\n" + f5},
        {{}, {1, 2}, "%LP", f5 + "\n" + f6},
        {{0, 1, 2}, {}, "%-LP", f1 + "\n" + f2 + "\n" + f3},
        {{0, 1}, {}, "%-LP", f1 + "\n" + f2},
        {{1, 2}, {}, "%-LP", f2 + "\n" + f3},
        {{}, {0, 1, 2}, "%L100P", f4 + "\n" + f5 + "\n" + f6},
        {{}, {0, 1, 2}, "%L3P", f4 + "\n" + f5 + "\n" + f6},
        {{}, {0, 1, 2}, "%L2P", f4 + "\n" + f5},
        {{}, {0, 1, 2}, "%L1P", f4},
        {{}, {0, 1, 2}, "%L0P", f4 + "\n" + f5 + "\n" + f6},
        {{}, {0, 1, 2}, "%100T %LP", f4 + "\n" + f5 + "\n" + f6},
        {{}, {0, 1, 2}, "%3T %LP", f4 + "\n" + f5 + "\n" + f6},
        {{}, {0, 1, 2}, "%2T %LP", f4 + "\n" + f5},
        {{}, {0, 1, 2}, "%1T %LP", f4},
        {{}, {0, 1, 2}, "%0T %LP", f4 + "\n" + f5 + "\n" + f6},
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

    VFSListingPtr l1, l2;
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir1").c_str(), l1, VFSFlags::F_NoDotDot, {}) == 0);
    REQUIRE(TestEnv().vfs_native->FetchDirectoryListing((root / "dir2").c_str(), l2, VFSFlags::F_NoDotDot, {}) == 0);
    data::Model left, right;
    left.Load(l1, data::Model::PanelType::Directory);
    right.Load(l2, data::Model::PanelType::Directory);
    nc::utility::TemporaryFileStorageImpl temp_storage(root.native(), "temp");
    struct TC {
        std::vector<std::string> inputs;
        std::string params_string;
        std::vector<std::string> args_expected;
        std::vector<std::string> prompts_expected;
    } const tcs[] = {
        {{"hello"}, "%?", {"hello"}, {""}},
        {{"hello"}, "%?world", {"helloworld"}, {""}},
        {{"hello"}, "%? world", {"hello", "world"}, {""}},
        {{"hello"}, "!!!%?world", {"!!!helloworld"}, {""}},
        {{"hello"}, "!!!%\"Salve!\"?world", {"!!!helloworld"}, {"Salve!"}},
        {{"hello", "world"}, "%? %?", {"hello", "world"}, {"", ""}},
        {{"hello", "world"}, "%?%?", {"helloworld"}, {"", ""}},
        {{"hello"}, "%? %f", {"hello", "file1.txt"}, {""}},
        {{"hello"}, "%?%f", {"hellofile1.txt"}, {""}},
        {{"hello"}, "%f%?%-f", {"file1.txthellofile3.txt"}, {""}},
        {{"hello"}, "%f %? %-f", {"file1.txt", "hello", "file3.txt"}, {""}},
        {{"hello"}, "%\"%\"?", {"hello"}, {"%"}},
        {{"hello"}, "%\"%?\"?", {"hello"}, {"%?"}},
        {{"hello"}, "%\"%%\"?", {"hello"}, {"%"}},
        {{"hello"}, "%\"%%%%\"?", {"hello"}, {"%%"}},
        //        {{"hello"}, "%\"%%\\\"%%\"?", {"hello"}, {"%\"%"}}, // doesnt work now...
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
