#pragma once

#include <stddef.h>
#include <stdint.h>

// unsigned short is just UniChar. not to let rubbish inter headers

#define ENCODING_INVALID                0x00000000
#define ENCODING_OEM866                 0x00000001
#define ENCODING_WIN1251                0x00000002
#define ENCODING_MACOS_ROMAN_WESTERN    0x00000003
/* Mac OS Roman encoding, MIME=macintosh
 * Classic native Mac text encoding
 * https://en.wikipedia.org/wiki/Mac_OS_Roman
 */

#define ENCODING_ISO_8859_1             0x00000004
/* ISO/IEC 8859-1, also called Western (ISO Latin 1)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-1
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_2             0x00000005
/* ISO/IEC 8859-2, also called Central European (ISO Latin 2)
 * http://en.wikipedia.org/wiki/ISO_8859-2
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_3             0x00000006
/* ISO/IEC 8859-3, also called South European (ISO Latin 3)
 * Mac call it Western (ISO Latin 3)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-3
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_4             0x00000007
/* ISO/IEC 8859-4, also called North European (ISO Latin 4)
 * Mac call it Central European (ISO Latin 4)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-4
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_5             0x00000008
/* ISO/IEC 8859-5, also called Latin/Cyrillic (Part 5: Latin/Cyrillic )
 * Mac call it Cyrillic (ISO 8859-5)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-5
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_6             0x00000009
/* ISO/IEC 8859-6, also called Latin/Arabic
 * Mac call it Arabic (ISO 8859-6)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-6
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_7             0x0000000A
/* ISO/IEC 8859-7, also called Latin/Greek
 * Mac call it Greek (ISO 8859-7)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-7
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_8             0x0000000B
/* ISO/IEC 8859-8, also called Latin/Hebrew
 * Mac call it Hebrew (ISO 8859-8)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-8
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_9             0x0000000C
/* ISO/IEC 8859-9, also called Latin-5 Turkish
 * Mac call it Turkish (ISO Latin 5)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-9
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_10            0x0000000D
/* ISO/IEC 8859-10, also caled Latin-6 Nordic
 * Mac call it Nordic (ISO Latin 6)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-10
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_11            0x0000000E
/* ISO/IEC 8859-11, also called Latin/Thai
 * Mac call it Thai (ISO 8859-11)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-11
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_13            0x0000000F
/* ISO/IEC 8859-13, also called Latin-7 Baltic Rim
 * Mac call it Baltic (ISO Latin 7)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-13
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_14            0x00000010
/* ISO/IEC 8859-14, also called Latin-8 Celtic
 * Mac call it Celtic (ISO Latin 8)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-14
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_15            0x00000011
/* ISO/IEC 8859-15, also called Latin-9
 * Mac call it Western (ISO Latin 9)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-15
 * NB! there are some holes in encodings which are filled with zeros
 */

#define ENCODING_ISO_8859_16            0x00000012
/* ISO/IEC 8859-16, also called Latin-10 South-Eastern European
 * Mac call it Romanian (ISO Latin 10)
 * http://en.wikipedia.org/wiki/ISO/IEC_8859-16
 * NB! there are some holes in encodings which are filled with zeros
 */ 

#define ENCODING_UTF8                   0x00010000
#define ENCODING_UTF16LE                0x00010001
#define ENCODING_UTF16BE                0x00010002

#define ENCODING_SINGLE_BYTES_FIRST__ ENCODING_OEM866
#define ENCODING_SINGLE_BYTES_LAST__ ENCODING_ISO_8859_16


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

namespace encodings
{
    const char *NameFromEncoding(int _encoding);
    int EncodingFromName(const char* _name);
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
