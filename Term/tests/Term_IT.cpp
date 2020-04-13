// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Parser2Impl.h>
#include <InterpreterImpl.h>
#include <Screen.h>
#include "Tests.h"

using namespace nc::term;
#define PREFIX "nc::term::Interpreter "

const static std::pair<const char*, const char*> g_SimpleCases[] = 
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
    {
        "aaa\r\nbbb",
        "aaa       "
        "bbb       "
        "          "
        "          "
        "          "
        "          "
    },        
    {
        "aaa\r\n""\x1B""Mbbb",
        "bbb       "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
};

const static std::pair<const char*, const char*> g_ResponseCases[] = 
{
    {
        "\x1B[c",
        "\033[?6c"
    },
    {
        "\x1B[5n",
        "\033[0n"
    },
    {
        "\x1B[6n",
        "\033[1;1R"
    },
    {
        "\x1B[6;10H\x1B[6n",
        "\033[6;10R"
    },
};

const static std::pair<const char8_t*, const char32_t*> g_UTFCases[] = 
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

TEST_CASE(PREFIX"Response cases")
{
    for( size_t i = 0; i < std::extent_v<decltype(g_ResponseCases)>; ++i ) {
        const auto test_case = g_ResponseCases[i];
        
        Parser2Impl parser;
        Screen screen(10, 6);
        InterpreterImpl interpreter(screen);
        
        std::string response;
        interpreter.SetOuput([&](Interpreter::Bytes _bytes){
            if( not _bytes.empty() )
                response.append( reinterpret_cast<const char*>(_bytes.data()), _bytes.size());        
        });
        
        const auto input_bytes = Parser2::Bytes(reinterpret_cast<const std::byte*>(test_case.first),
            strlen(test_case.first));
        interpreter.Interpret(parser.Parse( input_bytes ) );
         
        const auto expectation = test_case.second;
        CHECK( response == expectation );
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

TEST_CASE(PREFIX"vttest - test of cursor movements, "
"Test of cursor-control characters inside ESC sequences.")
{
    const auto raw_input =
    "\x1B[?3l\x1B[2J\x1B[1;1HTest of cursor-control characters inside ESC sequences."
    "\x0D\x0D\x0A""Below should be four identical lines:\x0D\x0D\x0A\x0D\x0D\x0A""A B C D E F G H I"
    "\x0D\x0D\x0A""A\x1B[2\x08""CB\x1B[2\x08""CC\x1B[2\x08""CD\x1B[2\x08""CE\x1B[2\x08""CF\x1B[2\x08""CG\x1B[2\x08""CH\x1B[2\x08""CI"
    "\x1B[2\x08""C\x0D\x0D\x0A""A \x1B[\x0D""2CB\x1B[\x0D""4CC\x1B[\x0D""6CD\x1B[\x0D""8CE\x1B[\x0D""10CF\x1B[\x0D""12CG\x1B[\x0D""14CH\x1B[\x0D""16CI"
    "\x0D\x0D\x0A\x1B[20lA \x1B[1\x0B""AB \x1B[1\x0B""AC \x1B[1\x0B""AD \x1B[1\x0B""AE \x1B[1\x0B""AF \x1B[1\x0B""AG \x1B[1\x0B""AH \x1B[1\x0B""AI"
    " \x1B[1\x0BA\x0D\x0D\x0A\x0D\x0D\x0A""Push <RETURN>";
    const auto expectation = 
    "Test of cursor-control characters inside ESC sequences.     "
    "Below should be four identical lines:                       "
    "                                                            "
    "A B C D E F G H I                                           "
    "A B C D E F G H I                                           "
    "A B C D E F G H I                                           "
    "A B C D E F G H I                                           "
    "                                                            "
    "Push <RETURN>                                               ";

    Parser2Impl parser;
    Screen screen(60, 9);
    InterpreterImpl interpreter(screen);    
    const auto input = std::string_view{raw_input};
    const auto input_bytes = Parser2::Bytes(reinterpret_cast<const std::byte*>(input.data()),
                                            input.length());
    interpreter.Interpret(parser.Parse( input_bytes ) );
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK( result == expectation );
}

TEST_CASE(PREFIX"vttest - test of cursor movements, "
"Test of leading zeros in ESC sequences.")
{
    const auto raw_input =
    "\x1B[2J\x1B[1;1HTest of leading zeros in ESC sequences.\x0D\x0D\x0A"
    "Two lines below you should see the sentence \"This is a correct sentence\"."   
    "\x1B[00000000004;000000001HT\x1B[00000000004;000000002Hh\x1B[00000000004;000000003Hi\x1B[00000000004;000000004Hs"
    "\x1B[00000000004;000000005H \x1B[00000000004;000000006Hi\x1B[00000000004;000000007Hs\x1B[00000000004;000000008H "
    "\x1B[00000000004;000000009Ha\x1B[00000000004;0000000010H \x1B[00000000004;0000000011Hc\x1B[00000000004;0000000012Ho"
    "\x1B[00000000004;0000000013Hr\x1B[00000000004;0000000014Hr\x1B[00000000004;0000000015He\x1B[00000000004;0000000016Hc"
    "\x1B[00000000004;0000000017Ht\x1B[00000000004;0000000018H \x1B[00000000004;0000000019Hs\x1B[00000000004;0000000020He"
    "\x1B[00000000004;0000000021Hn\x1B[00000000004;0000000022Ht\x1B[00000000004;0000000023He\x1B[00000000004;0000000024Hn"
    "\x1B[00000000004;0000000025Hc\x1B[00000000004;0000000026He\x1B[20;1H"    
    "Push <RETURN>";    
    const auto expectation = 
    "Test of leading zeros in ESC sequences.                                         "
    "Two lines below you should see the sentence \"This is a correct sentence\".       "
    "                                                                                "
    "This is a correct sentence                                                      "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "Push <RETURN>                                                                   ";

    Parser2Impl parser;
    Screen screen(80, 20);
    InterpreterImpl interpreter(screen);    
    const auto input = std::string_view{raw_input};
    const auto input_bytes = Parser2::Bytes(reinterpret_cast<const std::byte*>(input.data()),
                                            input.length());
    interpreter.Interpret(parser.Parse( input_bytes ) );
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK( result == expectation );

}

TEST_CASE(PREFIX"rn escape assumption")
{
    auto string = std::string_view("\r\n");
    REQUIRE( string.size() == 2 );
    REQUIRE( string[0] == 13 );
    REQUIRE( string[1] == 10 ); 
}
