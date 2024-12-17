// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <catch2/catch_all.hpp>
#include <Base/CommonPaths.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/dirent.h>
#include "Tests.h"

static auto g_TestDirPrefix = "_nc__viewer__test_";

int main(int argc, char *argv[])
{
    return Catch::Session().run(argc, argv);
}

static std::string MakeTempFilesStorage()
{
    const auto base_path = nc::base::CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( std::filesystem::exists(tmp_path) )
        std::filesystem::remove_all(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}

TempTestDir::TempTestDir()
{
    directory = MakeTempFilesStorage();
}

TempTestDir::~TempTestDir()
{
    std::filesystem::remove_all(directory);
}
