// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <catch2/catch.hpp>

//#define GTEST_DONT_DEFINE_FAIL 1
//#define GTEST_DONT_DEFINE_SUCCEED 1
//#include <gmock/gmock.h>

struct TestDir
{
    TestDir();
    ~TestDir();
    std::string directory;
    static std::string MakeTempFilesStorage();
    static int RMRF(const std::string& _path);
};
