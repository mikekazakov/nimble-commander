// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Parser2Impl.h>
#include <InterpreterImpl.h>
#include <Screen.h>
#include "Tests.h"

#include <iostream>

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
    {
        "\x1B""#8",
        "EEEEEEEEEE"
        "EEEEEEEEEE"
        "EEEEEEEEEE"
        "EEEEEEEEEE"
        "EEEEEEEEEE"
        "EEEEEEEEEE"
    },
    {
        "a\x08\x1B[1J",
        "          "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "aa\x08\x1B[1J",
        "          "
        "          "
        "          "
        "          "
        "          "
        "          "
    }

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

[[maybe_unused]] static void Print( const std::span<const input::Command> &_commands )
{
    for( auto &cmd: _commands )
        std::cout << input::VerboseDescription(cmd) << "\n";
    std::cout << std::endl;
}

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

TEST_CASE(PREFIX"vttest - test of cursor movements, "
"Test zero movements, display alignment, display erase, line erase")
{
    const auto raw_input =
    "\x1B[?3l\x1B#8\x1B[9;10H\x1B[1J\x1B[18;60H\x1B[0J\x1B[1K\x1B[9;71H\x1B[0K\x1B[10;10H\x1B[1K"
    "\x1B[10;71H\x1B[0K\x1B[11;10H\x1B[1K\x1B[11;71H\x1B[0K\x1B[12;10H\x1B[1K\x1B[12;71H\x1B[0K"
    "\x1B[13;10H\x1B[1K\x1B[13;71H\x1B[0K\x1B[14;10H\x1B[1K\x1B[14;71H\x1B[0K\x1B[15;10H\x1B[1K"
    "\x1B[15;71H\x1B[0K\x1B[16;10H\x1B[1K\x1B[16;71H\x1B[0K\x1B[17;30H\x1B[2K\x1B[24;1f*\x1B[1;1f*"
    "\x1B[24;2f*\x1B[1;2f*\x1B[24;3f*\x1B[1;3f*\x1B[24;4f*\x1B[1;4f*\x1B[24;5f*\x1B[1;5f*"
    "\x1B[24;6f*\x1B[1;6f*\x1B[24;7f*\x1B[1;7f*\x1B[24;8f*\x1B[1;8f*\x1B[24;9f*\x1B[1;9f*"
    "\x1B[24;10f*\x1B[1;10f*\x1B[24;11f*\x1B[1;11f*\x1B[24;12f*\x1B[1;12f*\x1B[24;13f*\x1B[1;13f*"
    "\x1B[24;14f*\x1B[1;14f*\x1B[24;15f*\x1B[1;15f*\x1B[24;16f*\x1B[1;16f*\x1B[24;17f*\x1B[1;17f*"
    "\x1B[24;18f*\x1B[1;18f*\x1B[24;19f*\x1B[1;19f*\x1B[24;20f*\x1B[1;20f*\x1B[24;21f*\x1B[1;21f*"
    "\x1B[24;22f*\x1B[1;22f*\x1B[24;23f*\x1B[1;23f*\x1B[24;24f*\x1B[1;24f*\x1B[24;25f*\x1B[1;25f*"
    "\x1B[24;26f*\x1B[1;26f*\x1B[24;27f*\x1B[1;27f*\x1B[24;28f*\x1B[1;28f*\x1B[24;29f*\x1B[1;29f*"
    "\x1B[24;30f*\x1B[1;30f*\x1B[24;31f*\x1B[1;31f*\x1B[24;32f*\x1B[1;32f*\x1B[24;33f*\x1B[1;33f*"
    "\x1B[24;34f*\x1B[1;34f*\x1B[24;35f*\x1B[1;35f*\x1B[24;36f*\x1B[1;36f*\x1B[24;37f*\x1B[1;37f*"
    "\x1B[24;38f*\x1B[1;38f*\x1B[24;39f*\x1B[1;39f*\x1B[24;40f*\x1B[1;40f*\x1B[24;41f*\x1B[1;41f*"
    "\x1B[24;42f*\x1B[1;42f*\x1B[24;43f*\x1B[1;43f*\x1B[24;44f*\x1B[1;44f*\x1B[24;45f*\x1B[1;45f*"
    "\x1B[24;46f*\x1B[1;46f*\x1B[24;47f*\x1B[1;47f*\x1B[24;48f*\x1B[1;48f*\x1B[24;49f*\x1B[1;49f*"
    "\x1B[24;50f*\x1B[1;50f*\x1B[24;51f*\x1B[1;51f*\x1B[24;52f*\x1B[1;52f*\x1B[24;53f*\x1B[1;53f*"
    "\x1B[24;54f*\x1B[1;54f*\x1B[24;55f*\x1B[1;55f*\x1B[24;56f*\x1B[1;56f*\x1B[24;57f*\x1B[1;57f*"
    "\x1B[24;58f*\x1B[1;58f*\x1B[24;59f*\x1B[1;59f*\x1B[24;60f*\x1B[1;60f*\x1B[24;61f*\x1B[1;61f*"
    "\x1B[24;62f*\x1B[1;62f*\x1B[24;63f*\x1B[1;63f*\x1B[24;64f*\x1B[1;64f*\x1B[24;65f*\x1B[1;65f*"
    "\x1B[24;66f*\x1B[1;66f*\x1B[24;67f*\x1B[1;67f*\x1B[24;68f*\x1B[1;68f*\x1B[24;69f*\x1B[1;69f*"
    "\x1B[24;70f*\x1B[1;70f*\x1B[24;71f*\x1B[1;71f*\x1B[24;72f*\x1B[1;72f*\x1B[24;73f*\x1B[1;73f*"
    "\x1B[24;74f*\x1B[1;74f*\x1B[24;75f*\x1B[1;75f*\x1B[24;76f*\x1B[1;76f*\x1B[24;77f*\x1B[1;77f*"
    "\x1B[24;78f*\x1B[1;78f*\x1B[24;79f*\x1B[1;79f*\x1B[24;80f*\x1B[1;80f*\x1B[2;2H+\x1B[1D"
    "\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D"
    "\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D"
    "\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D"
    "\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D+\x1B[1D\x1B""D\x1B[23;79H+\x1B[1D\x1BM+\x1B[1D\x1BM+"
    "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+"
    "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+"
    "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM\x1B[2;1H*"
    "\x1B[2;80H*\x1B[10D\x1B""E*\x1B[3;80H*\x1B[10D\x1B""E*\x1B[4;80H*\x1B[10D\x1B""E*\x1B[5;80H*"
    "\x1B[10D\x1B""E*\x1B[6;80H*\x1B[10D\x1B""E*\x1B[7;80H*\x1B[10D\x1B""E*\x1B[8;80H*\x1B[10D"
    "\x1B""E*\x1B[9;80H*\x1B[10D\x1B""E*\x1B[10;80H*\x1B[10D\x0D\x0A*\x1B[11;80H*\x1B[10D\x0D\x0A*"
    "\x1B[12;80H*\x1B[10D\x0D\x0A*\x1B[13;80H*\x1B[10D\x0D\x0A*\x1B[14;80H*\x1B[10D\x0D\x0A*"
    "\x1B[15;80H*\x1B[10D\x0D\x0A*\x1B[16;80H*\x1B[10D\x0D\x0A*\x1B[17;80H*\x1B[10D\x0D\x0A*"
    "\x1B[18;80H*\x1B[10D\x0D\x0A*\x1B[19;80H*\x1B[10D\x0D\x0A*\x1B[20;80H*\x1B[10D\x0D\x0A*"
    "\x1B[21;80H*\x1B[10D\x0D\x0A*\x1B[22;80H*\x1B[10D\x0D\x0A*\x1B[23;80H*\x1B[10D\x0D\x0A"
    "\x1B[2;10H\x1B[42D\x1B[2C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+"
    "\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C\x1B[23;70H\x1B[42C\x1B[2D+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08"
    "+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C"
    "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+"
    "\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08\x1B[1;1H"
    "\x1B[10A\x1B[1A\x1B[0A\x1B[24;80H\x1B[10B\x1B[1B\x1B[0B"
    "\x1B[10;12H                                                          \x1B[1B"
    "\x1B[58D                                                          \x1B[1B"
    "\x1B[58D                                                          \x1B[1B"
    "\x1B[58D                                                          \x1B[1B"
    "\x1B[58D                                                          \x1B[1B"
    "\x1B[58D                                                          \x1B[1B"
    "\x1B[58D\x1B[5A\x1B[1C"
    "The screen should be cleared,  and have an unbroken bor-\x1B[12;13Hder of *'s and +'s around"
    " the edge,   and exactly in the\x1B[13;13Hmiddle  there should be a frame of E's around this"
    "  text\x1B[14;13Hwith  one (1) free position around it.    Push <RETURN>";
    
    const auto expectation =
    "********************************************************************************"
    "*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+        EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE        +*"
    "*+        E                                                          E        +*"
    "*+        E The screen should be cleared,  and have an unbroken bor- E        +*"
    "*+        E der of *'s and +'s around the edge,   and exactly in the E        +*"
    "*+        E middle  there should be a frame of E's around this  text E        +*"
    "*+        E with  one (1) free position around it.    Push <RETURN>  E        +*"
    "*+        E                                                          E        +*"
    "*+        EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE        +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*+                                                                            +*"
    "*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*"
    "********************************************************************************"
    "                                                                                ";    
    
    Parser2Impl parser;
    Screen screen(80, 25);
    InterpreterImpl interpreter(screen);
    const auto input = std::string_view{raw_input};
    const auto input_bytes = Parser2::Bytes(reinterpret_cast<const std::byte*>(input.data()),
                                            input.length());
    interpreter.Interpret( parser.Parse( input_bytes ) );
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
