// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch_all.hpp>
#include <filesystem>

#define GTEST_DONT_DEFINE_FAIL 1
#define GTEST_DONT_DEFINE_SUCCEED 1
#include <gmock/gmock.h>

struct TestDir {
    TestDir();
    ~TestDir();
    std::filesystem::path directory;
    static std::string MakeTempFilesStorage();
};
