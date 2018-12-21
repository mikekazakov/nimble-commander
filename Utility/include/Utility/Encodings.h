// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <vector>

unsigned short SingleByteIntoUniCharUsingCodepage(
                                                    unsigned char _input,
                                                    int _codepage
                                                    );

void InterpretSingleByteBufferAsUniCharPreservingBufferSize(
                                                            const unsigned char* _input,
                                                            size_t _input_size,
                                                            unsigned short *_output, // should be at least _input_size 16b words long
                                                            int _codepage
                                                            );
                                                            // not setting a null-terminator!


void InterpretUTF8BufferAsUniCharPreservingBufferSize(
                                                    const unsigned char* _input,
                                                    size_t _input_size,
                                                    unsigned short *_output, // should be at least _input_size 16b words long
                                                    unsigned short _stuffing_symb, // something like '>'
                                                    unsigned short _bad_symb // something like '?' or U+FFFD
                                                    );
    // this function will also visualize non-printed symbols (0-32) in funny DOS-style
    // not setting a null-terminator!

void InterpretUTF8BufferAsUTF16(const uint8_t* _input,
                                size_t _input_size,
                                uint16_t *_output_buf, // should be at least _input_size 16b words long
                                size_t *_output_sz, // size of an output
                                uint16_t _bad_symb // something like '?' or U+FFFD
                                );
    // this function will not visualize non-printed symbols (0-32) in funny DOS-style
    // it will set a null-terminator in the end

void InterpretUTF8BufferAsIndexedUTF16(
                                         const unsigned char* _input,
                                         size_t _input_size,
                                         unsigned short *_output_buf, // should be at least _input_size 16b words long
                                         uint32_t       *_indexes_buf, // should be at least _input_size 32b words long
                                         size_t *_output_sz, // size of an output in unichars
                                         unsigned short _bad_symb // something like '?' or U+FFFD
                                         );
// this function will not visualize non-printed symbols (0-32) in funny DOS-style
// it will set a null-terminator in the end


void InterpretUTF16LEBufferAsUniChar(
                                  const unsigned char* _input,
                                  size_t _input_size,
                                  unsigned short *_output_buf, // should be at least _input_size/2 16b words long
                                  size_t *_output_sz,          // size of an output
                                  unsigned short _bad_symb     // something like '?' or U+FFFD
                                  );

void InterpretUTF16BEBufferAsUniChar(
                                     const unsigned char* _input,
                                     size_t _input_size,
                                     unsigned short *_output_buf, // should be at least _input_size/2 16b words long
                                     size_t *_output_sz,          // size of an output
                                     unsigned short _bad_symb     // something like '?' or U+FFFD
                                     );

/**
 * UTF16LE->UTF8
 * _input_chars - amount or characters, not bytes
 * _output_size - size of buffer in bytes
 * _output_result - amount of utf8 chars in buffer resulted, not accounting null-terminator
 * output will be null-terminated
 * _input_chars_eaten - (optional) how much input unicode characters was processed
 */
void InterpretUnicharsAsUTF8(const uint16_t* _input,
                             size_t _input_chars,
                             unsigned char* _output,
                             size_t _output_size,
                             size_t&_output_result,
                             size_t*_input_chars_eaten);

/**
 * UTF32LE->UTF8
 * _input_chars - amount or characters, not bytes
 * _output_size - size of buffer in bytes
 * _output_result - amount of utf8 chars in buffer resulted, not accounting null-terminator
 * output will be null-terminated
 * _input_chars_eaten - (optional) how much input unicode characters was processed
 */
void InterpretUnicodeAsUTF8(const uint32_t* _input,
                             size_t _input_chars,
                             unsigned char* _output,
                             size_t _output_size,
                             size_t&_output_result,
                             size_t*_input_chars_eaten);

namespace encodings
{
    enum {
        ENCODING_INVALID = 0,
        ENCODING_ISO_8859_1,
        ENCODING_ISO_8859_2,
        ENCODING_ISO_8859_3,
        ENCODING_ISO_8859_4,
        ENCODING_ISO_8859_5,
        ENCODING_ISO_8859_6,
        ENCODING_ISO_8859_7,
        ENCODING_ISO_8859_8,
        ENCODING_ISO_8859_9,
        ENCODING_ISO_8859_10,
        ENCODING_ISO_8859_11,
        ENCODING_ISO_8859_13,
        ENCODING_ISO_8859_14,
        ENCODING_ISO_8859_15,
        ENCODING_ISO_8859_16,
        ENCODING_OEM437,
        ENCODING_OEM737,
        ENCODING_OEM775,
        ENCODING_OEM850,
        ENCODING_OEM851,
        ENCODING_OEM852,
        ENCODING_OEM855,
        ENCODING_OEM857,
        ENCODING_OEM860,
        ENCODING_OEM861,
        ENCODING_OEM862,
        ENCODING_OEM863,
        ENCODING_OEM864,
        ENCODING_OEM865,
        ENCODING_OEM866,
        ENCODING_OEM869,
        ENCODING_WIN1250,
        ENCODING_WIN1251,
        ENCODING_WIN1252,
        ENCODING_WIN1253,
        ENCODING_WIN1254,
        ENCODING_WIN1255,
        ENCODING_WIN1256,
        ENCODING_WIN1257,
        ENCODING_WIN1258,
        
        /**
         * Mac OS Roman encoding, MIME=macintosh
         * Classic native Mac text encoding
         * https://en.wikipedia.org/wiki/Mac_OS_Roman
         */
        ENCODING_MACOS_ROMAN_WESTERN,
        
    
        
        ENCODING_UTF8                   = 0x00010000,
        ENCODING_UTF16LE                = 0x00010001,
        ENCODING_UTF16BE                = 0x00010002,
        ENCODING_SINGLE_BYTES_FIRST__   = ENCODING_ISO_8859_1,
        ENCODING_SINGLE_BYTES_LAST__    = ENCODING_MACOS_ROMAN_WESTERN
    };
    
    
    
    
    bool IsValidEncoding(int _encoding);
    const char *NameFromEncoding(int _encoding);
    int EncodingFromName(const char* _name);
    
    /**
     * on error(if _encoding is invalid value) will return -1
     */
    int ToCFStringEncoding(int _encoding);

    /**
     * on error(if _encoding is not mapped currently) will return ENCODING_INVALID
     */
    int FromCFStringEncoding(int _encoding);
    
    /**
     * on error will return ENCODING_INVALID
     */
    int FromComAppleTextEncodingXAttr(const char *_xattr_value);
    
    const std::vector< std::pair<int, CFStringRef> >& LiteralEncodingsList();
    
    int BytesForCodeUnit(int _encoding);
    void InterpretAsUnichar(
                            int _encoding,
                            const unsigned char* _input,
                            size_t _input_size,          // in bytes
                            unsigned short *_output_buf, // should be at least _input_size unichars long
                            uint32_t       *_indexes_buf, // should be at least _input_size 32b words long, can be NULL
                            size_t *_output_sz           // size of an _output_buf
                            );
}
