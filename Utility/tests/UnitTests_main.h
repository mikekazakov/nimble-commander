// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <catch2/catch.hpp>
#include <gmock/gmock.h>

struct TempTestDir
{
    TempTestDir();
    ~TempTestDir();
    std::string directory;
};
