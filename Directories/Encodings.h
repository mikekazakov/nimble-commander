#pragma once

#include <stddef.h>
#include <stdint.h>

// unsigned short is just UniChar. not to let rubbish inter headers

#define ENCODING_INVALID                0x00000000
#define ENCODING_OEM866                 0x00000001
#define ENCODING_WIN1251                0x00000002
#define ENCODING_MACOS_ROMAN_WESTERN    0x00000003
#define ENCODING_UTF8                   0x00010000
#define ENCODING_UTF16LE                0x00010001
#define ENCODING_UTF16BE                0x00010002

#define ENCODING_SINGLE_BYTES_FIRST__ ENCODING_OEM866
#define ENCODING_SINGLE_BYTES_LAST__ ENCODING_MACOS_ROMAN_WESTERN


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

void InterpretUTF8BufferAsUniChar(
                                                      const unsigned char* _input,
                                                      size_t _input_size,
                                                      unsigned short *_output_buf, // should be at least _input_size 16b words long
                                                      size_t *_output_sz, // size of an output
                                                      unsigned short _bad_symb // something like '?' or U+FFFD
                                                      );
    // this function will not visualize non-printed symbols (0-32) in funny DOS-style
    // it will set a null-terminator in the end

void InterpretUTF8BufferAsIndexedUniChar(
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
