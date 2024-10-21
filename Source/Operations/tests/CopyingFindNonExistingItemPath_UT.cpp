// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "../source/Copying/Helpers.h"

using nc::ops::copying::FindNonExistingItemPath;

#define PREFIX "nc::ops::FindNonExistingItemPath "

TEST_CASE(PREFIX "regular file without extension")
{
    const TempTestDir dir;

    auto orig_path = dir.directory / "item";
    close(open((orig_path / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 2").native());
}

TEST_CASE(PREFIX "doesnt check the initial path")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item";

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 2").native());
}

TEST_CASE(PREFIX "regular file without extension when possible targets already exists")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item";
    close(open((dir.directory / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    close(open((dir.directory / "item 2").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    close(open((dir.directory / "item 3").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    close(open((dir.directory / "item 4").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 5").native());
}

TEST_CASE(PREFIX "regular file with extension")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item.zip";

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 2.zip").native());
}

TEST_CASE(PREFIX "regular file with extension when possible targets already exists")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item.zip";
    close(open((dir.directory / "item.zip").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    close(open((dir.directory / "item 2.zip").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    close(open((dir.directory / "item 3.zip").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    close(open((dir.directory / "item 4.zip").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 5.zip").native());
}

TEST_CASE(PREFIX "checks magnitudes of tens")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item.zip";
    close(open((dir.directory / "item.zip").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    for( int i = 2; i <= 9; ++i )
        close(open(
            (dir.directory / ("item " + std::to_string(i) + ".zip")).c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 10.zip").native());
}

TEST_CASE(PREFIX "checks magnitudes of hundreds")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item.zip";
    close(open((dir.directory / "item.zip").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    for( int i = 2; i <= 99; ++i )
        close(open(
            (dir.directory / ("item " + std::to_string(i) + ".zip")).c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native);

    CHECK(proposed_path == (dir.directory / "item 100.zip").native());
}

TEST_CASE(PREFIX "returns empty string on cancellation")
{
    const TempTestDir dir;
    auto orig_path = dir.directory / "item.zip";
    auto cancel = [] { return true; };

    auto proposed_path = FindNonExistingItemPath(orig_path.native(), *TestEnv().vfs_native, cancel);

    CHECK(proposed_path.empty());
}
