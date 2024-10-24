// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#define _LIBCPP_DISABLE_DEPRECATION_WARNINGS
#include <ParserImpl.h>
#include <InterpreterImpl.h>
#include <Screen.h>
#include "Tests.h"

#include <iostream>
#include <codecvt>

using namespace nc::term;
#define PREFIX "nc::term::Interpreter "

const static std::pair<const char *, const char *> g_SimpleCases[] = {
    // clang-format off
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
    },
    {
        "\x1B[3;10r\x1B[?6h\x1B[2;5HA",
        "          "
        "          "
        "          "
        "    A     "
        "          "
        "          "
    },
    {
        "\x1B[1;10HA\x08 a",
        "         a"
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "\x1B[2;3rA\r\nB\r\nC\r\nD",
        "A         "
        "C         "
        "D         "
        "          "
        "          "
        "          "
    },
    {
        "\x1B[2;3r\x1B[5BA\r\nB",
        "          "
        "          "
        "          "
        "          "
        "          "
        "B         "
    },
    {
        "\x1B[2;3r\x1B[4BA\r\nB",
        "          "
        "          "
        "          "
        "          "
        "A         "
        "B         "
    },
    {
        "\x1B[2;3r\x1B[4BA\r\nB\r\nC",
        "          "
        "          "
        "          "
        "          "
        "A         "
        "C         "
    },
    {
        "\x1B[?6h\x1B[1;2r\x1B[24BA",
        "          "
        "A         "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\r\nB\r\nC\r\nD\r\nE\r\nF\x1B[1;1H\x1B[L",
        "          "
        "A         "
        "B         "
        "C         "
        "D         "
        "E         "
    },
    {
        "A\r\nB\r\nC\r\nD\r\nE\r\nF\x1B[1;1H\x1B[L\x1B[M",
        "A         "
        "B         "
        "C         "
        "D         "
        "E         "
        "          "
    },
    {
        "A\r\nB\r\nC\r\nD\r\nE\r\nF\x1B[2;5r\x1B[1;1H\x1B[L",
        "A         "
        "B         "
        "C         "
        "D         "
        "E         "
        "F         "
    },
    {
        "A\r\nB\r\nC\r\nD\r\nE\r\nF\x1B[2;4r\x1B[5;1H\x1B[L",
        "A         "
        "B         "
        "C         "
        "D         "
        "E         "
        "F         "
    },
    {
        "A\r\nB\r\nC\r\nD\r\nE\r\nF\x1B[2;4r\x1B[2;1H\x1B[L",
        "A         "
        "          "
        "B         "
        "C         "
        "E         "
        "F         "
    },
    {
        "A\r\nB\r\nC\r\nD\r\nE\r\nF\x1B[2;4r\x1B[4;1H\x1B[L",
        "A         "
        "B         "
        "C         "
        "          "
        "E         "
        "F         "
    },
    {
        "A\x08\x1b[@D",
        "DA        "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x08\x1b[2@",
        "  A       "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x08\x1b[9@",
        "         A"
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x08\x1b[10@",
        "          "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x1b[?47hBBB",
        "BBB       "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x1b[?47hBBBBBBB\x1b[?47lC",
        "AC        "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x1b[?47hBB\x1b[?47lC\x1b[?47hD",
        "DB        "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "AAAA\x1b[?1049hBB\x1b[?1049lC",
        "AAAAC     "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "A\x1b[?1049hBB\x1b[?1049lC\x1b[?1049hD",
        "D         "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    {
        "AAAA\x1b[3D\x1b[2XB",
        "AB A      "
        "          "
        "          "
        "          "
        "          "
        "          "
    },
    // clang-format on
};

const static std::pair<const char *, const char *> g_ResponseCases[] = {
    // clang-format off
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
    {
        "\x1B[3;10r\x1B[2;5HA\x1B[6n",
        "\033[2;6R"
    },
    {
        "\x1B[3;10r\x1B[?6h\x1B[2;5HA\x1B[6n",
        "\033[2;6R"
    },
    {
        "\x1B[1;10HA\x1B[6n",
        "\033[1;10R"
    },
    {
        "\x1B[1;10HA\x08\x1B[6n",
        "\033[1;9R"
    },
    {
        "\x1B[3;4r\n\x1BM\x1B[6n",
        "\033[1;1R"
    },
    {
        "\x1B[2;4r\n\x1BM\x1B[6n",
        "\033[2;1R"
    },
    {
        "\x1B[?6h\x1B[2;3r\x1BM\x1B[6n",
        "\033[1;1R"
    },
    {
        "\x1B[2;3r\n\n\n\x1B[6n",
        "\033[3;1R"
    },
    // clang-format on
};

// 10x6 screen
const static std::pair<const char8_t *, const char32_t *> g_UTFCases[] = {
    // clang-format off
    {    u8"\xD0\xB5\xCC\x88", // ё, non-composed
          U"\x435\x308         "
           "          "
           "          "
           "          "
           "          "
           "          "
    }, { u8"\xD0\xB5\xCC\x88\xCC\xB6", // ё̶, non-composed and crossed
          U"\x435\x308\x336         "
           "          "
           "          "
           "          "
           "          "
           "          "
    }, { u8"\x1B""[10G""\xD0\xB5\xCC\x88\xCC\xB6", // ESC[10Gё̶
          U"         \x435\x308\x336"
           "          "
           "          "
           "          "
           "          "
           "          "
    }, { u8"\x1B""[6;10H""\xD0\xB5\xCC\x88\xCC\xB6", // ESC[6;10HGё̶
          U"          "
           "          "
           "          "
           "          "
           "          "
           "         \x435\x308\x336"
    }, { u8"🧜🏾‍♀️",
          U"🧜🏾‍♀️        "
           "          "
           "          "
           "          "
           "          "
           "          "
    }, { u8"🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️",
          U"🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️"
           "          "
           "          "
           "          "
           "          "
           "          "
    }, { u8"0123456789🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️",
          U"0123456789"
           "🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️"
           "          "
           "          "
           "          "
           "          "
    }, { u8"0123456789🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️",
          U"0123456789"
           "🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️"
           "🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️"
           "          "
           "          "
           "          "
    }, { u8"0123456789👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻",
          U"0123456789"
           "👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦"
           "👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻👩🏻‍❤️‍👩🏻"
           "          "
           "          "
           "          "
    }, { u8"0123456789🇬🇧🇬🇧🇬🇧🇬🇧🇬🇧0123456789🦄🦄🦄🦄🦄0123456789☀️☀️☀️☀️☀️",
          U"0123456789"
           "🇬🇧🇬🇧🇬🇧🇬🇧🇬🇧"
           "0123456789"
           "🦄🦄🦄🦄🦄"
           "0123456789"
           "☀️☀️☀️☀️☀️"
    }, { u8"0123456789☁️  ☀️  ⛅️0☁️ ☀️ ⛅️9❄️🌨☁️🌦☁️0123456789",
          U"0123456789"
           "☁️  ☀️  ⛅️"
           "0☁️ ☀️ ⛅️9"
           "❄️🌨☁️🌦☁️"
           "0123456789"
           "          "
    }, { u8"Zalgo     Z̷a̸l̴g̴o̶     Z̸̬͂ą̶̈́ľ̴͖ǧ̷̗o̶͇̒     Ź̸̫̞͝ä̴͓́͜l̸̟̈̊g̶̬̅͒ō̴̮     Z̴̠̓̄a̸͇̼͎͐̈́̽l̸͈̱̼̋̌g̷͈̩͑͂̐o̶̢̯̺̔     Z̸̛͈̩͎̉͗á̶̱̟͍͘l̷͎̒͐ͅg̷̨̩̥͓̾͛͐o̸̺̾͌͠     ",
          U"Zalgo     "
           "Z̷a̸l̴g̴o̶     "
           "Z̸̬͂ą̶̈́ľ̴͖ǧ̷̗o̶͇̒     "
           "Ź̸̫̞͝ä̴͓́͜l̸̟̈̊g̶̬̅͒ō̴̮     "
           "Z̴̠̓̄a̸͇̼͎͐̈́̽l̸͈̱̼̋̌g̷͈̩͑͂̐o̶̢̯̺̔     "
           "Z̸̛͈̩͎̉͗á̶̱̟͍͘l̷͎̒͐ͅg̷̨̩̥͓̾͛͐o̸̺̾͌͠     "
    }
    // clang-format on
};

static Parser::Bytes Bytes(const char *_string) noexcept
{
    const auto view = std::string_view{_string};
    return {reinterpret_cast<const std::byte *>(view.data()), view.length()};
}

[[maybe_unused]] static void Print(const std::span<const input::Command> &_commands)
{
    for( auto &cmd : _commands )
        std::cout << input::VerboseDescription(cmd) << "\n";
    std::cout << '\n';
}

[[maybe_unused]] static std::string ToUTF8(const std::u32string &str)
{
    std::wstring_convert<std::codecvt_utf8<char32_t>, char32_t> conv;
    return conv.to_bytes(str);
}

static void Expect(const ScreenBuffer &buffer,
                   const int line_no,
                   const int x_begin,
                   const int x_end,
                   const ScreenBuffer::Space expected_sp)
{
    const auto line = buffer.LineFromNo(line_no);
    REQUIRE(!line.empty());
    REQUIRE(static_cast<long>(line.size()) >= x_end);
    for( auto it = line.begin() + x_begin; it != line.begin() + x_end; ++it ) {
        const auto space = *it;
        CHECK(space.foreground == expected_sp.foreground);
        CHECK(space.background == expected_sp.background);
        CHECK(space.faint == expected_sp.faint);
        CHECK(space.underline == expected_sp.underline);
        CHECK(space.reverse == expected_sp.reverse);
        CHECK(space.bold == expected_sp.bold);
        CHECK(space.italic == expected_sp.italic);
        CHECK(space.invisible == expected_sp.invisible);
        CHECK(space.blink == expected_sp.blink);
    }
}

TEST_CASE(PREFIX "Simple cases")
{
    for( auto test_case : g_SimpleCases ) {
        ParserImpl parser;
        Screen screen(10, 6);
        InterpreterImpl interpreter(screen);

        INFO(test_case.first);
        const auto input_bytes =
            Parser::Bytes(reinterpret_cast<const std::byte *>(test_case.first), strlen(test_case.first));
        interpreter.Interpret(parser.Parse(input_bytes));

        const auto result = screen.Buffer().DumpScreenAsANSI();
        const auto expectation = test_case.second;
        CHECK(result == expectation);
    }
}

TEST_CASE(PREFIX "Response cases")
{
    for( auto test_case : g_ResponseCases ) {
        ParserImpl parser;
        Screen screen(10, 6);
        InterpreterImpl interpreter(screen);

        std::string response;
        interpreter.SetOuput([&](Interpreter::Bytes _bytes) {
            if( not _bytes.empty() )
                response.append(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
        });

        const auto input_bytes =
            Parser::Bytes(reinterpret_cast<const std::byte *>(test_case.first), strlen(test_case.first));
        interpreter.Interpret(parser.Parse(input_bytes));

        const auto expectation = test_case.second;
        CHECK(response == expectation);
    }
}

TEST_CASE(PREFIX "UTF cases")
{
    for( auto test_case : g_UTFCases ) {
        ParserImpl parser;
        Screen screen(10, 6);
        InterpreterImpl interpreter(screen);

        const auto input = std::u8string_view{test_case.first};
        const auto input_bytes = Parser::Bytes(reinterpret_cast<const std::byte *>(input.data()), input.length());
        interpreter.Interpret(parser.Parse(input_bytes));

        const auto result = screen.Buffer().DumpScreenAsUTF32();
        const auto expectation = std::u32string(test_case.second);
        INFO(reinterpret_cast<const char *>(test_case.first));
        CHECK(result == expectation);
    }
}

TEST_CASE(PREFIX "vttest(1.1) - test of cursor movements, "
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
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D\x1B[23;79H+\x1B[1D\x1BM+\x1B[1D\x1BM+"
        "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+"
        "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+"
        "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM\x1B[2;1H*"
        "\x1B[2;80H*\x1B[10D\x1B"
        "E*\x1B[3;80H*\x1B[10D\x1B"
        "E*\x1B[4;80H*\x1B[10D\x1B"
        "E*\x1B[5;80H*"
        "\x1B[10D\x1B"
        "E*\x1B[6;80H*\x1B[10D\x1B"
        "E*\x1B[7;80H*\x1B[10D\x1B"
        "E*\x1B[8;80H*\x1B[10D"
        "\x1B"
        "E*\x1B[9;80H*\x1B[10D\x1B"
        "E*\x1B[10;80H*\x1B[10D\x0D\x0A*\x1B[11;80H*\x1B[10D\x0D\x0A*"
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
        // clang-format off
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
    "********************************************************************************";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

// ^^^ buggy!!! with a larger screen!

TEST_CASE(PREFIX "vttest(1.2) - test of cursor movements, "
                 "Test zero movements, display alignment, display erase, line erase")
{
    const auto raw_input =
        "\x1B[?3h\x1B#8\x1B[9;36H\x1B[1J\x1B[18;86H\x1B[0J\x1B[1K\x1B[9;97H\x1B[0K\x1B[10;36H\x1B[1K"
        "\x1B[10;97H\x1B[0K\x1B[11;36H\x1B[1K\x1B[11;97H\x1B[0K\x1B[12;36H\x1B[1K\x1B[12;97H\x1B[0K"
        "\x1B[13;36H\x1B[1K\x1B[13;97H\x1B[0K\x1B[14;36H\x1B[1K\x1B[14;97H\x1B[0K\x1B[15;36H\x1B[1K"
        "\x1B[15;97H\x1B[0K\x1B[16;36H\x1B[1K\x1B[16;97H\x1B[0K\x1B[17;30H\x1B[2K\x1B[24;1f*\x1B[1;1f*"
        "\x1B[24;2f*\x1B[1;2f*\x1B[24;3f*\x1B[1;3f*\x1B[24;4f*\x1B[1;4f*\x1B[24;5f*\x1B[1;5f*\x1B[24;6f"
        "*\x1B[1;6f*\x1B[24;7f*\x1B[1;7f*\x1B[24;8f*\x1B[1;8f*\x1B[24;9f*\x1B[1;9f*\x1B[24;10f*"
        "\x1B[1;10f*\x1B[24;11f*\x1B[1;11f*\x1B[24;12f*\x1B[1;12f*\x1B[24;13f*\x1B[1;13f*\x1B[24;14f*"
        "\x1B[1;14f*\x1B[24;15f*\x1B[1;15f*\x1B[24;16f*\x1B[1;16f*\x1B[24;17f*\x1B[1;17f*\x1B[24;18f*"
        "\x1B[1;18f*\x1B[24;19f*\x1B[1;19f*\x1B[24;20f*\x1B[1;20f*\x1B[24;21f*\x1B[1;21f*\x1B[24;22f*"
        "\x1B[1;22f*\x1B[24;23f*\x1B[1;23f*\x1B[24;24f*\x1B[1;24f*\x1B[24;25f*\x1B[1;25f*\x1B[24;26f*"
        "\x1B[1;26f*\x1B[24;27f*\x1B[1;27f*\x1B[24;28f*\x1B[1;28f*\x1B[24;29f*\x1B[1;29f*\x1B[24;30f*"
        "\x1B[1;30f*\x1B[24;31f*\x1B[1;31f*\x1B[24;32f*\x1B[1;32f*\x1B[24;33f*\x1B[1;33f*\x1B[24;34f*"
        "\x1B[1;34f*\x1B[24;35f*\x1B[1;35f*\x1B[24;36f*\x1B[1;36f*\x1B[24;37f*\x1B[1;37f*\x1B[24;38f*"
        "\x1B[1;38f*\x1B[24;39f*\x1B[1;39f*\x1B[24;40f*\x1B[1;40f*\x1B[24;41f*\x1B[1;41f*\x1B[24;42f*"
        "\x1B[1;42f*\x1B[24;43f*\x1B[1;43f*\x1B[24;44f*\x1B[1;44f*\x1B[24;45f*\x1B[1;45f*\x1B[24;46f*"
        "\x1B[1;46f*\x1B[24;47f*\x1B[1;47f*\x1B[24;48f*\x1B[1;48f*\x1B[24;49f*\x1B[1;49f*\x1B[24;50f*"
        "\x1B[1;50f*\x1B[24;51f*\x1B[1;51f*\x1B[24;52f*\x1B[1;52f*\x1B[24;53f*\x1B[1;53f*\x1B[24;54f*"
        "\x1B[1;54f*\x1B[24;55f*\x1B[1;55f*\x1B[24;56f*\x1B[1;56f*\x1B[24;57f*\x1B[1;57f*\x1B[24;58f*"
        "\x1B[1;58f*\x1B[24;59f*\x1B[1;59f*\x1B[24;60f*\x1B[1;60f*\x1B[24;61f*\x1B[1;61f*\x1B[24;62f*"
        "\x1B[1;62f*\x1B[24;63f*\x1B[1;63f*\x1B[24;64f*\x1B[1;64f*\x1B[24;65f*\x1B[1;65f*\x1B[24;66f*"
        "\x1B[1;66f*\x1B[24;67f*\x1B[1;67f*\x1B[24;68f*\x1B[1;68f*\x1B[24;69f*\x1B[1;69f*\x1B[24;70f*"
        "\x1B[1;70f*\x1B[24;71f*\x1B[1;71f*\x1B[24;72f*\x1B[1;72f*\x1B[24;73f*\x1B[1;73f*\x1B[24;74f*"
        "\x1B[1;74f*\x1B[24;75f*\x1B[1;75f*\x1B[24;76f*\x1B[1;76f*\x1B[24;77f*\x1B[1;77f*\x1B[24;78f*"
        "\x1B[1;78f*\x1B[24;79f*\x1B[1;79f*\x1B[24;80f*\x1B[1;80f*\x1B[24;81f*\x1B[1;81f*\x1B[24;82f*"
        "\x1B[1;82f*\x1B[24;83f*\x1B[1;83f*\x1B[24;84f*\x1B[1;84f*\x1B[24;85f*\x1B[1;85f*\x1B[24;86f*"
        "\x1B[1;86f*\x1B[24;87f*\x1B[1;87f*\x1B[24;88f*\x1B[1;88f*\x1B[24;89f*\x1B[1;89f*\x1B[24;90f*"
        "\x1B[1;90f*\x1B[24;91f*\x1B[1;91f*\x1B[24;92f*\x1B[1;92f*\x1B[24;93f*\x1B[1;93f*\x1B[24;94f*"
        "\x1B[1;94f*\x1B[24;95f*\x1B[1;95f*\x1B[24;96f*\x1B[1;96f*\x1B[24;97f*\x1B[1;97f*\x1B[24;98f*"
        "\x1B[1;98f*\x1B[24;99f*\x1B[1;99f*\x1B[24;100f*\x1B[1;100f*\x1B[24;101f*\x1B[1;101f*"
        "\x1B[24;102f*\x1B[1;102f*\x1B[24;103f*\x1B[1;103f*\x1B[24;104f*\x1B[1;104f*\x1B[24;105f*"
        "\x1B[1;105f*\x1B[24;106f*\x1B[1;106f*\x1B[24;107f*\x1B[1;107f*\x1B[24;108f*\x1B[1;108f*"
        "\x1B[24;109f*\x1B[1;109f*\x1B[24;110f*\x1B[1;110f*\x1B[24;111f*\x1B[1;111f*\x1B[24;112f*"
        "\x1B[1;112f*\x1B[24;113f*\x1B[1;113f*\x1B[24;114f*\x1B[1;114f*\x1B[24;115f*\x1B[1;115f*"
        "\x1B[24;116f*\x1B[1;116f*\x1B[24;117f*\x1B[1;117f*\x1B[24;118f*\x1B[1;118f*\x1B[24;119f*"
        "\x1B[1;119f*\x1B[24;120f*\x1B[1;120f*\x1B[24;121f*\x1B[1;121f*\x1B[24;122f*\x1B[1;122f*"
        "\x1B[24;123f*\x1B[1;123f*\x1B[24;124f*\x1B[1;124f*\x1B[24;125f*\x1B[1;125f*\x1B[24;126f*"
        "\x1B[1;126f*\x1B[24;127f*\x1B[1;127f*\x1B[24;128f*\x1B[1;128f*\x1B[24;129f*\x1B[1;129f*"
        "\x1B[24;130f*\x1B[1;130f*\x1B[24;131f*\x1B[1;131f*\x1B[24;132f*\x1B[1;132f*\x1B[2;2H+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D"
        "\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D+\x1B[1D\x1B"
        "D\x1B[23;131H+\x1B[1D\x1BM+\x1B[1D\x1BM+"
        "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+"
        "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+"
        "\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM+\x1B[1D\x1BM\x1B[2;1H*"
        "\x1B[2;132H*\x1B[10D\x1B"
        "E*\x1B[3;132H*\x1B[10D\x1B"
        "E*\x1B[4;132H*\x1B[10D\x1B"
        "E*"
        "\x1B[5;132H*\x1B[10D\x1B"
        "E*\x1B[6;132H*\x1B[10D\x1B"
        "E*\x1B[7;132H*\x1B[10D\x1B"
        "E*"
        "\x1B[8;132H*\x1B[10D\x1B"
        "E*\x1B[9;132H*\x1B[10D\x1B"
        "E*\x1B[10;132H*\x1B[10D\x0D\x0A*"
        "\x1B[11;132H*\x1B[10D\x0D\x0A*\x1B[12;132H*\x1B[10D\x0D\x0A*\x1B[13;132H*\x1B[10D\x0D\x0A*"
        "\x1B[14;132H*\x1B[10D\x0D\x0A*\x1B[15;132H*\x1B[10D\x0D\x0A*\x1B[16;132H*\x1B[10D\x0D\x0A*"
        "\x1B[17;132H*\x1B[10D\x0D\x0A*\x1B[18;132H*\x1B[10D\x0D\x0A*\x1B[19;132H*\x1B[10D\x0D\x0A*"
        "\x1B[20;132H*\x1B[10D\x0D\x0A*\x1B[21;132H*\x1B[10D\x0D\x0A*\x1B[22;132H*\x1B[10D\x0D\x0A*"
        "\x1B[23;132H*\x1B[10D\x0D\x0A\x1B[2;10H\x1B[68D\x1B[2C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D"
        "\x1B[1C+\x1B[0C\x1B[2D\x1B[1C+\x1B[0C\x1B[2D\x1B[1C\x1B[23;96H\x1B[68C\x1B[2D+\x1B[1D\x1B[1C"
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
        "\x1B[0D\x08+\x1B[1D\x1B[1C\x1B[0D\x08\x1B[1;1H\x1B[10A\x1B[1A\x1B[0A\x1B[24;132H\x1B[10B"
        "\x1B[1B\x1B[0B\x1B[10;38H                                                          \x1B[1B"
        "\x1B[58D                                                          \x1B[1B\x1B[58D"
        "                                                          \x1B[1B\x1B[58D"
        "                                                          \x1B[1B\x1B[58D"
        "                                                          \x1B[1B\x1B[58D"
        "                                                          \x1B[1B\x1B[58D"
        "\x1B[5A\x1B[1CThe screen should be cleared,  and have an unbroken bor-\x1B[12;39Hder of *'s"
        " and +'s around the edge,   and exactly in the\x1B[13;39Hmiddle  there should be a frame of"
        " E's around this  text\x1B[14;39Hwith  one (1) free position around it.    Push <RETURN>";

    const auto expectation =
        // clang-format off
    "************************************************************************************************************************************"
    "*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                  EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE                                  +*"
    "*+                                  E                                                          E                                  +*"
    "*+                                  E The screen should be cleared,  and have an unbroken bor- E                                  +*"
    "*+                                  E der of *'s and +'s around the edge,   and exactly in the E                                  +*"
    "*+                                  E middle  there should be a frame of E's around this  text E                                  +*"
    "*+                                  E with  one (1) free position around it.    Push <RETURN>  E                                  +*"
    "*+                                  E                                                          E                                  +*"
    "*+                                  EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE                                  +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*+                                                                                                                                +*"
    "*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*"
    "************************************************************************************************************************************";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

// ^^^ buggy!!! with a larger screen!

TEST_CASE(PREFIX "vttest(1.3) - test of cursor movements, "
                 "autowrap, mixing control and print characters")
{
    const auto raw_input =
        "\x1B[?3l\x1B[?3lTest of autowrap, mixing control and print characters."
        "\x0D\x0D\x0AThe left/right margins should have letters in order:\x0D\x0D\x0A\x1B[3;21r"
        "\x1B[?6h\x1B[19;1HA\x1B[19;80Ha\x0D\x0A\x1B[18;80HaB\x1B[19;80HB\x08 b"
        "\x0D\x0A\x1B[19;80HC\x08\x08\x09\x09"
        "c\x1B[19;2H\x08"
        "C\x0D\x0A"
        "\x1B[19;80H\x0D\x0A\x1B[18;1HD\x1B[18;80Hd\x1B[19;1HE\x1B[19;80He\x0D\x0A\x1B[18;80HeF"
        "\x1B[19;80HF\x08 f\x0D\x0A\x1B[19;80HG\x08\x08\x09\x09g\x1B[19;2H\x08G\x0D\x0A\x1B[19;80H"
        "\x0D\x0A\x1B[18;1HH\x1B[18;80Hh\x1B[19;1HI\x1B[19;80Hi\x0D\x0A\x1B[18;80HiJ\x1B[19;80HJ\x08 j"
        "\x0D\x0A\x1B[19;80HK\x08\x08\x09\x09k\x1B[19;2H\x08K\x0D\x0A\x1B[19;80H\x0D\x0A\x1B[18;1HL"
        "\x1B[18;80Hl\x1B[19;1HM\x1B[19;80Hm\x0D\x0A\x1B[18;80HmN\x1B[19;80HN\x08 n\x0D\x0A\x1B[19;80HO"
        "\x08\x08\x09\x09o\x1B[19;2H\x08O\x0D\x0A\x1B[19;80H\x0D\x0A\x1B[18;1HP\x1B[18;80Hp\x1B[19;1HQ"
        "\x1B[19;80Hq\x0D\x0A\x1B[18;80HqR\x1B[19;80HR\x08 r\x0D\x0A\x1B[19;80HS\x08\x08\x09\x09s"
        "\x1B[19;2H\x08S\x0D\x0A\x1B[19;80H\x0D\x0A\x1B[18;1HT\x1B[18;80Ht\x1B[19;1HU\x1B[19;80Hu"
        "\x0D\x0A\x1B[18;80HuV\x1B[19;80HV\x08 v\x0D\x0A\x1B[19;80HW\x08\x08\x09\x09w\x1B[19;2H\x08W"
        "\x0D\x0A\x1B[19;80H\x0D\x0A\x1B[18;1HX\x1B[18;80Hx\x1B[19;1HY\x1B[19;80Hy\x0D\x0A\x1B[18;80Hy"
        "Z\x1B[19;80HZ\x08 z\x0D\x0A\x1B[?6l\x1B[r\x1B[22;1HPush <RETURN>";

    const auto expectation =
        // clang-format off
    "Test of autowrap, mixing control and print characters.                          "
    "The left/right margins should have letters in order:                            "
    "I                                                                              i"
    "J                                                                              j"
    "K                                                                              k"
    "L                                                                              l"
    "M                                                                              m"
    "N                                                                              n"
    "O                                                                              o"
    "P                                                                              p"
    "Q                                                                              q"
    "R                                                                              r"
    "S                                                                              s"
    "T                                                                              t"
    "U                                                                              u"
    "V                                                                              v"
    "W                                                                              w"
    "X                                                                              x"
    "Y                                                                              y"
    "Z                                                                              z"
    "                                                                                "
    "Push <RETURN>                                                                   "
    "                                                                                "
    "                                                                                ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

// ^^^ buggy!!! with a larger screen!

TEST_CASE(PREFIX "vttest(1.4) - test of cursor movements, "
                 "autowrap, mixing control and print characters")
{
    const auto raw_input =
        "\x1B[?3hTest of autowrap, mixing control and print characters.\x0D\x0D\x0AThe left/right "
        "margins should have letters in order:\x0D\x0D\x0A\x1B[3;21r\x1B[?6h\x1B[19;1HA\x1B[19;132H"
        "a\x0D\x0A\x1B[18;132HaB\x1B[19;132HB\x08 b\x0D\x0A\x1B[19;132HC\x08\x08\x09\x09c\x1B[19;2H"
        "\x08C\x0D\x0A\x1B[19;132H\x0D\x0A\x1B[18;1HD\x1B[18;132Hd\x1B[19;1HE\x1B[19;132He\x0D\x0A"
        "\x1B[18;132HeF\x1B[19;132HF\x08 f\x0D\x0A\x1B[19;132HG\x08\x08\x09\x09g\x1B[19;2H\x08G\x0D"
        "\x0A\x1B[19;132H\x0D\x0A\x1B[18;1HH\x1B[18;132Hh\x1B[19;1HI\x1B[19;132Hi\x0D\x0A\x1B[18;132H"
        "iJ\x1B[19;132HJ\x08 j\x0D\x0A\x1B[19;132HK\x08\x08\x09\x09k\x1B[19;2H\x08K\x0D\x0A"
        "\x1B[19;132H\x0D\x0A\x1B[18;1HL\x1B[18;132Hl\x1B[19;1HM\x1B[19;132Hm\x0D\x0A\x1B[18;132HmN"
        "\x1B[19;132HN\x08 n\x0D\x0A\x1B[19;132HO\x08\x08\x09\x09o\x1B[19;2H\x08O\x0D\x0A\x1B[19;132H"
        "\x0D\x0A\x1B[18;1HP\x1B[18;132Hp\x1B[19;1HQ\x1B[19;132Hq\x0D\x0A\x1B[18;132HqR\x1B[19;132H"
        "R\x08 r\x0D\x0A\x1B[19;132HS\x08\x08\x09\x09s\x1B[19;2H\x08S\x0D\x0A\x1B[19;132H\x0D\x0A"
        "\x1B[18;1HT\x1B[18;132Ht\x1B[19;1HU\x1B[19;132Hu\x0D\x0A\x1B[18;132HuV\x1B[19;132HV\x08 v"
        "\x0D\x0A\x1B[19;132HW\x08\x08\x09\x09w\x1B[19;2H\x08W\x0D\x0A\x1B[19;132H\x0D\x0A\x1B[18;1H"
        "X\x1B[18;132Hx\x1B[19;1HY\x1B[19;132Hy\x0D\x0A\x1B[18;132HyZ\x1B[19;132HZ\x08 z\x0D\x0A"
        "\x1B[?6l\x1B[r\x1B[22;1HPush <RETURN>";

    const auto expectation =
        // clang-format off
    "Test of autowrap, mixing control and print characters.                                                                              "
    "The left/right margins should have letters in order:                                                                                "
    "I                                                                                                                                  i"
    "J                                                                                                                                  j"
    "K                                                                                                                                  k"
    "L                                                                                                                                  l"
    "M                                                                                                                                  m"
    "N                                                                                                                                  n"
    "O                                                                                                                                  o"
    "P                                                                                                                                  p"
    "Q                                                                                                                                  q"
    "R                                                                                                                                  r"
    "S                                                                                                                                  s"
    "T                                                                                                                                  t"
    "U                                                                                                                                  u"
    "V                                                                                                                                  v"
    "W                                                                                                                                  w"
    "X                                                                                                                                  x"
    "Y                                                                                                                                  y"
    "Z                                                                                                                                  z"
    "                                                                                                                                    "
    "Push <RETURN>                                                                                                                       "
    "                                                                                                                                    "
    "                                                                                                                                    ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

// ^^^ buggy!!! with a larger screen!

TEST_CASE(PREFIX "vttest(1.5) - test of cursor movements, "
                 "Test of cursor-control characters inside ESC sequences.")
{
    const auto raw_input = "\x1B[?3l\x1B[2J\x1B[1;1HTest of cursor-control characters inside ESC sequences."
                           "\x0D\x0D\x0A"
                           "Below should be four identical lines:\x0D\x0D\x0A\x0D\x0D\x0A"
                           "A B C D E F G H I"
                           "\x0D\x0D\x0A"
                           "A\x1B[2\x08"
                           "CB\x1B[2\x08"
                           "CC\x1B[2\x08"
                           "CD\x1B[2\x08"
                           "CE\x1B[2\x08"
                           "CF\x1B[2\x08"
                           "CG\x1B[2\x08"
                           "CH\x1B[2\x08"
                           "CI"
                           "\x1B[2\x08"
                           "C\x0D\x0D\x0A"
                           "A \x1B[\x0D"
                           "2CB\x1B[\x0D"
                           "4CC\x1B[\x0D"
                           "6CD\x1B[\x0D"
                           "8CE\x1B[\x0D"
                           "10CF\x1B[\x0D"
                           "12CG\x1B[\x0D"
                           "14CH\x1B[\x0D"
                           "16CI"
                           "\x0D\x0D\x0A\x1B[20lA \x1B[1\x0B"
                           "AB \x1B[1\x0B"
                           "AC \x1B[1\x0B"
                           "AD \x1B[1\x0B"
                           "AE \x1B[1\x0B"
                           "AF \x1B[1\x0B"
                           "AG \x1B[1\x0B"
                           "AH \x1B[1\x0B"
                           "AI"
                           " \x1B[1\x0BA\x0D\x0D\x0A\x0D\x0D\x0A"
                           "Push <RETURN>";

    const auto expectation =
        // clang-format off
    "Test of cursor-control characters inside ESC sequences.                         "
    "Below should be four identical lines:                                           "
    "                                                                                "
    "A B C D E F G H I                                                               "
    "A B C D E F G H I                                                               "
    "A B C D E F G H I                                                               "
    "A B C D E F G H I                                                               "
    "                                                                                "
    "Push <RETURN>                                                                   ";
    // clang-format on

    ParserImpl parser;
    Screen screen(60, 9);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(1.6) - test of cursor movements, "
                 "Test of leading zeros in ESC sequences.")
{
    const auto raw_input = "\x1B[2J\x1B[1;1HTest of leading zeros in ESC sequences.\x0D\x0D\x0A"
                           "Two lines below you should see the sentence \"This is a correct sentence\"."
                           "\x1B[00000000004;000000001HT\x1B[00000000004;000000002Hh\x1B[00000000004;000000003Hi\x1B["
                           "00000000004;000000004Hs"
                           "\x1B[00000000004;000000005H "
                           "\x1B[00000000004;000000006Hi\x1B[00000000004;000000007Hs\x1B[00000000004;000000008H "
                           "\x1B[00000000004;000000009Ha\x1B[00000000004;0000000010H "
                           "\x1B[00000000004;0000000011Hc\x1B[00000000004;0000000012Ho"
                           "\x1B[00000000004;0000000013Hr\x1B[00000000004;0000000014Hr\x1B[00000000004;"
                           "0000000015He\x1B[00000000004;0000000016Hc"
                           "\x1B[00000000004;0000000017Ht\x1B[00000000004;0000000018H "
                           "\x1B[00000000004;0000000019Hs\x1B[00000000004;0000000020He"
                           "\x1B[00000000004;0000000021Hn\x1B[00000000004;0000000022Ht\x1B[00000000004;"
                           "0000000023He\x1B[00000000004;0000000024Hn"
                           "\x1B[00000000004;0000000025Hc\x1B[00000000004;0000000026He\x1B[20;1H"
                           "Push <RETURN>";

    const auto expectation =
        // clang-format off
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
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 20);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(2.1) - test of WRAP AROUND mode setting")
{
    const auto raw_input =
        "\x0D\x0A\x1B[2J"
        "\x1B[1;1H\x1B[?7h***************************************************************************"
        "*************************************************************************************\x1B[?7l"
        "\x1B[3;1H************************************************************************************"
        "****************************************************************************\x1B[?7h\x1B[5;1H"
        "This should be three identical lines of *'s completely filling\x0D\x0D\x0Athe top of the "
        "screen without any empty lines between.\x0D\x0D\x0A(Test of WRAP AROUND mode setting.)"
        "\x0D\x0D\x0APush <RETURN>";

    const auto expectation =
        // clang-format off
    "********************************************************************************"
    "********************************************************************************"
    "********************************************************************************"
    "                                                                                "
    "This should be three identical lines of *'s completely filling                  "
    "the top of the screen without any empty lines between.                          "
    "(Test of WRAP AROUND mode setting.)                                             "
    "Push <RETURN>                                                                   ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 8);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(2.2) - Test of TAB setting/resetting")
{
    const auto raw_input = "\x1B[2J\x1B[3g\x1B[1;1H\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C"
                           "\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C"
                           "\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C"
                           "\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[3C\x1BH\x1B[1;4H"
                           "\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C"
                           "\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C\x1B[0g\x1B[6C"
                           "\x1B[0g\x1B[6C\x1B[1;7H\x1B[1g\x1B[2g\x1B[1;1H"
                           "\x09*\x09*\x09*\x09*\x09*\x09*\x09*\x09*\x09*\x09*\x09*\x09*\x09*"
                           "\x1B[2;2H     *     *     *     *     *     *     *     *     *     *     *     *     *"
                           "\x1B[4;1HTest of TAB setting/resetting. These two lines\x0D\x0D\x0Ashould look the same. "
                           "Push <RETURN>";

    const auto expectation =
        // clang-format off
    "      *     *     *     *     *     *     *     *     *     *     *     *     * "
    "      *     *     *     *     *     *     *     *     *     *     *     *     * "
    "                                                                                "
    "Test of TAB setting/resetting. These two lines                                  "
    "should look the same. Push <RETURN>                                             ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 5);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(2.3) - 132 column / video reverse")
{
    const auto raw_input =
        "\x1B[?5h\x1B[?3h\x1B[2J\x1B[1;1H\x1B[3g\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C"
        "\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH"
        "\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[1;1H12345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901\x1B[3;3HThis is 132 column mode, light background.\x1B[4;4HThis is 132 "
        "column mode, light background.\x1B[5;5HThis is 132 column mode, light background.\x1B[6;6HThis"
        " is 132 column mode, light background.\x1B[7;7HThis is 132 column mode, light background."
        "\x1B[8;8HThis is 132 column mode, light background.\x1B[9;9HThis is 132 column mode, light "
        "background.\x1B[10;10HThis is 132 column mode, light background.\x1B[11;11HThis is 132 column "
        "mode, light background.\x1B[12;12HThis is 132 column mode, light background.\x1B[13;13HThis "
        "is 132 column mode, light background.\x1B[14;14HThis is 132 column mode, light background."
        "\x1B[15;15HThis is 132 column mode, light background.\x1B[16;16HThis is 132 column mode, light"
        " background.\x1B[17;17HThis is 132 column mode, light background.\x1B[18;18HThis is 132 column"
        " mode, light background.\x1B[19;19HThis is 132 column mode, light background.\x1B[20;20HThis "
        "is 132 column mode, light background.Push <RETURN>";

    const auto expectation =
        // clang-format off
    "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901 "
    "                                                                                                                                    "
    "  This is 132 column mode, light background.                                                                                        "
    "   This is 132 column mode, light background.                                                                                       "
    "    This is 132 column mode, light background.                                                                                      "
    "     This is 132 column mode, light background.                                                                                     "
    "      This is 132 column mode, light background.                                                                                    "
    "       This is 132 column mode, light background.                                                                                   "
    "        This is 132 column mode, light background.                                                                                  "
    "         This is 132 column mode, light background.                                                                                 "
    "          This is 132 column mode, light background.                                                                                "
    "           This is 132 column mode, light background.                                                                               "
    "            This is 132 column mode, light background.                                                                              "
    "             This is 132 column mode, light background.                                                                             "
    "              This is 132 column mode, light background.                                                                            "
    "               This is 132 column mode, light background.                                                                           "
    "                This is 132 column mode, light background.                                                                          "
    "                 This is 132 column mode, light background.                                                                         "
    "                  This is 132 column mode, light background.                                                                        "
    "                   This is 132 column mode, light background.Push <RETURN>                                                          ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 20);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == true);
}

TEST_CASE(PREFIX "vttest(2.4) - 80 column / video reverse")
{
    const auto raw_input =
        "\x1B[?5h\x1B[?3l\x1B[2J\x1B[1;1H12345678901234567890123456789012345678901234567890123456789012"
        "34567890123456789\x1B[3;3HThis is 80 column mode, light background.\x1B[4;4HThis is 80 column "
        "mode, light background.\x1B[5;5HThis is 80 column mode, light background.\x1B[6;6HThis is 80 "
        "column mode, light background.\x1B[7;7HThis is 80 column mode, light background.\x1B[8;8HThis"
        " is 80 column mode, light background.\x1B[9;9HThis is 80 column mode, light background."
        "\x1B[10;10HThis is 80 column mode, light background.\x1B[11;11HThis is 80 column mode, light "
        "background.\x1B[12;12HThis is 80 column mode, light background.\x1B[13;13HThis is 80 column "
        "mode, light background.\x1B[14;14HThis is 80 column mode, light background.\x1B[15;15HThis is"
        " 80 column mode, light background.\x1B[16;16HThis is 80 column mode, light background."
        "\x1B[17;17HThis is 80 column mode, light background.\x1B[18;18HThis is 80 column mode, light "
        "background.\x1B[19;19HThis is 80 column mode, light background.\x1B[20;20HThis is 80 column "
        "mode, light background.Push <RETURN>";

    const auto expectation =
        // clang-format off
    "1234567890123456789012345678901234567890123456789012345678901234567890123456789 "
    "                                                                                "
    "  This is 80 column mode, light background.                                     "
    "   This is 80 column mode, light background.                                    "
    "    This is 80 column mode, light background.                                   "
    "     This is 80 column mode, light background.                                  "
    "      This is 80 column mode, light background.                                 "
    "       This is 80 column mode, light background.                                "
    "        This is 80 column mode, light background.                               "
    "         This is 80 column mode, light background.                              "
    "          This is 80 column mode, light background.                             "
    "           This is 80 column mode, light background.                            "
    "            This is 80 column mode, light background.                           "
    "             This is 80 column mode, light background.                          "
    "              This is 80 column mode, light background.                         "
    "               This is 80 column mode, light background.                        "
    "                This is 80 column mode, light background.                       "
    "                 This is 80 column mode, light background.                      "
    "                  This is 80 column mode, light background.                     "
    "                   This is 80 column mode, light background.Push <RETURN>       ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 20);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == true);
}

TEST_CASE(PREFIX "vttest(2.5) - 132 column / no video reverse")
{
    const auto raw_input =
        "\x1B[?5l\x1B[?3h\x1B[2J\x1B[1;1H\x1B[3g\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C"
        "\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH"
        "\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[8C\x1BH\x1B[1;1H1234567890123456789012345"
        "6789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
        "012345678901\x1B[3;3HThis is 132 column mode, dark background.\x1B[4;4HThis is 132 column mode"
        ", dark background.\x1B[5;5HThis is 132 column mode, dark background.\x1B[6;6HThis is 132 "
        "column mode, dark background.\x1B[7;7HThis is 132 column mode, dark background.\x1B[8;8HThis "
        "is 132 column mode, dark background.\x1B[9;9HThis is 132 column mode, dark background."
        "\x1B[10;10HThis is 132 column mode, dark background.\x1B[11;11HThis is 132 column mode, dark "
        "background.\x1B[12;12HThis is 132 column mode, dark background.\x1B[13;13HThis is 132 column "
        "mode, dark background.\x1B[14;14HThis is 132 column mode, dark background.\x1B[15;15HThis is "
        "132 column mode, dark background.\x1B[16;16HThis is 132 column mode, dark background."
        "\x1B[17;17HThis is 132 column mode, dark background.\x1B[18;18HThis is 132 column mode, dark "
        "background.\x1B[19;19HThis is 132 column mode, dark background.\x1B[20;20HThis is 132 column "
        "mode, dark background.Push <RETURN>";

    const auto expectation =
        // clang-format off
    "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901 "
    "                                                                                                                                    "
    "  This is 132 column mode, dark background.                                                                                         "
    "   This is 132 column mode, dark background.                                                                                        "
    "    This is 132 column mode, dark background.                                                                                       "
    "     This is 132 column mode, dark background.                                                                                      "
    "      This is 132 column mode, dark background.                                                                                     "
    "       This is 132 column mode, dark background.                                                                                    "
    "        This is 132 column mode, dark background.                                                                                   "
    "         This is 132 column mode, dark background.                                                                                  "
    "          This is 132 column mode, dark background.                                                                                 "
    "           This is 132 column mode, dark background.                                                                                "
    "            This is 132 column mode, dark background.                                                                               "
    "             This is 132 column mode, dark background.                                                                              "
    "              This is 132 column mode, dark background.                                                                             "
    "               This is 132 column mode, dark background.                                                                            "
    "                This is 132 column mode, dark background.                                                                           "
    "                 This is 132 column mode, dark background.                                                                          "
    "                  This is 132 column mode, dark background.                                                                         "
    "                   This is 132 column mode, dark background.Push <RETURN>                                                           ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 20);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.6) - 80 column / no video reverse")
{
    const auto raw_input =
        "\x1B[?5l\x1B[?3l\x1B[2J\x1B[1;1H12345678901234567890123456789012345678901234567890123456789012"
        "34567890123456789\x1B[3;3HThis is 80 column mode, dark background.\x1B[4;4HThis is 80 column "
        "mode, dark background.\x1B[5;5HThis is 80 column mode, dark background.\x1B[6;6HThis is 80 "
        "column mode, dark background.\x1B[7;7HThis is 80 column mode, dark background.\x1B[8;8HThis is"
        " 80 column mode, dark background.\x1B[9;9HThis is 80 column mode, dark background.\x1B[10;10H"
        "This is 80 column mode, dark background.\x1B[11;11HThis is 80 column mode, dark background."
        "\x1B[12;12HThis is 80 column mode, dark background.\x1B[13;13HThis is 80 column mode, dark "
        "background.\x1B[14;14HThis is 80 column mode, dark background.\x1B[15;15HThis is 80 column "
        "mode, dark background.\x1B[16;16HThis is 80 column mode, dark background.\x1B[17;17HThis is 80"
        " column mode, dark background.\x1B[18;18HThis is 80 column mode, dark background.\x1B[19;19H"
        "This is 80 column mode, dark background.\x1B[20;20HThis is 80 column mode, dark background."
        "Push <RETURN>";

    const auto expectation =
        // clang-format off
    "1234567890123456789012345678901234567890123456789012345678901234567890123456789 "
    "                                                                                "
    "  This is 80 column mode, dark background.                                      "
    "   This is 80 column mode, dark background.                                     "
    "    This is 80 column mode, dark background.                                    "
    "     This is 80 column mode, dark background.                                   "
    "      This is 80 column mode, dark background.                                  "
    "       This is 80 column mode, dark background.                                 "
    "        This is 80 column mode, dark background.                                "
    "         This is 80 column mode, dark background.                               "
    "          This is 80 column mode, dark background.                              "
    "           This is 80 column mode, dark background.                             "
    "            This is 80 column mode, dark background.                            "
    "             This is 80 column mode, dark background.                           "
    "              This is 80 column mode, dark background.                          "
    "               This is 80 column mode, dark background.                         "
    "                This is 80 column mode, dark background.                        "
    "                 This is 80 column mode, dark background.                       "
    "                  This is 80 column mode, dark background.                      "
    "                   This is 80 column mode, dark background.Push <RETURN>        ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 20);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.7) - soft scroll")
{
    const auto raw_input =
        "\x1B[2J\x1B[?6h\x1B[?4h\x1B[12;13r\x1B[2J\x1B[24BSoft scroll up region [12..13] size 2 Line 1"
        "\x0D\x0ASoft scroll up region [12..13] size 2 Line 2\x0D\x0ASoft scroll up region [12..13] "
        "size 2 Line 3\x0D\x0ASoft scroll up region [12..13] size 2 Line 4\x0D\x0ASoft scroll up region"
        " [12..13] size 2 Line 5\x0D\x0ASoft scroll up region [12..13] size 2 Line 6\x0D\x0ASoft scroll"
        " up region [12..13] size 2 Line 7\x0D\x0ASoft scroll up region [12..13] size 2 Line 8\x0D\x0A"
        "Soft scroll up region [12..13] size 2 Line 9\x0D\x0ASoft scroll up region [12..13] size 2 Line"
        " 10\x0D\x0ASoft scroll up region [12..13] size 2 Line 11\x0D\x0ASoft scroll up region [12..13]"
        " size 2 Line 12\x0D\x0ASoft scroll up region [12..13] size 2 Line 13\x0D\x0ASoft scroll up "
        "region [12..13] size 2 Line 14\x0D\x0ASoft scroll up region [12..13] size 2 Line 15\x0D\x0A"
        "Soft scroll up region [12..13] size 2 Line 16\x0D\x0ASoft scroll up region [12..13] size 2 "
        "Line 17\x0D\x0ASoft scroll up region [12..13] size 2 Line 18\x0D\x0ASoft scroll up region "
        "[12..13] size 2 Line 19\x0D\x0ASoft scroll up region [12..13] size 2 Line 20\x0D\x0ASoft "
        "scroll up region [12..13] size 2 Line 21\x0D\x0ASoft scroll up region [12..13] size 2 Line 22"
        "\x0D\x0ASoft scroll up region [12..13] size 2 Line 23\x0D\x0ASoft scroll up region [12..13] "
        "size 2 Line 24\x0D\x0ASoft scroll up region [12..13] size 2 Line 25\x0D\x0ASoft scroll up "
        "region [12..13] size 2 Line 26\x0D\x0ASoft scroll up region [12..13] size 2 Line 27\x0D\x0A"
        "Soft scroll up region [12..13] size 2 Line 28\x0D\x0ASoft scroll up region [12..13] size 2 "
        "Line 29\x0D\x0A\x1B[24ASoft scroll down region [12..13] size 2 Line 1\x0D\x0A\x1BM\x1BMSoft "
        "scroll down region [12..13] size 2 Line 2\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] "
        "size 2 Line 3\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 4\x0D\x0A\x1BM"
        "\x1BMSoft scroll down region [12..13] size 2 Line 5\x0D\x0A\x1BM\x1BMSoft scroll down region "
        "[12..13] size 2 Line 6\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 7\x0D\x0A"
        "\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 8\x0D\x0A\x1BM\x1BMSoft scroll down "
        "region [12..13] size 2 Line 9\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 10"
        "\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 11\x0D\x0A\x1BM\x1BMSoft scroll"
        " down region [12..13] size 2 Line 12\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2"
        " Line 13\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 14\x0D\x0A\x1BM\x1BMSo"
        "ft scroll down region [12..13] size 2 Line 15\x0D\x0A\x1BM\x1BMSoft scroll down region "
        "[12..13] size 2 Line 16\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 17"
        "\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 18\x0D\x0A\x1BM\x1BMSoft scroll"
        " down region [12..13] size 2 Line 19\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2"
        " Line 20\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 21\x0D\x0A\x1BM\x1BM"
        "Soft scroll down region [12..13] size 2 Line 22\x0D\x0A\x1BM\x1BMSoft scroll down region "
        "[12..13] size 2 Line 23\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 24"
        "\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 25\x0D\x0A\x1BM\x1BMSoft scroll"
        " down region [12..13] size 2 Line 26\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2"
        " Line 27\x0D\x0A\x1BM\x1BMSoft scroll down region [12..13] size 2 Line 28\x0D\x0A\x1BM\x1BM"
        "Soft scroll down region [12..13] size 2 Line 29\x0D\x0A\x1BM\x1BMPush <RETURN>";

    const auto expectation =
        // clang-format off
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
    "Push <RETURN>                                                                   "
    "Soft scroll down region [12..13] size 2 Line 29                                 ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 13);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.8) - soft scroll")
{
    const auto raw_input =
        "\x1B[?4h"
        "\x1B[?6h\x1B[1;24r\x1B[2J\x1B[24BSoft scroll up region [1..24] size 24 Line 1\x0D\x0ASoft "
        "scroll up region [1..24] size 24 Line 2\x0D\x0ASoft scroll up region [1..24] size 24 Line 3"
        "\x0D\x0ASoft scroll up region [1..24] size 24 Line 4\x0D\x0ASoft scroll up region [1..24] size"
        " 24 Line 5\x0D\x0ASoft scroll up region [1..24] size 24 Line 6\x0D\x0ASoft scroll up region "
        "[1..24] size 24 Line 7\x0D\x0ASoft scroll up region [1..24] size 24 Line 8\x0D\x0ASoft scroll "
        "up region [1..24] size 24 Line 9\x0D\x0ASoft scroll up region [1..24] size 24 Line 10\x0D\x0A"
        "Soft scroll up region [1..24] size 24 Line 11\x0D\x0ASoft scroll up region [1..24] size 24 "
        "Line 12\x0D\x0ASoft scroll up region [1..24] size 24 Line 13\x0D\x0ASoft scroll up region "
        "[1..24] size 24 Line 14\x0D\x0ASoft scroll up region [1..24] size 24 Line 15\x0D\x0ASoft "
        "scroll up region [1..24] size 24 Line 16\x0D\x0ASoft scroll up region [1..24] size 24 Line "
        "17\x0D\x0ASoft scroll up region [1..24] size 24 Line 18\x0D\x0ASoft scroll up region [1..24] "
        "size 24 Line 19\x0D\x0ASoft scroll up region [1..24] size 24 Line 20\x0D\x0ASoft scroll up "
        "region [1..24] size 24 Line 21\x0D\x0ASoft scroll up region [1..24] size 24 Line 22\x0D\x0A"
        "Soft scroll up region [1..24] size 24 Line 23\x0D\x0ASoft scroll up region [1..24] size 24 "
        "Line 24\x0D\x0ASoft scroll up region [1..24] size 24 Line 25\x0D\x0ASoft scroll up region "
        "[1..24] size 24 Line 26\x0D\x0ASoft scroll up region [1..24] size 24 Line 27\x0D\x0ASoft "
        "scroll up region [1..24] size 24 Line 28\x0D\x0ASoft scroll up region [1..24] size 24 Line "
        "29\x0D\x0A\x1B[24ASoft scroll down region [1..24] size 24 Line 1\x0D\x0A\x1BM\x1BMSoft scroll"
        " down region [1..24] size 24 Line 2\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 "
        "Line 3\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 4\x0D\x0A\x1BM\x1BMSoft "
        "scroll down region [1..24] size 24 Line 5\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] "
        "size 24 Line 6\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 7\x0D\x0A\x1BM"
        "\x1BMSoft scroll down region [1..24] size 24 Line 8\x0D\x0A\x1BM\x1BMSoft scroll down region "
        "[1..24] size 24 Line 9\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 10\x0D"
        "\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 11\x0D\x0A\x1BM\x1BMSoft scroll "
        "down region [1..24] size 24 Line 12\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 "
        "Line 13\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 14\x0D\x0A\x1BM\x1BMSoft"
        " scroll down region [1..24] size 24 Line 15\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] "
        "size 24 Line 16\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 17\x0D\x0A\x1BM"
        "\x1BMSoft scroll down region [1..24] size 24 Line 18\x0D\x0A\x1BM\x1BMSoft scroll down region"
        " [1..24] size 24 Line 19\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 20\x0D"
        "\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 21\x0D\x0A\x1BM\x1BMSoft scroll "
        "down region [1..24] size 24 Line 22\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 "
        "Line 23\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 24\x0D\x0A\x1BM\x1BMSoft"
        " scroll down region [1..24] size 24 Line 25\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] "
        "size 24 Line 26\x0D\x0A\x1BM\x1BMSoft scroll down region [1..24] size 24 Line 27\x0D\x0A\x1BM"
        "\x1BMSoft scroll down region [1..24] size 24 Line 28\x0D\x0A\x1BM\x1BMSoft scroll down region"
        " [1..24] size 24 Line 29\x0D\x0A\x1BM\x1BMPush <RETURN>";

    const auto expectation =
        // clang-format off
    "Push <RETURN>                                                                   "
    "Soft scroll down region [1..24] size 24 Line 29                                 "
    "Soft scroll down region [1..24] size 24 Line 28                                 "
    "Soft scroll down region [1..24] size 24 Line 27                                 "
    "Soft scroll down region [1..24] size 24 Line 26                                 "
    "Soft scroll down region [1..24] size 24 Line 25                                 "
    "Soft scroll down region [1..24] size 24 Line 24                                 "
    "Soft scroll down region [1..24] size 24 Line 23                                 "
    "Soft scroll down region [1..24] size 24 Line 22                                 "
    "Soft scroll down region [1..24] size 24 Line 21                                 "
    "Soft scroll down region [1..24] size 24 Line 20                                 "
    "Soft scroll down region [1..24] size 24 Line 19                                 "
    "Soft scroll down region [1..24] size 24 Line 18                                 "
    "Soft scroll down region [1..24] size 24 Line 17                                 "
    "Soft scroll down region [1..24] size 24 Line 16                                 "
    "Soft scroll down region [1..24] size 24 Line 15                                 "
    "Soft scroll down region [1..24] size 24 Line 14                                 "
    "Soft scroll down region [1..24] size 24 Line 13                                 "
    "Soft scroll down region [1..24] size 24 Line 12                                 "
    "Soft scroll down region [1..24] size 24 Line 11                                 "
    "Soft scroll down region [1..24] size 24 Line 10                                 "
    "Soft scroll down region [1..24] size 24 Line 9                                  "
    "Soft scroll down region [1..24] size 24 Line 8                                  "
    "Soft scroll down region [1..24] size 24 Line 7                                  ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.9) - jump scroll")
{
    const auto raw_input =
        "\x1B[?6h\x1B[?4l\x1B[12;13r\x1B[2J\x1B[24BJump scroll up region [12..13] size 2 Line 1\x0D\x0A"
        "Jump scroll up region [12..13] size 2 Line 2\x0D\x0AJump scroll up region [12..13] size 2 Line"
        " 3\x0D\x0AJump scroll up region [12..13] size 2 Line 4\x0D\x0AJump scroll up region [12..13] "
        "size 2 Line 5\x0D\x0AJump scroll up region [12..13] size 2 Line 6\x0D\x0AJump scroll up region"
        " [12..13] size 2 Line 7\x0D\x0AJump scroll up region [12..13] size 2 Line 8\x0D\x0AJump scroll"
        " up region [12..13] size 2 Line 9\x0D\x0AJump scroll up region [12..13] size 2 Line 10\x0D\x0A"
        "Jump scroll up region [12..13] size 2 Line 11\x0D\x0AJump scroll up region [12..13] size 2 "
        "Line 12\x0D\x0AJump scroll up region [12..13] size 2 Line 13\x0D\x0AJump scroll up region "
        "[12..13] size 2 Line 14\x0D\x0AJump scroll up region [12..13] size 2 Line 15\x0D\x0AJump "
        "scroll up region [12..13] size 2 Line 16\x0D\x0AJump scroll up region [12..13] size 2 Line 17"
        "\x0D\x0AJump scroll up region [12..13] size 2 Line 18\x0D\x0AJump scroll up region [12..13] "
        "size 2 Line 19\x0D\x0AJump scroll up region [12..13] size 2 Line 20\x0D\x0AJump scroll up "
        "region [12..13] size 2 Line 21\x0D\x0AJump scroll up region [12..13] size 2 Line 22\x0D\x0A"
        "Jump scroll up region [12..13] size 2 Line 23\x0D\x0AJump scroll up region [12..13] size 2 "
        "Line 24\x0D\x0AJump scroll up region [12..13] size 2 Line 25\x0D\x0AJump scroll up region "
        "[12..13] size 2 Line 26\x0D\x0AJump scroll up region [12..13] size 2 Line 27\x0D\x0AJump "
        "scroll up region [12..13] size 2 Line 28\x0D\x0AJump scroll up region [12..13] size 2 Line 29"
        "\x0D\x0A\x1B[24AJump scroll down region [12..13] size 2 Line 1\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [12..13] size 2 Line 2\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 "
        "Line 3\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 4\x0D\x0A\x1BM\x1BMJump "
        "scroll down region [12..13] size 2 Line 5\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] "
        "size 2 Line 6\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 7\x0D\x0A\x1BM"
        "\x1BMJump scroll down region [12..13] size 2 Line 8\x0D\x0A\x1BM\x1BMJump scroll down region "
        "[12..13] size 2 Line 9\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 10\x0D"
        "\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 11\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [12..13] size 2 Line 12\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 "
        "Line 13\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 14\x0D\x0A\x1BM\x1BM"
        "Jump scroll down region [12..13] size 2 Line 15\x0D\x0A\x1BM\x1BMJump scroll down region "
        "[12..13] size 2 Line 16\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 17\x0D"
        "\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 18\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [12..13] size 2 Line 19\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 "
        "Line 20\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 21\x0D\x0A\x1BM\x1BMJump"
        " scroll down region [12..13] size 2 Line 22\x0D\x0A\x1BM\x1BMJump scroll down region [12..13]"
        " size 2 Line 23\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 24\x0D\x0A\x1BM"
        "\x1BMJump scroll down region [12..13] size 2 Line 25\x0D\x0A\x1BM\x1BMJump scroll down region"
        " [12..13] size 2 Line 26\x0D\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 27\x0D"
        "\x0A\x1BM\x1BMJump scroll down region [12..13] size 2 Line 28\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [12..13] size 2 Line 29\x0D\x0A\x1BM\x1BMPush <RETURN>";

    const auto expectation =
        // clang-format off
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
    "Push <RETURN>                                                                   "
    "Jump scroll down region [12..13] size 2 Line 29                                 ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 13);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.10) - jump scroll")
{
    const auto raw_input =
        "\x1B[?6h\x1B[1;24r\x1B[2J\x1B[24BJump scroll up region [1..24] size 24 Line 1\x0D\x0AJump "
        "scroll up region [1..24] size 24 Line 2\x0D\x0AJump scroll up region [1..24] size 24 Line 3"
        "\x0D\x0AJump scroll up region [1..24] size 24 Line 4\x0D\x0AJump scroll up region [1..24] size"
        " 24 Line 5\x0D\x0AJump scroll up region [1..24] size 24 Line 6\x0D\x0AJump scroll up region "
        "[1..24] size 24 Line 7\x0D\x0AJump scroll up region [1..24] size 24 Line 8\x0D\x0AJump scroll"
        " up region [1..24] size 24 Line 9\x0D\x0AJump scroll up region [1..24] size 24 Line 10\x0D\x0A"
        "Jump scroll up region [1..24] size 24 Line 11\x0D\x0AJump scroll up region [1..24] size 24 "
        "Line 12\x0D\x0AJump scroll up region [1..24] size 24 Line 13\x0D\x0AJump scroll up region "
        "[1..24] size 24 Line 14\x0D\x0AJump scroll up region [1..24] size 24 Line 15\x0D\x0AJump "
        "scroll up region [1..24] size 24 Line 16\x0D\x0AJump scroll up region [1..24] size 24 Line 17"
        "\x0D\x0AJump scroll up region [1..24] size 24 Line 18\x0D\x0AJump scroll up region [1..24] "
        "size 24 Line 19\x0D\x0AJump scroll up region [1..24] size 24 Line 20\x0D\x0AJump scroll up "
        "region [1..24] size 24 Line 21\x0D\x0AJump scroll up region [1..24] size 24 Line 22\x0D\x0A"
        "Jump scroll up region [1..24] size 24 Line 23\x0D\x0AJump scroll up region [1..24] size 24 "
        "Line 24\x0D\x0AJump scroll up region [1..24] size 24 Line 25\x0D\x0AJump scroll up region "
        "[1..24] size 24 Line 26\x0D\x0AJump scroll up region [1..24] size 24 Line 27\x0D\x0AJump "
        "scroll up region [1..24] size 24 Line 28\x0D\x0AJump scroll up region [1..24] size 24 Line "
        "29\x0D\x0A\x1B[24AJump scroll down region [1..24] size 24 Line 1\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [1..24] size 24 Line 2\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 "
        "Line 3\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 4\x0D\x0A\x1BM\x1BMJump "
        "scroll down region [1..24] size 24 Line 5\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] "
        "size 24 Line 6\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 7\x0D\x0A\x1BM"
        "\x1BMJump scroll down region [1..24] size 24 Line 8\x0D\x0A\x1BM\x1BMJump scroll down region "
        "[1..24] size 24 Line 9\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 10\x0D"
        "\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 11\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [1..24] size 24 Line 12\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 "
        "Line 13\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 14\x0D\x0A\x1BM\x1BMJump"
        " scroll down region [1..24] size 24 Line 15\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] "
        "size 24 Line 16\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 17\x0D\x0A\x1BM"
        "\x1BMJump scroll down region [1..24] size 24 Line 18\x0D\x0A\x1BM\x1BMJump scroll down region "
        "[1..24] size 24 Line 19\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 20\x0D"
        "\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 21\x0D\x0A\x1BM\x1BMJump scroll "
        "down region [1..24] size 24 Line 22\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 "
        "Line 23\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 24\x0D\x0A\x1BM\x1BMJump"
        " scroll down region [1..24] size 24 Line 25\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] "
        "size 24 Line 26\x0D\x0A\x1BM\x1BMJump scroll down region [1..24] size 24 Line 27\x0D\x0A\x1BM"
        "\x1BMJump scroll down region [1..24] size 24 Line 28\x0D\x0A\x1BM\x1BMJump scroll down region "
        "[1..24] size 24 Line 29\x0D\x0A\x1BM\x1BMPush <RETURN>";

    const auto expectation =
        // clang-format off
    "Push <RETURN>                                                                   "
    "Jump scroll down region [1..24] size 24 Line 29                                 "
    "Jump scroll down region [1..24] size 24 Line 28                                 "
    "Jump scroll down region [1..24] size 24 Line 27                                 "
    "Jump scroll down region [1..24] size 24 Line 26                                 "
    "Jump scroll down region [1..24] size 24 Line 25                                 "
    "Jump scroll down region [1..24] size 24 Line 24                                 "
    "Jump scroll down region [1..24] size 24 Line 23                                 "
    "Jump scroll down region [1..24] size 24 Line 22                                 "
    "Jump scroll down region [1..24] size 24 Line 21                                 "
    "Jump scroll down region [1..24] size 24 Line 20                                 "
    "Jump scroll down region [1..24] size 24 Line 19                                 "
    "Jump scroll down region [1..24] size 24 Line 18                                 "
    "Jump scroll down region [1..24] size 24 Line 17                                 "
    "Jump scroll down region [1..24] size 24 Line 16                                 "
    "Jump scroll down region [1..24] size 24 Line 15                                 "
    "Jump scroll down region [1..24] size 24 Line 14                                 "
    "Jump scroll down region [1..24] size 24 Line 13                                 "
    "Jump scroll down region [1..24] size 24 Line 12                                 "
    "Jump scroll down region [1..24] size 24 Line 11                                 "
    "Jump scroll down region [1..24] size 24 Line 10                                 "
    "Jump scroll down region [1..24] size 24 Line 9                                  "
    "Jump scroll down region [1..24] size 24 Line 8                                  "
    "Jump scroll down region [1..24] size 24 Line 7                                  ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.11) - origin mode test")
{
    const auto raw_input =
        "\x1B[?6h\x1B[2J\x1B[23;24r\x0D\x0AOrigin mode test. This line should be at the bottom of the "
        "screen.\x1B[1;1HThis line should be the one above the bottom of the screen. Push <RETURN>";

    const auto expectation =
        // clang-format off
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
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "This line should be the one above the bottom of the screen. Push <RETURN>       "
    "Origin mode test. This line should be at the bottom of the screen.              ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.12) - origin mode test")
{
    const auto raw_input = "\x1B[2J\x1B[?6l\x1B[24;1HOrigin mode test. This line should be at the bottom of the screen."
                           "\x1B[1;1HThis line should be at the top of the screen. Push <RETURN>";

    const auto expectation =
        // clang-format off
    "This line should be at the top of the screen. Push <RETURN>                     "
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
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "Origin mode test. This line should be at the bottom of the screen.              ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);
}

TEST_CASE(PREFIX "vttest(2.13) - Graphic rendition test pattern / dark background")
{
    const auto raw_input =
        "\x1B[1;24r\x1B[2J\x1B[1;20HGraphic rendition test pattern:\x1B[4;1H\x1B[0mvanilla\x1B[4;40H"
        "\x1B[0;1mbold\x1B[6;6H\x1B[;4munderline\x1B[6;45H\x1B[;1m\x1B[4mbold underline\x1B[8;1H"
        "\x1B[0;5mblink\x1B[8;40H\x1B[0;5;1mbold blink\x1B[10;6H\x1B[0;4;5munderline blink\x1B[10;45H"
        "\x1B[0;1;4;5mbold underline blink\x1B[12;1H\x1B[1;4;5;0;7mnegative\x1B[12;40H\x1B[0;1;7m"
        "bold negative\x1B[14;6H\x1B[0;4;7munderline negative\x1B[14;45H\x1B[0;1;4;7mbold underline "
        "negative\x1B[16;1H\x1B[1;4;;5;7mblink negative\x1B[16;40H\x1B[0;1;5;7mbold blink negative"
        "\x1B[18;6H\x1B[0;4;5;7munderline blink negative\x1B[18;45H\x1B[0;1;4;5;7mbold underline blink "
        "negative\x1B[m\x1B[?5l\x1B[23;1H\x1B[0KDark background. Push <RETURN>";

    const auto expectation =
        // clang-format off
    "                   Graphic rendition test pattern:                              "
    "                                                                                "
    "                                                                                "
    "vanilla                                bold                                     "
    "                                                                                "
    "     underline                              bold underline                      "
    "                                                                                "
    "blink                                  bold blink                               "
    "                                                                                "
    "     underline blink                        bold underline blink                "
    "                                                                                "
    "negative                               bold negative                            "
    "                                                                                "
    "     underline negative                     bold underline negative             "
    "                                                                                "
    "blink negative                         bold blink negative                      "
    "                                                                                "
    "     underline blink negative               bold underline blink negative       "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "Dark background. Push <RETURN>                                                  "
    "                                                                                ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    const ScreenBuffer &buffer = screen.Buffer();
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == false);

    ScreenBuffer::Space sp = ScreenBuffer::DefaultEraseChar();
    Expect(buffer, 3, 0, 7, sp);

    sp.underline = true;
    Expect(buffer, 5, 5, 14, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 7, 0, 5, sp);

    sp.underline = true;
    Expect(buffer, 9, 5, 20, sp);

    sp.blink = false;
    sp.underline = false;
    sp.reverse = true;
    Expect(buffer, 11, 0, 8, sp);

    sp.underline = true;
    Expect(buffer, 13, 5, 23, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 15, 0, 14, sp);

    sp.underline = true;
    Expect(buffer, 17, 5, 29, sp);

    sp.underline = false;
    sp.blink = false;
    sp.reverse = false;
    sp.bold = true;
    Expect(buffer, 3, 39, 43, sp);

    sp.underline = true;
    Expect(buffer, 5, 44, 58, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 7, 39, 49, sp);

    sp.underline = true;
    Expect(buffer, 9, 44, 64, sp);

    sp.underline = false;
    sp.blink = false;
    sp.reverse = true;
    Expect(buffer, 11, 39, 52, sp);

    sp.underline = true;
    Expect(buffer, 13, 44, 67, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 15, 39, 58, sp);

    sp.underline = true;
    Expect(buffer, 17, 44, 73, sp);
}

TEST_CASE(PREFIX "vttest(2.14) - Graphic rendition test pattern / light background")
{
    const auto raw_input =
        "\x1B[1;24r\x1B[2J\x1B[1;20HGraphic rendition test pattern:\x1B[4;1H\x1B[0mvanilla\x1B[4;40H"
        "\x1B[0;1mbold\x1B[6;6H\x1B[;4munderline\x1B[6;45H\x1B[;1m\x1B[4mbold underline\x1B[8;1H"
        "\x1B[0;5mblink\x1B[8;40H\x1B[0;5;1mbold blink\x1B[10;6H\x1B[0;4;5munderline blink\x1B[10;45H"
        "\x1B[0;1;4;5mbold underline blink\x1B[12;1H\x1B[1;4;5;0;7mnegative\x1B[12;40H\x1B[0;1;7m"
        "bold negative\x1B[14;6H\x1B[0;4;7munderline negative\x1B[14;45H\x1B[0;1;4;7mbold underline "
        "negative\x1B[16;1H\x1B[1;4;;5;7mblink negative\x1B[16;40H\x1B[0;1;5;7mbold blink negative"
        "\x1B[18;6H\x1B[0;4;5;7munderline blink negative\x1B[18;45H\x1B[0;1;4;5;7mbold underline blink "
        "negative\x1B[m\x1B[?5l\x1B[23;1H\x1B[0KDark background. Push <RETURN>\x1B[?5h\x1B[23;1H\x1B[0K"
        "Light background. Push <RETURN>";

    const auto expectation =
        // clang-format off
    "                   Graphic rendition test pattern:                              "
    "                                                                                "
    "                                                                                "
    "vanilla                                bold                                     "
    "                                                                                "
    "     underline                              bold underline                      "
    "                                                                                "
    "blink                                  bold blink                               "
    "                                                                                "
    "     underline blink                        bold underline blink                "
    "                                                                                "
    "negative                               bold negative                            "
    "                                                                                "
    "     underline negative                     bold underline negative             "
    "                                                                                "
    "blink negative                         bold blink negative                      "
    "                                                                                "
    "     underline blink negative               bold underline blink negative       "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "Light background. Push <RETURN>                                                 "
    "                                                                                ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    const ScreenBuffer &buffer = screen.Buffer();
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
    CHECK(screen.VideoReverse() == true);

    ScreenBuffer::Space sp = ScreenBuffer::DefaultEraseChar();
    Expect(buffer, 3, 0, 7, sp);

    sp.underline = true;
    Expect(buffer, 5, 5, 14, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 7, 0, 5, sp);

    sp.underline = true;
    Expect(buffer, 9, 5, 20, sp);

    sp.blink = false;
    sp.underline = false;
    sp.reverse = true;
    Expect(buffer, 11, 0, 8, sp);

    sp.underline = true;
    Expect(buffer, 13, 5, 23, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 15, 0, 14, sp);

    sp.underline = true;
    Expect(buffer, 17, 5, 29, sp);

    sp.underline = false;
    sp.blink = false;
    sp.reverse = false;
    sp.bold = true;
    Expect(buffer, 3, 39, 43, sp);

    sp.underline = true;
    Expect(buffer, 5, 44, 58, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 7, 39, 49, sp);

    sp.underline = true;
    Expect(buffer, 9, 44, 64, sp);

    sp.underline = false;
    sp.blink = false;
    sp.reverse = true;
    Expect(buffer, 11, 39, 52, sp);

    sp.underline = true;
    Expect(buffer, 13, 44, 67, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 15, 39, 58, sp);

    sp.underline = true;
    Expect(buffer, 17, 44, 73, sp);
}

TEST_CASE(PREFIX "vttest(2.15) - Test of the SAVE/RESTORE CURSOR feature")
{
    const auto raw_input =
        "\x1B[?5l\x1B[2J\x1B[8;12Hnormal\x1B[8;24Hbold\x1B[8;36Hunderscored\x1B[8;48Hblinking\x1B[8;60H"
        "reversed\x1B[10;1Hstars:\x1B[12;1Hline:\x1B[14;1Hx'es:\x1B[16;1Hdiamonds:\x1B[10;12H\x1B[;0m"
        "\x1B(B\x1B)B\x0F*****\x1B"
        "7\x1B[1;1H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8*****\x1B[10;24H\x1B[;1m"
        "\x1B(B\x1B)B\x0F*****\x1B"
        "7\x1B[1;2H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8*****\x1B[10;36H\x1B[;4m"
        "\x1B(B\x1B)B\x0F*****\x1B"
        "7\x1B[1;3H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8*****\x1B[10;48H\x1B[;5m"
        "\x1B(B\x1B)B\x0F*****\x1B"
        "7\x1B[1;4H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8*****\x1B[10;60H\x1B[;7m"
        "\x1B(B\x1B)B\x0F*****\x1B"
        "7\x1B[1;5H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8*****\x1B[12;12H\x1B[;0m"
        "\x1B(0\x1B)B\x0Fqqqqq\x1B"
        "7\x1B[2;1H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8qqqqq\x1B[12;24H\x1B[;1m"
        "\x1B(0\x1B)B\x0Fqqqqq\x1B"
        "7\x1B[2;2H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8qqqqq\x1B[12;36H\x1B[;4m"
        "\x1B(0\x1B)B\x0Fqqqqq\x1B"
        "7\x1B[2;3H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8qqqqq\x1B[12;48H\x1B[;5m"
        "\x1B(0\x1B)B\x0Fqqqqq\x1B"
        "7\x1B[2;4H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8qqqqq\x1B[12;60H\x1B[;7m"
        "\x1B(0\x1B)B\x0Fqqqqq\x1B"
        "7\x1B[2;5H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8qqqqq\x1B[14;12H\x1B[;0m"
        "\x1B(B\x1B)B\x0Fxxxxx\x1B"
        "7\x1B[3;1H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8xxxxx\x1B[14;24H\x1B[;1m"
        "\x1B(B\x1B)B\x0Fxxxxx\x1B"
        "7\x1B[3;2H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8xxxxx\x1B[14;36H\x1B[;4m"
        "\x1B(B\x1B)B\x0Fxxxxx\x1B"
        "7\x1B[3;3H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8xxxxx\x1B[14;48H\x1B[;5m"
        "\x1B(B\x1B)B\x0Fxxxxx\x1B"
        "7\x1B[3;4H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8xxxxx\x1B[14;60H\x1B[;7m"
        "\x1B(B\x1B)B\x0Fxxxxx\x1B"
        "7\x1B[3;5H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8xxxxx\x1B[16;12H\x1B[;0m"
        "\x1B(0\x1B)B\x0F`````\x1B"
        "7\x1B[4;1H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8`````\x1B[16;24H\x1B[;1m"
        "\x1B(0\x1B)B\x0F`````\x1B"
        "7\x1B[4;2H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8`````\x1B[16;36H\x1B[;4m"
        "\x1B(0\x1B)B\x0F`````\x1B"
        "7\x1B[4;3H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8`````\x1B[16;48H\x1B[;5m"
        "\x1B(0\x1B)B\x0F`````\x1B"
        "7\x1B[4;4H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8`````\x1B[16;60H\x1B[;7m"
        "\x1B(0\x1B)B\x0F`````\x1B"
        "7\x1B[4;5H\x1B[m\x1B(B\x1B)B\x0F"
        "A\x1B"
        "8`````\x1B[0m\x1B(B\x1B)B"
        "\x0F\x1B[21;1HTest of the SAVE/RESTORE CURSOR feature. There should\x0D\x0D\x0A"
        "be ten "
        "characters of each flavour, and a rectangle\x0D\x0D\x0Aof 5 x 4 A's filling the top left of "
        "the screen.\x0D\x0D\x0APush <RETURN>";

    const auto expectation =
        // clang-format off
   U"AAAAA                                                                           "
    "AAAAA                                                                           "
    "AAAAA                                                                           "
    "AAAAA                                                                           "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "           normal      bold        underscored blinking    reversed             "
    "                                                                                "
    "stars:     **********  **********  **********  **********  **********           "
    "                                                                                "
    "line:      ──────────  ──────────  ──────────  ──────────  ──────────           "
    "                                                                                "
    "x'es:      xxxxxxxxxx  xxxxxxxxxx  xxxxxxxxxx  xxxxxxxxxx  xxxxxxxxxx           "
    "                                                                                "
    "diamonds:  ◆◆◆◆◆◆◆◆◆◆  ◆◆◆◆◆◆◆◆◆◆  ◆◆◆◆◆◆◆◆◆◆  ◆◆◆◆◆◆◆◆◆◆  ◆◆◆◆◆◆◆◆◆◆           "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "Test of the SAVE/RESTORE CURSOR feature. There should                           "
    "be ten characters of each flavour, and a rectangle                              "
    "of 5 x 4 A's filling the top left of the screen.                                "
    "Push <RETURN>                                                                   ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    const ScreenBuffer &buffer = screen.Buffer();
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsUTF32();

    CHECK(result == expectation);

    ScreenBuffer::Space sp = ScreenBuffer::DefaultEraseChar();
    Expect(buffer, 9, 11, 21, sp);
    Expect(buffer, 11, 11, 21, sp);
    Expect(buffer, 13, 11, 21, sp);
    Expect(buffer, 13, 11, 21, sp);

    sp.bold = true;
    Expect(buffer, 9, 23, 33, sp);
    Expect(buffer, 11, 23, 33, sp);
    Expect(buffer, 13, 23, 33, sp);
    Expect(buffer, 13, 23, 33, sp);

    sp.bold = false;
    sp.underline = true;
    Expect(buffer, 9, 35, 45, sp);
    Expect(buffer, 11, 35, 45, sp);
    Expect(buffer, 13, 35, 45, sp);
    Expect(buffer, 13, 35, 45, sp);

    sp.underline = false;
    sp.blink = true;
    Expect(buffer, 9, 47, 57, sp);
    Expect(buffer, 11, 47, 57, sp);
    Expect(buffer, 13, 47, 57, sp);
    Expect(buffer, 13, 47, 57, sp);

    sp.blink = false;
    sp.reverse = true;
    Expect(buffer, 9, 59, 69, sp);
    Expect(buffer, 11, 59, 69, sp);
    Expect(buffer, 13, 59, 69, sp);
    Expect(buffer, 13, 59, 69, sp);
}

TEST_CASE(PREFIX "vttest(3) - Test of character sets")
{
    const auto raw_input =
        "\x0D\x0A\x1B[2J\x1B[?42l\x1B(B\x1B)B\x1B*B\x1B+B\x1B[1;10HSelected as G0 (with SI)\x1B[1;48H"
        "Selected as G1 (with SO)\x1B)B\x1B(B\x0E\x1B[3;1H\x1B[1mCharacter set B (US ASCII)\x1B[0m"
        "\x1B(B\x1B)B\x0F\x1B[4;10H !\"#$%&'()*+,-./0123456789:;<=>?\x1B[5;10H@ABCDEFGHIJKLMNOPQRSTUVWX"
        "YZ[\\]^_\x1B[6;10H`abcdefghijklmnopqrstuvwxyz{|}~\x1B)B\x1B(B\x0E\x1B[4;48H !\"#$%&'()*+,-./01"
        "23456789:;<=>?\x1B[5;48H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\x1B[6;48H`abcdefghijklmnopqrstuvwxyz"
        "{|}~\x1B)B\x1B(B\x0E\x1B[7;1H\x1B[1mCharacter set A (British)\x1B[0m\x1B(A\x1B)B\x0F\x1B[8;10H"
        " !\"#$%&'()*+,-./0123456789:;<=>?\x1B[9;10H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\x1B[10;10H`abcdef"
        "ghijklmnopqrstuvwxyz{|}~\x1B)A\x1B(B\x0E\x1B[8;48H !\"#$%&'()*+,-./0123456789:;<=>?\x1B[9;48H@"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\x1B[10;48H`abcdefghijklmnopqrstuvwxyz{|}~\x1B)B\x1B(B\x0E\x1B"
        "[11;1H\x1B[1mCharacter set 0 (DEC Special graphics and line drawing)\x1B[0m\x1B(0\x1B)B\x0F"
        "\x1B[12;10H !\"#$%&'()*+,-./0123456789:;<=>?\x1B[13;10H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
        "\x1B[14;10H`abcdefghijklmnopqrstuvwxyz{|}~\x1B)0\x1B(B\x0E\x1B[12;48H !\"#$%&'()*+,-./01234567"
        "89:;<=>?\x1B[13;48H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\x1B[14;48H`abcdefghijklmnopqrstuvwxyz{|}~"
        "\x1B)B\x1B(B\x0E\x1B[15;1H\x1B[1mCharacter set 1 (DEC Alternate character ROM standard charact"
        "ers)\x1B[0m\x1B(1\x1B)B\x0F\x1B[16;10H !\"#$%&'()*+,-./0123456789:;<=>?\x1B[17;10H@ABCDEFGHIJK"
        "LMNOPQRSTUVWXYZ[\\]^_\x1B[18;10H`abcdefghijklmnopqrstuvwxyz{|}~\x1B)1\x1B(B\x0E\x1B[16;48H !\""
        "#$%&'()*+,-./0123456789:;<=>?\x1B[17;48H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\x1B[18;48H`abcdefghi"
        "jklmnopqrstuvwxyz{|}~\x1B)B\x1B(B\x0E\x1B[19;1H\x1B[1mCharacter set 2 (DEC Alternate character"
        " ROM special graphics)\x1B[0m\x1B(2\x1B)B\x0F\x1B[20;10H !\"#$%&'()*+,-./0123456789:;<=>?\x1B["
        "21;10H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\x1B[22;10H`abcdefghijklmnopqrstuvwxyz{|}~\x1B)2\x1B(B"
        "\x0E\x1B[20;48H !\"#$%&'()*+,-./0123456789:;<=>?\x1B[21;48H@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
        "\x1B[22;48H`abcdefghijklmnopqrstuvwxyz{|}~\x1B(B\x1B)B\x0F\x1B[24;1HThese are the installed "
        "character sets. Push <RETURN>";

    const auto expectation =
        // clang-format off
   U"         Selected as G0 (with SI)              Selected as G1 (with SO)         "
    "                                                                                "
    "Character set B (US ASCII)                                                      "
    "          !\"#$%&'()*+,-./0123456789:;<=>?       !\"#$%&'()*+,-./0123456789:;<=>? "
    "         @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_      @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ "
    "         `abcdefghijklmnopqrstuvwxyz{|}~       `abcdefghijklmnopqrstuvwxyz{|}~  "
    "Character set A (British)                                                       "
    "          !\"£$%&'()*+,-./0123456789:;<=>?       !\"£$%&'()*+,-./0123456789:;<=>? "
    "         @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_      @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ "
    "         `abcdefghijklmnopqrstuvwxyz{|}~       `abcdefghijklmnopqrstuvwxyz{|}~  "
    "Character set 0 (DEC Special graphics and line drawing)                         "
    "          !\"#$%&'()*+,-./0123456789:;<=>?       !\"#$%&'()*+,-./0123456789:;<=>? "
    "         @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^       @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^  "
    "         ◆▒␉␌␍␊°±␤␋┘┐┌└┼⎺⎻─⎼⎽├┤┴┬│≤≥π≠£·       ◆▒␉␌␍␊°±␤␋┘┐┌└┼⎺⎻─⎼⎽├┤┴┬│≤≥π≠£·  "
    "Character set 1 (DEC Alternate character ROM standard characters)               "
    "          !\"#$%&'()*+,-./0123456789:;<=>?       !\"#$%&'()*+,-./0123456789:;<=>? "
    "         @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_      @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ "
    "         `abcdefghijklmnopqrstuvwxyz{|}~       `abcdefghijklmnopqrstuvwxyz{|}~  "
    "Character set 2 (DEC Alternate character ROM special graphics)                  "
    "          !\"#$%&'()*+,-./0123456789:;<=>?       !\"#$%&'()*+,-./0123456789:;<=>? "
    "         @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^       @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^  "
    "         ◆▒␉␌␍␊°±␤␋┘┐┌└┼⎺⎻─⎼⎽├┤┴┬│≤≥π≠£·       ◆▒␉␌␍␊°±␤␋┘┐┌└┼⎺⎻─⎼⎽├┤┴┬│≤≥π≠£·  "
    "                                                                                "
    "These are the installed character sets. Push <RETURN>                           ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsUTF32();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(8.1) - Screen accordion test")
{
    const auto raw_input =
        "\x0D\x0A\x1B[2J\x1B[?3l\x1B[2J\x1B[1;1H\x1B[1;1HAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\x1B[2;1HBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBB\x1B[3;1HCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCC\x1B[4;1HDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
        "DDDDDDDDDDDDDDDDDDD\x1B[5;1HEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
        "EEEEEEEEEEEEEE\x1B[6;1HFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
        "FFFFFFFFF\x1B[7;1HGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"
        "GGGG\x1B[8;1HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH"
        "\x1B[9;1HIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"
        "\x1B[10;1HJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ"
        "\x1B[11;1HKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
        "\x1B[12;1HLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
        "\x1B[13;1HMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
        "\x1B[14;1HNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"
        "\x1B[15;1HOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO"
        "\x1B[16;1HPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP"
        "\x1B[17;1HQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ"
        "\x1B[18;1HRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"
        "\x1B[19;1HSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
        "\x1B[20;1HTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"
        "\x1B[21;1HUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU"
        "\x1B[22;1HVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
        "\x1B[23;1HWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
        "\x1B[24;1HXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        "\x1B[4;1HScreen accordion test (Insert & Delete Line). Push <RETURN>";

    const auto expectation =
        // clang-format off
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
    "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    "Screen accordion test (Insert & Delete Line). Push <RETURN>DDDDDDDDDDDDDDDDDDDDD"
    "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"
    "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH"
    "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"
    "JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ"
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
    "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
    "MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
    "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"
    "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO"
    "PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP"
    "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ"
    "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"
    "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"
    "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU"
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(8.2)")
{
    const auto initial =
        // clang-format off
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
    "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    "Screen accordion test (Insert & Delete Line). Push <RETURN>DDDDDDDDDDDDDDDDDDDDD"
    "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"
    "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH"
    "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"
    "JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ"
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
    "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
    "MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
    "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"
    "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO"
    "PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP"
    "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ"
    "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"
    "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"
    "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU"
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    // clang-format on

    const auto raw_input = "\x1B[4;1H\x0D\x0A\x1BM\x1B[2K\x1B[2;23r\x1B[?6h\x1B[1;1H\x1B[1L\x1B[1M\x1B[2L\x1B[2M\x1B[3L"
                           "\x1B[3M\x1B[4L\x1B[4M\x1B[5L\x1B[5M\x1B[6L\x1B[6M\x1B[7L\x1B[7M\x1B[8L\x1B[8M\x1B[9L\x1B[9M"
                           "\x1B[10L\x1B[10M\x1B[11L\x1B[11M\x1B[12L\x1B[12M\x1B[13L\x1B[13M\x1B[14L\x1B[14M\x1B[15L"
                           "\x1B[15M\x1B[16L\x1B[16M\x1B[17L\x1B[17M\x1B[18L\x1B[18M\x1B[19L\x1B[19M\x1B[20L\x1B[20M"
                           "\x1B[21L\x1B[21M\x1B[22L\x1B[22M\x1B[23L\x1B[23M\x1B[24L\x1B[24M\x1B[?6l\x1B[r\x1B[2;1H"
                           "Top line: A's, bottom line: X's, this line, nothing more. Push <RETURN>";

    const auto expectation =
        // clang-format off
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "Top line: A's, bottom line: X's, this line, nothing more. Push <RETURN>         "
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
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    screen.Buffer().LoadScreenFromANSI(initial);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(8.3) - Test of 'Insert Mode'")
{
    const auto initial =
        // clang-format off
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "Top line: A's, bottom line: X's, this line, nothing more. Push <RETURN>         "
    "                                                                                "
    "                                                                                ";
    // clang-format on

    const auto raw_input =
        "\x1B[2;1H\x0D\x0A\x1B[2;1H\x1B[0J\x1B[1;2HB\x1B[1D\x1B[4h*************************************"
        "*****************************************\x1B[4l\x1B[4;1HTest of 'Insert Mode'. The top line "
        "should be 'A*** ... ***B'. Push <RETURN>";

    const auto expectation =
        // clang-format off
    "A******************************************************************************B"
    "                                                                                "
    "                                                                                "
    "Test of 'Insert Mode'. The top line should be 'A*** ... ***B'. Push <RETURN>    ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 4);
    screen.Buffer().LoadScreenFromANSI(initial);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(8.4) - Test of 'Delete Character'")
{
    const auto initial =
        // clang-format off
    "A******************************************************************************B"
    "                                                                                "
    "                                                                                "
    "Test of 'Insert Mode'. The top line should be 'A*** ... ***B'. Push <RETURN>    "
    "                                                                                ";
    // clang-format on

    const auto raw_input = "\x1B[4;1H\x0D\x0A\x1BM\x1B[2K\x1B[1;2H\x1B[78P\x1B[4;1H"
                           "Test of 'Delete Character'. The top line should be 'AB'. Push <RETURN>";

    const auto expectation =
        // clang-format off
    "AB                                                                              "
    "                                                                                "
    "                                                                                "
    "Test of 'Delete Character'. The top line should be 'AB'. Push <RETURN>          "
    "                                                                                ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 5);
    screen.Buffer().LoadScreenFromANSI(initial);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(8.5)")
{
    const auto raw_input =
        "\x0D\x0A\x1B[2J\x1B[1;1HAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAA\x1B[1;79H\x1B[1P\x1B[2;1HBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBB\x1B[2;78H\x1B[2P\x1B[3;1HCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC\x1B[3;77H\x1B[3P\x1B[4;1HDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\x1B[4;76H\x1B[4P\x1B[5;1HEEEEEEEEEEEEEEEEEEEEEE"
        "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\x1B[5;75H\x1B[5P\x1B[6;1HFFFFFFFFFF"
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\x1B[6;74H\x1B[6P"
        "\x1B[7;1HGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"
        "\x1B[7;73H\x1B[7P\x1B[8;1HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH"
        "HHHHHHHHHHHH\x1B[8;72H\x1B[8P\x1B[9;1HIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"
        "IIIIIIIIIIIIIIIIIIIIIIII\x1B[9;71H\x1B[9P\x1B[10;1HJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ"
        "JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ\x1B[10;70H\x1B[10P\x1B[11;1HKKKKKKKKKKKKKKKKKKKKKKKKKKKK"
        "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK\x1B[11;69H\x1B[11P\x1B[12;1HLLLLLLLLLLLLL"
        "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL\x1B[12;68H\x1B[12P"
        "\x1B[13;1HMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
        "\x1B[13;67H\x1B[13P\x1B[14;1HNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"
        "NNNNNNNNNNNNNNN\x1B[14;66H\x1B[14P\x1B[15;1HOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO"
        "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOO\x1B[15;65H\x1B[15P\x1B[16;1HPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP"
        "PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP\x1B[16;64H\x1B[16P\x1B[17;1HQQQQQQQQQQQQQQQQQQQQ"
        "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ\x1B[17;63H\x1B[17P\x1B[18;1HRRRRR"
        "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR\x1B[18;62H"
        "\x1B[18P\x1B[19;1HSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
        "SSSS\x1B[19;61H\x1B[19P\x1B[20;1HTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"
        "TTTTTTTTTTTTTTTTTTT\x1B[20;60H\x1B[20P\x1B[21;1HUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU"
        "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU\x1B[21;59H\x1B[21P\x1B[22;1HVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
        "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV\x1B[22;58H\x1B[22P\x1B[23;1HWWWWWWWWWWWWWWWW"
        "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\x1B[23;57H\x1B[23P\x1B[24;1HX"
        "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\x1B[24;56H"
        "\x1B[24P\x1B[4;1HThe right column should be staggered \x0D\x0D\x0A"
        "by one.  Push <RETURN>";

    const auto expectation =
        // clang-format off
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "
    "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  "
    "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC   "
    "The right column should be staggered DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD    "
    "by one.  Push <RETURN>EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE     "
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF      "
    "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG       "
    "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH        "
    "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII         "
    "JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ          "
    "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK           "
    "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL            "
    "MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM             "
    "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN              "
    "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO               "
    "PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP                "
    "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ                 "
    "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR                  "
    "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS                   "
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT                    "
    "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU                     "
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV                      "
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW                       "
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX                        ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 24);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "vttest(8.7) - Insert Character")
{
    const auto raw_input =
        "\x0D\x0A\x1B[2J\x1B[1;1HIf your terminal has the ANSI 'Insert Character' function\x0D\x0D\x0A"
        "(the VT102 does not), then you should see a line like this\x0D\x0D\x0A  A B C D E F G H I J K"
        " L M N O P Q R S T U V W X Y Z\x0D\x0D\x0A"
        "below:\x0D\x0D\x0A\x0D\x0D\x0AZ\x08\x1B[2@Y\x08"
        "\x1B[2@X\x08\x1B[2@W\x08\x1B[2@V\x08\x1B[2@U\x08\x1B[2@T\x08\x1B[2@S\x08\x1B[2@R\x08\x1B[2@Q"
        "\x08\x1B[2@P\x08\x1B[2@O\x08\x1B[2@N\x08\x1B[2@M\x08\x1B[2@L\x08\x1B[2@K\x08\x1B[2@J\x08"
        "\x1B[2@I\x08\x1B[2@H\x08\x1B[2@G\x08\x1B[2@F\x08\x1B[2@E\x08\x1B[2@D\x08\x1B[2@C\x08\x1B[2@B"
        "\x08\x1B[2@A\x08\x1B[2@\x1B[10;1HPush <RETURN>";

    const auto expectation =
        // clang-format off
    "If your terminal has the ANSI 'Insert Character' function                       "
    "(the VT102 does not), then you should see a line like this                      "
    "  A B C D E F G H I J K L M N O P Q R S T U V W X Y Z                           "
    "below:                                                                          "
    "                                                                                "
    "  A B C D E F G H I J K L M N O P Q R S T U V W X Y Z                           "
    "                                                                                "
    "                                                                                "
    "                                                                                "
    "Push <RETURN>                                                                   "
    "                                                                                ";
    // clang-format on

    ParserImpl parser;
    Screen screen(80, 11);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsANSI();
    CHECK(result == expectation);
}

TEST_CASE(PREFIX "rn escape assumption")
{
    auto string = std::string_view("\r\n");
    REQUIRE(string.size() == 2);
    REQUIRE(string[0] == 13);
    REQUIRE(string[1] == 10);
}

TEST_CASE(PREFIX "Wheather report - wttr.in")
{
    const auto raw_input =
        "Weather report: Houston\x0D\x0A\x0D\x0A  \x1B[38;5;250m     .-.     \x1B[0m Light rain\x0D\x0A  "
        "\x1B[38;5;250m    (   ).   \x1B[0m \x1B[38;5;154m18\x1B[0m °C\x1B[0m          \x0D\x0A  \x1B[38;5;250m   "
        "(___(__)  \x1B[0m \x1B[1m↙\x1B[0m \x1B[38;5;190m11\x1B[0m km/h\x1B[0m      \x0D\x0A  \x1B[38;5;111m    ‘ ‘ ‘ "
        "‘  \x1B[0m 11 km\x1B[0m          \x0D\x0A  \x1B[38;5;111m   ‘ ‘ ‘ ‘   \x1B[0m 0.0 mm\x1B[0m         \x0D\x0A  "
        "                                                     ┌─────────────┐                                          "
        "             \x0D\x0A┌──────────────────────────────┬───────────────────────┤  Sun 08 Jan "
        "├───────────────────────┬──────────────────────────────┐\x0D\x0A│            Morning           │             "
        "Noon      └──────┬──────┘     Evening           │             Night            │\x0D\x0A├────\342"
        "\224\200─────────────────────────┼──────────────────────────────┼──────────────────────────────┼──────────────"
        "────────────────┤\x0D\x0A│ \x1B[38;5;226m _`/\"\"\x1B[38;5;250m.-.    \x1B[0m Thundery outbr…│ \x1B[38;5;226m "
        "_`/\"\"\x1B[38;5;250m.-.    \x1B[0m Thundery outbr…│ \x1B[38;5;226m    \\   /    \x1B[0m Clear          │ "
        "\x1B[38;5;226m    \\   /    \x1B[0m Clear          │\x0D\x0A│ \x1B[38;5;226m  ,\\_\x1B[38;5;250m(   ).  "
        "\x1B[0m \x1B[38;5;118m+14\x1B[0m(\x1B[38;5;118m13\x1B[0m) °C\x1B[0m     │ \x1B[38;5;226m  ,\\_\x1B[38;5;250m( "
        "  ).  \x1B[0m \x1B[38;5;154m17\x1B[0m °C\x1B[0m          │ \x1B[38;5;226m     .-.     \x1B[0m "
        "\x1B[38;5;190m20\x1B[0m °C\x1B[0m          │ \x1B[38;5;226m     .-.     \x1B[0m \x1B[38;5;118m15\x1B[0m "
        "°C\x1B[0m          │\x0D\x0A│ \x1B[38;5;226m   /\x1B[38;5;250m(___(__) \x1B[0m \x1B[1m↓\x1B[0m "
        "\x1B[38;5;226m15\x1B[0m-\x1B[38;5;214m20\x1B[0m km/h\x1B[0m   │ \x1B[38;5;226m   /\x1B[38"
        ";5;250m(___(__) \x1B[0m \x1B[1m↓\x1B[0m \x1B[38;5;154m8\x1B[0m-\x1B[38;5;226m13\x1B[0m km/h\x1B[0m    │ "
        "\x1B[38;5;226m  ― (   ) ―  \x1B[0m \x1B[1m↓\x1B[0m \x1B[38;5;226m13\x1B[0m-\x1B[38;5;226m14\x1B[0m "
        "km/h\x1B[0m   │ \x1B[38;5;226m  ― (   ) ―  \x1B[0m \x1B[1m↙\x1B[0m "
        "\x1B[38;5;190m10\x1B[0m-\x1B[38;5;226m14\x1B[0m km/h\x1B[0m   │\x0D\x0A│ \x1B[38;5;228;5m    "
        "⚡\x1B[38;5;111;25m‘‘\x1B[38;5;228;5m⚡\x1B[38;5;111;25m‘‘ \x1B[0m 10 km\x1B[0m          │ \x1B[38;5;228;5m   "
        " "
        "⚡\x1B[38;5;111;25m‘‘\x1B[38;5;228;5m⚡\x1B[38;5;111;25m‘‘ \x1B[0m 9 km\x1B[0m           │ \x1B[38;5;226m     "
        "`-’     \x1B[0m 10 km\x1B[0m          │ \x1B[38;5;226m     `-’     \x1B[0m 10 km\x1B[0m          │\x0D\x0A│ "
        "\x1B[38;5;111m    ‘ ‘ ‘ ‘  \x1B[0m 0.0 mm | 0%\x1B[0m    │ \x1B[38;5;111m    ‘ ‘ ‘ ‘  \x1B[0m 0.0 mm | "
        "0%\x1B[0m    │ \x1B[38;5;226m    /   \\    \x1B[0m 0.0 mm | 0%\x1B[0m    │ \x1B[38;5;226m    /   \\    "
        "\x1B[0m 0.0 mm | 0%\x1B[0m    │\x0D\x0A└──────────────────────────────┴──────────────────────────────┴──"
        "────────────────────────────┴──────────────────────────────┘\x0D\x0A                                          "
        "             ┌─────────────┐                                                       "
        "\x0D\x0A┌──────────────────────────────┬───────────────────────┤  Mon 09 Jan "
        "├───────────────────────┬──────────────────────────────┐\x0D\x0A│            Morning           │             "
        "Noon      └──────┬──────┘     Evening           │             Night            "
        "│\x0D\x0A├──────────────────────────────┼────────────────────────\342"
        "\224\200─────┼──────────────────────────────┼──────────────────────────────┤\x0D\x0A│               Cloudy    "
        "     │               Overcast       │ \x1B[38;5;226m _`/\"\"\x1B[38;5;250m.-.    \x1B[0m Thundery outbr…│ "
        "\x1B[38;5;226m _`/\"\"\x1B[38;5;250m.-.    \x1B[0m Light rain sho…│\x0D\x0A│ \x1B[38;5;250m     .--.    "
        "\x1B[0m "
        "\x1B[38;5;118m14\x1B[0m °C\x1B[0m          │ \x1B[38;5;240;1m     .--.    \x1B[0m \x1B[38;5;154m17\x1B[0m "
        "°C\x1B[0m          │ \x1B[38;5;226m  ,\\_\x1B[38;5;250m(   ).  \x1B[0m \x1B[38;5;190m19\x1B[0m °C\x1B[0m      "
        "    │ \x1B[38;5;226m  ,\\_\x1B[38;5;250m(   ).  \x1B[0m \x1B[38;5;154m16\x1B[0m °C\x1B[0m          │\x0D\x0A│ "
        "\x1B[38;5;250m  .-(    ).  \x1B[0m \x1B[1m←\x1B[0m \x1B[38;5;118m6\x1B[0m-\x1B[38;5;154m9\x1B[0m km/h\x1B[0m  "
        "   │ \x1B[38;5;240;1m  .-(    ).  \x1B[0m \x1B[1m←\x1B[0m \x1B[38;5;154m9\x1B[0m-\x1B[38;5;190m11\x1B[0m "
        "km/h\x1B[0m    │ \x1B[38;5;226m   /\x1B[38;5;250m(___(__) \x1B[0m \x1B[1m↖\x1B[0m "
        "\x1B[38;5;190m11\x1B[0m-\x1B[38;5;226m14\x1B[0m km/h\x1B[0m   │ \x1B[38;5;226m   /\x1B[38;5;250m(__"
        "_(__) \x1B[0m \x1B[1m↖\x1B[0m \x1B[38;5;226m13\x1B[0m-\x1B[38;5;220m17\x1B[0m km/h\x1B[0m   │\x0D\x0A│ "
        "\x1B[38;5;250m (___.__)__) \x1B[0m 10 km\x1B[0m          │ \x1B[38;5;240;1m (___.__)__) \x1B[0m 10 km\x1B[0m  "
        "        │ \x1B[38;5;228;5m    ⚡\x1B[38;5;111;25m‘‘\x1B[38;5;228;5m⚡\x1B[38;5;111;25m‘‘ \x1B[0m 9 km\x1B[0m  "
        "  "
        "       │ \x1B[38;5;111m     ‘ ‘ ‘ ‘ \x1B[0m 10 km\x1B[0m          │\x0D\x0A│               0.0 mm | 0%\x1B[0m "
        "   │               0.0 mm | 0%\x1B[0m    │ \x1B[38;5;111m    ‘ ‘ ‘ ‘  \x1B[0m 0.1 mm | 67%\x1B[0m   │ "
        "\x1B[38;5;111m    ‘ ‘ ‘ ‘  \x1B[0m 0.4 mm | 82%\x1B[0m   "
        "│\x0D\x0A└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┴───────"
        "───────────────────────┘\x0D\x0A                                                       ┌─────────────"
        "┐                                                       "
        "\x0D\x0A┌──────────────────────────────┬───────────────────────┤  Tue 10 Jan "
        "├───────────────────────┬──────────────────────────────┐\x0D\x0A│            Morning           │             "
        "Noon      └──────┬──────┘     Evening           │             Night            "
        "│\x0D\x0A├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┼───────"
        "───────────────────────┤\x0D\x0A│               Mist           │ \x1B[38;5;226m   \\  /\x1B[0m       Partl"
        "y cloudy  │ \x1B[38;5;226m    \\   /    \x1B[0m Clear          │ \x1B[38;5;226m    \\   /    \x1B[0m Clear    "
        "      │\x0D\x0A│ \x1B[38;5;251m _ - _ - _ - \x1B[0m \x1B[38;5;154m17\x1B[0m °C\x1B[0m          │ "
        "\x1B[38;5;226m _ /\"\"\x1B[38;5;250m.-.    \x1B[0m \x1B[38;5;226m22\x1B[0m °C\x1B[0m          │ "
        "\x1B[38;5;226m     .-.     \x1B[0m "
        "\x1B[38;5;220m+26\x1B[0m(\x1B[38;5;220m27\x1B[0m) °C\x1B[0m     │ \x1B[38;5;226m     .-.     \x1B[0m "
        "\x1B[38;5;190m20\x1B[0m °C\x1B[0m          │\x0D\x0A│ \x1B[38;5;251m  _ - _ - _  \x1B[0m \x1B[1m↑\x1B[0m "
        "\x1B[38;5;118m5\x1B[0m-\x1B[38;5;154m9\x1B[0m km/h\x1B[0m     │ \x1B[38;5;226m   \\_\x1B[38;5;250m(   ).  "
        "\x1B[0m \x1B[1m↗\x1B[0m \x1B[38;5;154m8\x1B[0m-\x1B[38;5;154m9\x1B[0m km/h\x1B[0m     │ \x1B[38;5;226m  ― (   "
        ") ―  \x1B[0m \x1B[1m↗\x1B[0m \x1B[38;5;190m10\x1B[0m-\x1B[38;5;190m12\x1B[0m km/h\x1B[0m   │ \x1B[38;5;226m  "
        "― (   ) ―  \x1B[0m \x1B[1m↑\x1B[0m \x1B[38;5;190m10\x1B[0m-\x1B[38;5;220m16\x1B[0m km/h\x1B[0m   │\x0D\x0A│ "
        "\x1B[38;5;251m _ - _ - _ - \x1B[0m 2 km\x1B[0m           │ \x1B[38;5;226m   /\x1B[38;5;250m(___(__) \x1B[0m "
        "10 km\x1B[0m          │ \x1B[38;5;226m     `-’     \x1B[0m 10 km\x1B[0m          │ \x1B[38;5;226m     `-’     "
        "\x1B[0m 10 km\x1B[0m"
        "          │\x0D\x0A│               0.0 mm | 0%\x1B[0m    │               0.0 mm | 0%\x1B[0m    │ "
        "\x1B[38;5;226m    "
        "/   \\    \x1B[0m 0.0 mm | 0%\x1B[0m    │ \x1B[38;5;226m    /   \\    \x1B[0m 0.0 mm | 0%\x1B[0m    "
        "│\x0D\x0A└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┴───────"
        "───────────────────────┘\x0D\x0ALocation: Houston, Harris County, Texas, United States of America "
        "[29.7589382,-95.3676973]\x0D\x0A\x0D\x0A"
        "Follow \x1B[46m\x1B[30m@igor_chubin\x1B[0m for wttr.in updates";

    const auto expectation =
        // clang-format off
U"Weather report: Houston                                                                                                           "
"                                                                                                                                  "
"       .-.      Light rain                                                                                                        "
"      (   ).    18 °C                                                                                                             "
"     (___(__)   ↙ 11 km/h                                                                                                         "
"      ‘ ‘ ‘ ‘   11 km                                                                                                             "
"     ‘ ‘ ‘ ‘    0.0 mm                                                                                                            "
"                                                       ┌─────────────┐                                                            "
"┌──────────────────────────────┬───────────────────────┤  Sun 08 Jan ├───────────────────────┬──────────────────────────────┐     "
"│            Morning           │             Noon      └──────┬──────┘     Evening           │             Night            │     "
"├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤     "
"│  _`/\"\".-.     Thundery outbr…│  _`/\"\".-.     Thundery outbr…│     \\   /     Clear          │     \\   /     Clear          │     "
"│   ,\\_(   ).   +14(13) °C     │   ,\\_(   ).   17 °C          │      .-.      20 °C          │      .-.      15 °C          │     "
"│    /(___(__)  ↓ 15-20 km/h   │    /(___(__)  ↓ 8-13 km/h    │   ― (   ) ―   ↓ 13-14 km/h   │   ― (   ) ―   ↙ 10-14 km/h   │     "
"│     ⚡ ‘‘⚡ ‘‘  10 km          │     ⚡ ‘‘⚡ ‘‘  9 km           │      `-’      10 km          │      `-’      10 km          │     "
"│     ‘ ‘ ‘ ‘   0.0 mm | 0%    │     ‘ ‘ ‘ ‘   0.0 mm | 0%    │     /   \\     0.0 mm | 0%    │     /   \\     0.0 mm | 0%    │     "
"└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┴──────────────────────────────┘     "
"                                                       ┌─────────────┐                                                            "
"┌──────────────────────────────┬───────────────────────┤  Mon 09 Jan ├───────────────────────┬──────────────────────────────┐     "
"│            Morning           │             Noon      └──────┬──────┘     Evening           │             Night            │     "
"├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤     "
"│               Cloudy         │               Overcast       │  _`/\"\".-.     Thundery outbr…│  _`/\"\".-.     Light rain sho…│     "
"│      .--.     14 °C          │      .--.     17 °C          │   ,\\_(   ).   19 °C          │   ,\\_(   ).   16 °C          │     "
"│   .-(    ).   ← 6-9 km/h     │   .-(    ).   ← 9-11 km/h    │    /(___(__)  ↖ 11-14 km/h   │    /(___(__)  ↖ 13-17 km/h   │     "
"│  (___.__)__)  10 km          │  (___.__)__)  10 km          │     ⚡ ‘‘⚡ ‘‘  9 km           │      ‘ ‘ ‘ ‘  10 km          │     "
"│               0.0 mm | 0%    │               0.0 mm | 0%    │     ‘ ‘ ‘ ‘   0.1 mm | 67%   │     ‘ ‘ ‘ ‘   0.4 mm | 82%   │     "
"└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┴──────────────────────────────┘     "
"                                                       ┌─────────────┐                                                            "
"┌──────────────────────────────┬───────────────────────┤  Tue 10 Jan ├───────────────────────┬──────────────────────────────┐     "
"│            Morning           │             Noon      └──────┬──────┘     Evening           │             Night            │     "
"├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤     "
"│               Mist           │    \\  /       Partly cloudy  │     \\   /     Clear          │     \\   /     Clear          │     "
"│  _ - _ - _ -  17 °C          │  _ /\"\".-.     22 °C          │      .-.      +26(27) °C     │      .-.      20 °C          │     "
"│   _ - _ - _   ↑ 5-9 km/h     │    \\_(   ).   ↗ 8-9 km/h     │   ― (   ) ―   ↗ 10-12 km/h   │   ― (   ) ―   ↑ 10-16 km/h   │     "
"│  _ - _ - _ -  2 km           │    /(___(__)  10 km          │      `-’      10 km          │      `-’      10 km          │     "
"│               0.0 mm | 0%    │               0.0 mm | 0%    │     /   \\     0.0 mm | 0%    │     /   \\     0.0 mm | 0%    │     "
"└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┴──────────────────────────────┘     "
"Location: Houston, Harris County, Texas, United States of America [29.7589382,-95.3676973]                                        "
"                                                                                                                                  "
"Follow @igor_chubin for wttr.in updates                                                                                           "
"                                                                                                                                  " ;
    // clang-format on

    const size_t h = 41;
    const size_t w = 130;
    ParserImpl parser;
    Screen screen(static_cast<int>(w), static_cast<int>(h));
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(parser.Parse(Bytes(raw_input)));
    const auto result = screen.Buffer().DumpScreenAsUTF32(ScreenBuffer::DumpOptions::ReportMultiCellGlyphs);

    REQUIRE(result.size() == h * w);
    REQUIRE(std::u32string_view(expectation).length() == h * w);
    for( size_t line = 0; line < h; ++line ) {
        auto lhs = std::u32string_view(result.data() + (line * w), w);
        auto rhs = std::u32string_view(expectation + (line * w), w);
        INFO(std::to_string(line));
        CHECK(lhs == rhs);
    }
}
