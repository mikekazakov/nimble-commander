#pragma once

#include <catch2/catch_all.hpp>
#include <gmock/gmock.h>
#include <filesystem>

struct TempTestDir {
    TempTestDir();
    ~TempTestDir();
    std::filesystem::path directory;
};
