// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "variable_container.h"
#include "UnitTests_main.h"
#include <string>

using nc::base::variable_container;

#define PREFIX "variable_container "

TEST_CASE(PREFIX "Common storage")
{
    variable_container<std::string> vc(variable_container<>::type::common);
    CHECK(vc.size() == 1);
    CHECK(vc.empty() == false);
    CHECK(vc.at(0) == ""); // NOLINT default-constructed
    CHECK(vc[0] == "");    // NOLINT

    vc.at(0) = "Meow";
    CHECK(vc.at(0) == "Meow");
    CHECK(vc[0] == "Meow");
}

TEST_CASE(PREFIX "Sparse storage")
{
    variable_container<std::string> vc(variable_container<>::type::sparse);
    CHECK(vc.size() == 0); // NOLINT
    CHECK(vc.empty() == true);

    vc.insert(5, "abra");
    CHECK(vc.size() == 1);
    vc.insert(6, "kazam");
    CHECK(vc.size() == 2);
    CHECK(vc.at(5) == "abra");
    CHECK(vc.at(6) == "kazam");

    vc.insert(5, "abra!");
    CHECK(vc.size() == 2);
    CHECK(vc.at(5) == "abra!");

    CHECK(vc.has(5));
    CHECK(vc.has(6));
    CHECK(!vc.has(7));
}

TEST_CASE(PREFIX "Dense storage")
{
    variable_container<std::string> vc(variable_container<>::type::dense);

    vc.insert(5, "abra");
    vc.insert(6, "kazam");
    CHECK(vc.at(5) == "abra");
    CHECK(vc.at(6) == "kazam");

    vc.insert(5, "abra!");
    CHECK(vc.at(5) == "abra!");

    CHECK(vc.has(5));
    CHECK(vc.has(6));
    CHECK(!vc.has(7));

    CHECK(vc.at(0) == ""); // NOLINT

    variable_container<std::string> vc2(vc);
    CHECK(vc2.at(5) == "abra!");

    variable_container<std::string> vc3(std::move(vc2));
    CHECK(vc3.at(6) == "kazam");
}

TEST_CASE(PREFIX "is_contiguous")
{
    {
        variable_container<std::string> vc(variable_container<>::type::common);
        CHECK(vc.is_contiguous());
        vc.insert(0, "Meow");
        CHECK(vc.is_contiguous());
    }
    {
        variable_container<std::string> vc(variable_container<>::type::dense);
        CHECK(vc.is_contiguous());
        vc.insert(0, "Meow");
        CHECK(vc.is_contiguous());
        vc.insert(5, "Woof");
        CHECK(vc.is_contiguous());
    }
    {
        variable_container<std::string> vc(variable_container<>::type::sparse);
        CHECK(vc.is_contiguous());
        vc.insert(0, "Meow");
        CHECK(vc.is_contiguous());
        vc.insert(1, "Woof");
        CHECK(vc.is_contiguous());
        vc.insert(5, "Hiss");
        CHECK(!vc.is_contiguous());
    }
}
