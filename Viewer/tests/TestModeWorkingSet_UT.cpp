#include "Tests.h"
#include "TextModeWorkingSet.h"
#include <Utility/Encodings.h>
#include <string>
#include <memory>

using nc::viewer::TextModeWorkingSet;

#define PREFIX "TextModeWorkingSet "
TEST_CASE(PREFIX"Copies and owns UTF16 characters")
{
    std::string utf8_string = u8"Привет, мир!";
    auto utf16_chars = std::make_unique<unsigned short[]>( utf8_string.length() );
    auto utf16_chars_offsets = std::make_unique<unsigned[]>( utf8_string.length() );
    size_t utf16_length = 0;
    encodings::InterpretAsUnichar(encodings::ENCODING_UTF8,
                                  (const unsigned char*)utf8_string.data(),
                                  utf8_string.length(),
                                  utf16_chars.get(),
                                  utf16_chars_offsets.get(),
                                  &utf16_length);
    
    auto source = TextModeWorkingSet::Source{};
    source.unprocessed_characters = (const char16_t*)utf16_chars.get();
    source.mapping_to_byte_offsets = (const int*)utf16_chars_offsets.get();
    source.characters_number = (int)utf16_length;
    source.bytes_offset = 0x400000000l;
    source.bytes_length = (int)utf8_string.length();
    auto ws = TextModeWorkingSet{source};
    
    SECTION( "Doesn't rely on the original data" ) {
        CHECK( ws.Characters() != (const char16_t*)utf16_chars.get() );
        CHECK( ws.CharactersByteOffsets() != (const int*)utf16_chars_offsets.get() );
    }
    SECTION( "Keeps proper byte offsets" ) {
        for( int i = 0; i < ws.Length(); ++i ) {
            CHECK( ws.CharactersByteOffsets()[i] == (int)utf16_chars_offsets[i] );
            CHECK( ws.ToLocalByteOffset(i) == (int)utf16_chars_offsets[i] );
            CHECK( ws.ToGlobalByteOffset(i) == source.bytes_offset + utf16_chars_offsets[i] );
        }
    }
    SECTION( "Allows off-by-one access to the bytes offsets" ) {
        CHECK( ws.ToLocalByteOffset(ws.Length()) == source.bytes_length );
        CHECK( ws.ToGlobalByteOffset(ws.Length()) == source.bytes_offset + source.bytes_length );
    }
    SECTION( "Creates a non-owning CFString" ) {
        CHECK( CFStringGetCharactersPtr(ws.String()) == (const UniChar*)ws.Characters() );
    }
}
