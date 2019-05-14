// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ActionShortcut.h"
#include "UnitTests_main.h"

using nc::utility::ActionShortcut;

#define PREFIX "nc::utility::ActionShortcut "
TEST_CASE(PREFIX"Default constructor makes both unicode and modifiers zero")
{
    ActionShortcut as;
    CHECK( as.unicode == 0 );
    CHECK( as.modifiers.is_empty() );
}

TEST_CASE(PREFIX"ShortCut with both unicode and modifiers zero is convertible to false")
{
    CHECK( (bool)ActionShortcut{} == false );
    CHECK( (bool)ActionShortcut{49, NSEventModifierFlagCommand} == true );
}

TEST_CASE(PREFIX"Properly parses persistency strings")
{
    CHECK( ActionShortcut{u8""} == ActionShortcut{} );
    CHECK( ActionShortcut{u8"1"} == ActionShortcut{49, 0} );
    CHECK( ActionShortcut{u8"⌘1"} == ActionShortcut{49, NSEventModifierFlagCommand} );
    CHECK( ActionShortcut{u8"⇧⌘1"} == 
          ActionShortcut{49, NSEventModifierFlagShift | NSEventModifierFlagCommand} );
    CHECK( ActionShortcut{u8"^⌘1"} == 
          ActionShortcut{49, NSEventModifierFlagControl | NSEventModifierFlagCommand} );
    CHECK( ActionShortcut{u8"⌥⌘1"} == 
          ActionShortcut{49, NSEventModifierFlagOption | NSEventModifierFlagCommand} );
    CHECK( ActionShortcut{u8"^⇧⌥⌘1"} == 
          ActionShortcut{49, NSEventModifierFlagShift | NSEventModifierFlagControl | 
              NSEventModifierFlagOption | NSEventModifierFlagCommand} );    
}

TEST_CASE(PREFIX"Handles serialized special symbols properly")
{
    CHECK( ActionShortcut{u8"\\r"} == ActionShortcut{13, 0} );
    CHECK( ActionShortcut{u8"\\t"} == ActionShortcut{9, 0} );
}

TEST_CASE(PREFIX"Produces correct persistent strings")
{
    CHECK( ActionShortcut{u8"⇧^⌥⌘a"}.ToPersString() == u8"⇧^⌥⌘a" );
    CHECK( ActionShortcut{u8"⇧^⌥⌘1"}.ToPersString() == u8"⇧^⌥⌘1" );
    CHECK( ActionShortcut{u8"^⌥⌘1"}.ToPersString() == u8"^⌥⌘1" );
    CHECK( ActionShortcut{u8"⌥⌘1"}.ToPersString() == u8"⌥⌘1" );
    CHECK( ActionShortcut{u8"⌘1"}.ToPersString() == u8"⌘1" );
    CHECK( ActionShortcut{u8"1"}.ToPersString() == u8"1" );    
}

TEST_CASE(PREFIX"Does proper comparison")
{
    CHECK( ActionShortcut{u8"⌘1"} == ActionShortcut{u8"⌘1"} );
    CHECK( !(ActionShortcut{u8"⌘1"} == ActionShortcut{u8"⌘2"}) );
    CHECK( ActionShortcut{u8"⌘1"} != ActionShortcut{u8"⌘2"} );
    CHECK( !(ActionShortcut{u8"⌘1"} != ActionShortcut{u8"⌘1"}) );
    CHECK( !(ActionShortcut{u8"⌘1"} == ActionShortcut{u8"^1"}) );
    CHECK( ActionShortcut{u8"⌘1"} != ActionShortcut{u8"^1"} );    
}
