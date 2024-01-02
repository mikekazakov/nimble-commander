// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <vector>

/**
 All _UTF8 methods forms a null-terminated string.
 All _UTF16 methods forms a string without null-terminator.
 
 Fixed6 examples:
 "123456"
 "1234 K"
 "1235 M"
   "65 G"
    "7 T"

 SpaceSeparated examples:
 "12 232 bytes"
 "23 353 342 bytes"
 "123 234 545 454 bytes"
 
 Adaptive6 examples:
     "2 B"
    "20 B"
   "100 B"
  "1023 B"
   "5.9 K"
   "7.5 M" 
    "34 M"
   "157 G"
 
 Adaptive8 examples:
    "234 B"
   "123 KB"
  "3.53 MB"
 "56.34 MB"
 "43.78 GB"
   "0.1 TB"
 */
class ByteCountFormatter
{
public:
    ByteCountFormatter(bool _localized);
    static ByteCountFormatter &Instance();
    
    enum Type {
        SpaceSeparated = 0,
        Fixed6         = 1,
        Adaptive6      = 2,
        Adaptive8      = 3,
    };
    
    unsigned ToUTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size, Type _type) const;
    unsigned ToUTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size, Type _type) const;
#ifdef __OBJC__
    NSString* ToNSString(uint64_t _size, Type _type) const;
#endif
    
private:
    unsigned Fixed6_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size) const;
    unsigned Fixed6_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size) const;
    unsigned SpaceSeparated_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size) const;
    unsigned SpaceSeparated_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size) const;
    unsigned Adaptive_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size) const;
    unsigned Adaptive_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size) const;
    unsigned Adaptive8_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size) const;
    unsigned Adaptive8_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size) const;
#ifdef __OBJC__
    NSString* Fixed6_NSString(uint64_t _size) const;
    NSString* SpaceSeparated_NSString(uint64_t _size) const;
    NSString* Adaptive_NSString(uint64_t _size) const;
    NSString* Adaptive8_NSString(uint64_t _size) const;
#endif
    
    int Fixed6_Impl(uint64_t _size, unsigned short _buf[6]) const;
    int SpaceSeparated_Impl(uint64_t _size, unsigned short _buf[64]) const;
    int Adaptive6_Impl(uint64_t _size, unsigned short _buf[6]) const;
    int Adaptive8_Impl(uint64_t _size, unsigned short _buf[8]) const;
    void MessWithSeparator(char *_s) const;
    
    ByteCountFormatter(const ByteCountFormatter&) = delete;
    ByteCountFormatter& operator=(const ByteCountFormatter&) = delete;
    
    std::vector<uint16_t> m_SI; // localizable
    uint16_t              m_B;  // localizable
    std::vector<uint16_t> m_Bytes; // localizable
    
    char             m_DecimalSeparator = '.';
    unsigned short   m_DecimalSeparatorUni = '.';
    
    static constexpr uint64_t m_Exponent[] = {
                       1llu, // bytes
                    1024llu, // kilobytes
                 1048576llu, // megabytes
              1073741824llu, // gigabytes
           1099511627776llu, // terabytes
        1125899906842624llu, // petabytes
    }; // currently using binary based exponent, meanwhile OSX uses decimal-based exponent since MountainLion
    
};
