// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <catch2/catch.hpp>
#include <gmock/gmock.h>
#include <filesystem>

struct TempTestDir {
    TempTestDir();
    ~TempTestDir();
    std::filesystem::path directory;
};
