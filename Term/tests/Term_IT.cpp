// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Parser2Impl.h>
#include <InterpreterImpl.h>
#include <Screen.h>
#include "Tests.h"

using namespace nc::term;
#define PREFIX "nc::term::Interpreter "

static std::pair<const char*, const char*> g_SimpleCases[] = 
{
    {
        "Hello",
        "Hello     "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "Hello\x0C""Hello",
        "Hello     "
        "     Hello"
        "          "
        "          "
        "          "
        "          "
    },    
    {
        "Hello\x0C""\x0D""Hello",
        "Hello     "
        "Hello     "
        "          "
        "          "
        "          "
        "          "
    },  
    {
        "Hello\x0D""\x0C""Hello",
        "Hello     "
        "Hello     "
        "          "
        "          "
        "          "
        "          "
    },    
    {
        "\x0C\x0C\x0C\x0C""Hello",
        "          "
        "          "
        "          "
        "          "
        "Hello     "
        "          "        
    },       
    {
        "\x0C\x0C\x0C\x0C\x0C""Hello",
        "          "
        "          "
        "          "
        "          "
        "          "
        "Hello     "
    },     
    {
        "\x0C\x0C\x0C\x0C\x0C\x0C""Hello",
        "          "
        "          "
        "          "
        "          "
        "          "
        "Hello     "
    },    
    {
        "\x08Hello\x08\x08""Hello",
        "HelHello  "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "\x0C""\x1B""M""Hello",
        "Hello     "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "\x1B""[8;10H*""\x1B""[1;10H*""\x1B""[1;1H*""\x1B""[8;1H*",
        "*        *"
        "          "
        "          "
        "          "
        "          "
        "*        *"
    },
    {
        "\x0C\x0C\x1B[2A*\x1B[3B*\x1B[2C*\x1B[5D*",
        "*         "
        "          "
        "          "
        "**  *     "
        "          "
        "          "
    },
    {
        "\x1B[9C**",
        "         *"
        "*         "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "\t*\n\x1B[2Z*",
        "        * "
        "*         "
        "          "
        "          "
        "          "
        "          "
    },            
};

static std::pair<const char8_t*, const char32_t*> g_UTFCases[] = 
{
    {
        reinterpret_cast<const char8_t*>("\xD0\xB5\xCC\x88"), // е ̈ 
        U"ё         "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        reinterpret_cast<const char8_t*>("\xD0\xB5\xCC\x88\xCC\xB6"), // ё̶
        U"\x451\x336         "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        reinterpret_cast<const char8_t*>("\x1B""[10G""\xD0\xB5\xCC\x88\xCC\xB6"), // ESC[10Gё̶
        U"         \x451\x336"
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        reinterpret_cast<const char8_t*>("\x1B""[6;10H""\xD0\xB5\xCC\x88\xCC\xB6"), // ESC[6;10HGё̶
        U"          "
        "          "
        "          "
        "          "
        "          "
        "         \x451\x336"
    },    
};

TEST_CASE(PREFIX"Simple cases")
{
    for( size_t i = 0; i < std::extent_v<decltype(g_SimpleCases)>; ++i ) {
        const auto test_case = g_SimpleCases[i];
        
        Parser2Impl parser;
        Screen screen(10, 6);
        InterpreterImpl interpreter(screen);
        
        const auto input_bytes = Parser2::Bytes(reinterpret_cast<const std::byte*>(test_case.first),
            strlen(test_case.first));
        interpreter.Interpret(parser.Parse( input_bytes ) );
         
        const auto result = screen.Buffer().DumpScreenAsANSI();
        const auto expectation = test_case.second;
        CHECK( result == expectation );
    }
}

TEST_CASE(PREFIX"UTF cases")
{
    for( size_t i = 0; i < std::extent_v<decltype(g_UTFCases)>; ++i ) {
        const auto test_case = g_UTFCases[i];
        
        Parser2Impl parser;
        Screen screen(10, 6);
        InterpreterImpl interpreter(screen);
        
        const auto input = std::u8string_view{test_case.first};
        const auto input_bytes = Parser2::Bytes(reinterpret_cast<const std::byte*>(input.data()),
            input.length());
        interpreter.Interpret(parser.Parse( input_bytes ) );
         
        const auto result = screen.Buffer().DumpScreenAsUTF32();
        const auto expectation = test_case.second;
        CHECK( result == expectation );
    }
}
