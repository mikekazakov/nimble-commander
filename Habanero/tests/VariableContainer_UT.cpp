// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "variable_container.h"
#include "UnitTests_main.h"
#include <string>

using nc::base::variable_container;

#define PREFIX "variable_container "

TEST_CASE(PREFIX"test 1")
{    
    variable_container< std::string > vc( variable_container<std::string>::type::common );
    vc.at(0) = "Abra!!!";
    CHECK( vc.at(0) == "Abra!!!" );
}

TEST_CASE(PREFIX"test 2")
{
    variable_container< std::string > vc( variable_container<std::string>::type::sparse );

    vc.insert(5, "abra");
    vc.insert(6, "kazam");
    CHECK( vc.at(5) == "abra" );
    CHECK( vc.at(6) == "kazam" );
    
    vc.insert(5, "abra!");
    CHECK( vc.at(5) == "abra!" );
    
    CHECK( vc.has(5) );
    CHECK( vc.has(6) );
    CHECK(!vc.has(7) );
}

TEST_CASE(PREFIX"test 3")
{
    variable_container< std::string > vc( variable_container<std::string>::type::dense );
    
    vc.insert(5, "abra");
    vc.insert(6, "kazam");
    CHECK( vc.at(5) == "abra" );
    CHECK( vc.at(6) == "kazam" );
    
    vc.insert(5, "abra!");
    CHECK( vc.at(5) == "abra!" );
    
    CHECK( vc.has(5) );
    CHECK( vc.has(6) );
    CHECK(!vc.has(7) );
    
    CHECK( vc.at(0) == "" );
    
    variable_container< std::string > vc2( vc );
    CHECK( vc2.at(5) == "abra!" );
    
    variable_container< std::string > vc3( std::move(vc2) );
    CHECK( vc3.at(6) == "kazam" );
}
