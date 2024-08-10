// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TextModeWorkingSet.h"
#include <Utility/Encodings.h>
#include <string>
#include <memory>

using nc::viewer::TextModeWorkingSet;

#define PREFIX "TextModeWorkingSet "
TEST_CASE(PREFIX "Copies and owns UTF16 characters")
{
    std::string utf8_string = reinterpret_cast<const char *>(u8"Привет, мир!");
    auto utf16_chars = std::make_unique<unsigned short[]>(utf8_string.length());
    auto utf16_chars_offsets = std::make_unique<unsigned[]>(utf8_string.length());
    size_t utf16_length = 0;
    nc::utility::InterpretAsUnichar(nc::utility::Encoding::ENCODING_UTF8,
                                    reinterpret_cast<const unsigned char *>(utf8_string.data()),
                                    utf8_string.length(),
                                    utf16_chars.get(),
                                    utf16_chars_offsets.get(),
                                    &utf16_length);

    auto source = TextModeWorkingSet::Source{};
    source.unprocessed_characters = reinterpret_cast<const char16_t *>(utf16_chars.get());
    source.mapping_to_byte_offsets = reinterpret_cast<const int *>(utf16_chars_offsets.get());
    source.characters_number = static_cast<int>(utf16_length);
    source.bytes_offset = 0x400000000l;
    source.bytes_length = static_cast<int>(utf8_string.length());
    auto ws = TextModeWorkingSet{source};

    SECTION("Doesn't rely on the original data")
    {
        CHECK(ws.Characters() != reinterpret_cast<const char16_t *>(utf16_chars.get()));
        CHECK(ws.CharactersByteOffsets() != reinterpret_cast<const int *>(utf16_chars_offsets.get()));
    }
    SECTION("UTF16 characters are sane")
    {
        auto direct_utf16_chars = u"Привет, мир!";
        CHECK(memcmp(direct_utf16_chars, ws.Characters(), sizeof(char16_t) * ws.Length()) == 0);
    }
    SECTION("Keeps proper byte offsets")
    {
        for( int i = 0; i < ws.Length(); ++i ) {
            CHECK(ws.CharactersByteOffsets()[i] == static_cast<int>(utf16_chars_offsets[i]));
            CHECK(ws.ToLocalByteOffset(i) == static_cast<int>(utf16_chars_offsets[i]));
            CHECK(ws.ToGlobalByteOffset(i) == source.bytes_offset + utf16_chars_offsets[i]);
        }
    }
    SECTION("Allows off-by-one access to the bytes offsets")
    {
        CHECK(ws.ToLocalByteOffset(ws.Length()) == source.bytes_length);
        CHECK(ws.ToGlobalByteOffset(ws.Length()) == source.bytes_offset + source.bytes_length);
    }
    SECTION("Creates a non-owning CFString")
    {
        CHECK(CFStringGetCharactersPtr(ws.String()) == reinterpret_cast<const UniChar *>(ws.Characters()));
    }
}

TEST_CASE(PREFIX "properly clips ranges in ToLocalBytesRange")
{
    std::string utf8_string = reinterpret_cast<const char *>(u8"Привет, мир!");
    auto utf16_chars = std::make_unique<unsigned short[]>(utf8_string.length());
    auto utf16_chars_offsets = std::make_unique<unsigned[]>(utf8_string.length());
    size_t utf16_length = 0;
    nc::utility::InterpretAsUnichar(nc::utility::Encoding::ENCODING_UTF8,
                                    reinterpret_cast<const unsigned char *>(utf8_string.data()),
                                    utf8_string.length(),
                                    utf16_chars.get(),
                                    utf16_chars_offsets.get(),
                                    &utf16_length);

    auto source = TextModeWorkingSet::Source{};
    source.unprocessed_characters = reinterpret_cast<const char16_t *>(utf16_chars.get());
    source.mapping_to_byte_offsets = reinterpret_cast<const int *>(utf16_chars_offsets.get());
    source.characters_number = static_cast<int>(utf16_length);
    source.bytes_offset = 10;
    source.bytes_length = static_cast<int>(utf8_string.length());
    auto ws = TextModeWorkingSet{source};

    SECTION("range inside")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(12, 5)).location == 2);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(12, 5)).length == 5);
    }
    SECTION("left clip")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(8, 5)).location == 0);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(8, 5)).length == 3);
    }
    SECTION("right clip")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(12, 42)).location == 2);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(12, 42)).length == source.bytes_length - 2);
    }
    SECTION("both sides clip")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(8, 42)).location == 0);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(8, 42)).length == source.bytes_length);
    }
    SECTION("outside left")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(0, 5)).location == -1);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(0, 5)).length == 0);
    }
    SECTION("outside right")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(50, 5)).location == -1);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(50, 5)).length == 0);
    }
    SECTION("invalid")
    {
        CHECK(ws.ToLocalBytesRange(CFRangeMake(-1, 0)).location == -1);
        CHECK(ws.ToLocalBytesRange(CFRangeMake(-1, 0)).length == 0);
    }
}
