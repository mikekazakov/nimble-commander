// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <Operations/FilenameTextControl.h>
#include <VFS/Native.h>
#include <sys/stat.h>

#define PREFIX "DirectoryPathAutoCompletionImpl "

static bool MkDir(const std::string &_dir_path)
{
    return mkdir(_dir_path.c_str(), S_IRWXU) == 0;
}

static bool MkFile(const std::string &_file_path)
{
    return close(open(_file_path.c_str(), O_CREAT | O_RDWR, S_IRWXU)) == 0;
}

TEST_CASE(PREFIX "Tests")
{
    const TempTestDir tmp_dir;
    const auto dir = std::string(tmp_dir.directory);
    const auto native_host = TestEnv().vfs_native;

    MkDir(dir + "Directory1");
    MkDir(dir + "directory2");
    MkDir(dir + "dIRECTORY3");
    MkDir(dir + "AnotherDirectory");
    MkFile(dir + "direction1");
    MkFile(dir + "file");

    nc::ops::DirectoryPathAutoCompletionImpl auto_completion(native_host);

    // suggestions
    { // all directories
        const auto completions = auto_completion.PossibleCompletions(dir + "");
        CHECK(completions == std::vector<std::string>{"AnotherDirectory", "Directory1", "dIRECTORY3", "directory2"});
    }
    { // starting with 'd'
        const auto completions = auto_completion.PossibleCompletions(dir + "d");
        CHECK(completions == std::vector<std::string>{"Directory1", "dIRECTORY3", "directory2"});
    }
    { // starting with 'D'
        const auto completions = auto_completion.PossibleCompletions(dir + "D");
        CHECK(completions == std::vector<std::string>{"Directory1", "dIRECTORY3", "directory2"});
    }
    { // starting with 'A'
        const auto completions = auto_completion.PossibleCompletions(dir + "A");
        CHECK(completions == std::vector<std::string>{"AnotherDirectory"});
    }
    { // starting with 'z'
        const auto completions = auto_completion.PossibleCompletions(dir + "z");
        CHECK(completions.empty());
    }
    { // starting with 'adjagdjafgsdad'
        const auto completions = auto_completion.PossibleCompletions(dir + "adjagdjafgsdad");
        CHECK(completions.empty());
    }
    { // starting with 'file'
        const auto completions = auto_completion.PossibleCompletions(dir + "file");
        CHECK(completions.empty());
    }
    { // invalid dir
        const auto completions = auto_completion.PossibleCompletions(dir + "adasdadsa/");
        CHECK(completions.empty());
    }
    { // invalid dir + invalid filename
        const auto completions = auto_completion.PossibleCompletions(dir + "adasdadsa/asdasdasd");
        CHECK(completions.empty());
    }
    { // empty dir
        const auto completions = auto_completion.PossibleCompletions("");
        CHECK(completions.empty());
    }
    { // some gibberish
        const auto completions = auto_completion.PossibleCompletions("sidfogsodyfgosdufg");
        CHECK(completions.empty());
    }

    // completions
    {
        const auto path = auto_completion.Complete(dir + "", "Dir");
        CHECK(path == dir + "Dir/");
    }
    {
        const auto path = auto_completion.Complete(dir + "something", "Dir");
        CHECK(path == dir + "Dir/");
    }
    {
        const auto path = auto_completion.Complete(dir + "di", "Dir");
        CHECK(path == dir + "Dir/");
    }
}
