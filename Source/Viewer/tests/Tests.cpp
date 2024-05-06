// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_RUNNER
#include <catch2/catch.hpp>

int main(int argc, char *argv[])
{
    return Catch::Session().run(argc, argv);
}
