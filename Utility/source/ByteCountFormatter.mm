// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Foundation/Foundation.h>
#include <Utility/Encodings.h>
#include <Utility/ByteCountFormatter.h>
#include <string>

static inline void strsubst(char *_s, char _what, char _to)
{
    while(*_s) {
        if(*_s == _what)
            *_s = _to;
        ++_s;
    }
}

static inline unsigned chartouni(const char *_from, unsigned short *_to, unsigned _amount)
{
    for(unsigned i = 0; i < _amount; ++i)
        _to[i] = _from[i];
    return _amount;
}


//"__BYTECOUNTFORMATTER_BYTE_POSTFIX" = "B";
//"__BYTECOUNTFORMATTER_SI_LETTERS_ARRAY" = " KMGTP";
//"__BYTECOUNTFORMATTER_BYTES_WORD" = "bytes";
/* Bytes count postfix, for English is 'bytes' */
//"__BYTECOUNTFORMATTER_BYTES_WORD" = "байт";
//
///* One-letter byte postfix, for English is 'B' */
//"__BYTECOUNTFORMATTER_BYTE_POSTFIX" = "б";
//
///* SI postfixes with first symbol empty, for English is ' KMGTP' */
//"__BYTECOUNTFORMATTER_SI_LETTERS_ARRAY" = " КМГТП";



//
//"__BYTECOUNTFORMATTER_BYTE_POSTFIX" = "B";
//"__BYTECOUNTFORMATTER_SI_LETTERS_ARRAY" = " KMGTP";
//"__BYTECOUNTFORMATTER_BYTES_WORD" = "bytes";

// NSArray<NSString *> *preferredLocalizations;


constexpr uint64_t ByteCountFormatter::m_Exponent[];

ByteCountFormatter::ByteCountFormatter(bool _localized)
{
    m_SI = {' ', 'K', 'M', 'G', 'T', 'P'};
    m_B = 'B';
    m_Bytes = {'b', 'y', 't', 'e', 's'};

    if(_localized) {
        auto language = string(NSBundle.mainBundle.preferredLocalizations.firstObject.UTF8String);
    
        NSNumberFormatter *def_formatter = [NSNumberFormatter new];
        NSString *decimal_symbol = [def_formatter decimalSeparator];
        if(decimal_symbol.length == 1 && [decimal_symbol characterAtIndex:0] < 256) {
            m_DecimalSeparatorUni = [decimal_symbol characterAtIndex:0];
            unsigned char sep = [decimal_symbol characterAtIndex:0];
            m_DecimalSeparator = (char)sep;
        }
        
        NSString *b = [&]{
            if( language == "ru" ) return @"б";
            return  @"B";
        }();
       // NSString *b = NSLocalizedString(@"__BYTECOUNTFORMATTER_BYTE_POSTFIX", "One-letter byte postfix, for English is 'B'");
        if(b.length == 1)
            m_B = [b characterAtIndex:0];

        NSString *si = [&]{
            if( language == "ru" ) return @" КМГТП";
            return  @" KMGTP";
        }();
//        NSString *si = NSLocalizedString(@"__BYTECOUNTFORMATTER_SI_LETTERS_ARRAY", "SI postfixes with first symbol empty, for English is ' KMGTP'");
        if(si.length == m_SI.size())
            for(int i = 0; i < m_SI.size(); ++i)
                m_SI[i] = [si characterAtIndex:i];

        m_Bytes.clear();
//        NSString *bytes = NSLocalizedString(@"__BYTECOUNTFORMATTER_BYTES_WORD", "Bytes count postfix, for English is 'bytes'");
        NSString *bytes = [&]{
            if( language == "ru" ) return @"байт";
            return  @"bytes";
        }();
        for(int i = 0; i < bytes.length; ++i)
            m_Bytes.emplace_back([bytes characterAtIndex:i]);
    }
}

ByteCountFormatter &ByteCountFormatter::Instance()
{
    static ByteCountFormatter bcf(true);
    return bcf;
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// External wrapping and convertions
/////////////////////////////////////////////////////////////////////////////////////////////////

unsigned ByteCountFormatter::ToUTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size, Type _type)
{
    switch (_type) {
        case Fixed6:            return Fixed6_UTF8(_size, _buf, _buffer_size);
        case SpaceSeparated:    return SpaceSeparated_UTF8(_size, _buf, _buffer_size);
        case Adaptive6:         return Adaptive_UTF8(_size, _buf, _buffer_size);
        case Adaptive8:         return Adaptive8_UTF8(_size, _buf, _buffer_size);
        default:                return 0;
    }
}

unsigned ByteCountFormatter::ToUTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size, Type _type)
{
    switch (_type) {
        case Fixed6:            return Fixed6_UTF16(_size, _buf, _buffer_size);
        case SpaceSeparated:    return SpaceSeparated_UTF16(_size, _buf, _buffer_size);
        case Adaptive6:         return Adaptive_UTF16(_size, _buf, _buffer_size);
        case Adaptive8:         return Adaptive8_UTF16(_size, _buf, _buffer_size);
        default:                return 0;
    }
}

NSString* ByteCountFormatter::ToNSString(uint64_t _size, Type _type)
{
    switch (_type) {
        case Fixed6:            return Fixed6_NSString(_size);
        case SpaceSeparated:    return SpaceSeparated_NSString(_size);
        case Adaptive6:         return Adaptive_NSString(_size);
        case Adaptive8:         return Adaptive8_NSString(_size);
        default:                return nil;
    }
}

unsigned ByteCountFormatter::Fixed6_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size)
{
    unsigned short buf[6];
    int len = Fixed6_Impl(_size, buf);
    
    size_t utf8len;
    InterpretUnicharsAsUTF8(buf, len, _buf, _buffer_size, utf8len, nullptr);
    return (unsigned)utf8len;
}

unsigned ByteCountFormatter::Fixed6_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size)
{
    unsigned short buf[6];
    int len = Fixed6_Impl(_size, buf);
    int i = 0;
    for(; i < _buffer_size && i < len; ++i)
        _buf[i] = buf[i];
    return i;
}

NSString* ByteCountFormatter::Fixed6_NSString(uint64_t _size)
{
    unsigned short buf[6];
    int len = Fixed6_Impl(_size, buf);
    return [NSString stringWithCharacters:buf length:len];
}

unsigned ByteCountFormatter::SpaceSeparated_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size)
{
    unsigned short buf[64];
    int len = SpaceSeparated_Impl(_size, buf);
    
    size_t utf8len;
    InterpretUnicharsAsUTF8(buf, len, _buf, _buffer_size, utf8len, nullptr);
    return (unsigned)utf8len;
}

unsigned ByteCountFormatter::SpaceSeparated_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size)
{
    unsigned short buf[64];
    int len = SpaceSeparated_Impl(_size, buf);
    int i = 0;
    for(; i < _buffer_size && i < len; ++i)
        _buf[i] = buf[i];
    return i;
}

NSString* ByteCountFormatter::SpaceSeparated_NSString(uint64_t _size)
{
    unsigned short buf[64];
    int len = SpaceSeparated_Impl(_size, buf);
    return [NSString stringWithCharacters:buf length:len];
}

unsigned ByteCountFormatter::Adaptive_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size)
{
    unsigned short buf[6];
    int len = Adaptive6_Impl(_size, buf);
    size_t utf8len;
    InterpretUnicharsAsUTF8(buf, len, _buf, _buffer_size, utf8len, nullptr);
    return (unsigned)utf8len;
}

unsigned ByteCountFormatter::Adaptive_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size)
{
    unsigned short buf[6];
    int len = Adaptive6_Impl(_size, buf);
    int i = 0;
    for(; i < _buffer_size && i < len; ++i)
        _buf[i] = buf[i];
    return i;
}

NSString* ByteCountFormatter::Adaptive_NSString(uint64_t _size)
{
    unsigned short buf[6];
    int len = Adaptive6_Impl(_size, buf);
    assert(len <= 6);
    return [NSString stringWithCharacters:buf length:len];
}

unsigned ByteCountFormatter::Adaptive8_UTF8(uint64_t _size, unsigned char *_buf, size_t _buffer_size)
{
    unsigned short buf[8];
    int len = Adaptive8_Impl(_size, buf);
    size_t utf8len;
    InterpretUnicharsAsUTF8(buf, len, _buf, _buffer_size, utf8len, nullptr);
    return (unsigned)utf8len;
}

unsigned ByteCountFormatter::Adaptive8_UTF16(uint64_t _size, unsigned short *_buf, size_t _buffer_size)
{
    unsigned short buf[8];
    int len = Adaptive8_Impl(_size, buf);
    int i = 0;
    for(; i < _buffer_size && i < len; ++i)
        _buf[i] = buf[i];
    return i;
}

NSString* ByteCountFormatter::Adaptive8_NSString(uint64_t _size)
{
    unsigned short buf[8];
    int len = Adaptive8_Impl(_size, buf);
    assert(len <= 8);
    return [NSString stringWithCharacters:buf length:len];
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// Implementation itself
/////////////////////////////////////////////////////////////////////////////////////////////////

int ByteCountFormatter::Fixed6_Impl(uint64_t _size, unsigned short _buf[6])
{
    char buf[32];
    
    if(_size < 1000000) { // bytes
        int len = sprintf(buf, "%llu", _size);
        chartouni(buf, _buf, len);
        return len;
    }
    else if(_size < 9999lu * m_Exponent[1]) { // kilobytes
        uint64_t div = m_Exponent[1];
        uint64_t res = _size / div;
        int len = sprintf(buf, "%llu", res + (_size - res * div) / (div/2));
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[1];
        return len+2;
    }
    else if(_size < 9999lu * m_Exponent[2]) { // megabytes
        uint64_t div = m_Exponent[2];
        uint64_t res = _size / div;
        int len = sprintf(buf, "%llu", res + (_size - res * div) / (div/2));
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[2];
        return len+2;
    }
    else if(_size < 9999lu * m_Exponent[3]) { // gigabytes
        uint64_t div = m_Exponent[3];
        uint64_t res = _size / div;
        int len = sprintf(buf, "%llu", res + (_size - res * div) / (div/2));
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[3];
        return len+2;
    }
    else if(_size < 9999lu * m_Exponent[4]) { // terabytes
        uint64_t div = m_Exponent[4];
        uint64_t res = _size / div;
        int len = sprintf(buf, "%llu", res + (_size - res * div) / (div/2));
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[4];
        return len+2;
    }
    else if(_size < 9999lu * m_Exponent[5]) { // petabytes
        uint64_t div = m_Exponent[5];
        uint64_t res = _size / div;
        int len = sprintf(buf, "%llu", res + (_size - res * div) / (div/2));
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[5];
        return len+2;
    }
    return 0;
}

int ByteCountFormatter::SpaceSeparated_Impl(uint64_t _sz, unsigned short _buf[64])
{
    // TODO: localization!
    char buf[128];
    int len = 0;
#define __1000_1(a) ( (a) % 1000lu )
#define __1000_2(a) __1000_1( (a)/1000lu )
#define __1000_3(a) __1000_1( (a)/1000000lu )
#define __1000_4(a) __1000_1( (a)/1000000000lu )
#define __1000_5(a) __1000_1( (a)/1000000000000lu )
    if(_sz < 1000lu)
        len = sprintf(buf, "%llu ", _sz);
    else if(_sz < 1000lu * 1000lu)
        len = sprintf(buf, "%llu %03llu ", __1000_2(_sz), __1000_1(_sz));
    else if(_sz < 1000lu * 1000lu * 1000lu)
        len = sprintf(buf, "%llu %03llu %03llu ", __1000_3(_sz), __1000_2(_sz), __1000_1(_sz));
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu)
        len = sprintf(buf, "%llu %03llu %03llu %03llu ", __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz));
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu * 1000lu)
        len = sprintf(buf, "%llu %03llu %03llu %03llu %03llu ", __1000_5(_sz), __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz));
#undef __1000_1
#undef __1000_2
#undef __1000_3
#undef __1000_4
#undef __1000_5
    assert(len >= 0 && len < 50);
    for(int i = 0; i < len; ++i)
        _buf[i] = buf[i];
    for(int i = 0; i < m_Bytes.size(); ++i)
        _buf[i + len] = m_Bytes[i];
    len += m_Bytes.size();
    return len;
}

int ByteCountFormatter::Adaptive6_Impl(uint64_t _size, unsigned short _buf[6])
{
    char buf[32];
    if (_size <= 0) {
        _buf[0] = '0';
        _buf[1] = ' ';
        _buf[2] = m_B;
        return 3;
    }
    
    if (_size < 1024) {
        int len = sprintf(buf, "%llu", _size);
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_B;
        return len+2;
    }
    
    unsigned int remainer = 0, hrem = 0, expo = 1;
    for(;;expo++) {
        remainer = _size % 1024ULL;
        _size = _size / 1024ULL;
        if( _size < 1024ULL )
            break;
        hrem |= remainer;
    }
    
    unsigned significant = (unsigned)_size;
    
    if( significant < 10 ) {
        if( remainer >= 950 ) { // big remainer, add to significant number
            if( significant == 9 ) { // will overflow position
                _buf[0] = '1';
                _buf[1] = '0';
                _buf[2] = ' ';
                _buf[3] = m_SI[expo];
                _buf[4] = m_B;
                return 5;
            }
            else {
                _buf[0] = '0' + significant + 1;
                _buf[1] = m_DecimalSeparatorUni;
                _buf[2] = '0';
                _buf[3] = ' ';
                _buf[4] = m_SI[expo];
                _buf[5] = m_B;
                return 6;
            }
        } else  { // regular remainer, just write it
            int decimal = remainer / 100;
            remainer = remainer % 100;
            if (remainer > 50 || (remainer == 50 && ((decimal & 1) || hrem)))
                decimal++;
            _buf[0] = '0' + significant;
            _buf[1] = m_DecimalSeparatorUni;
            _buf[2] = '0' + decimal;
            _buf[3] = ' ';
            _buf[4] = m_SI[expo];
            _buf[5] = m_B;
            return 6;
        }
    } else { // "big" numbers, no decimal part
        if( remainer > 512 || (remainer == 512 && ((significant & 1) || hrem)) )
            significant++;
        if( significant >= 1000 ) { // overflowing current exponent
            _buf[0] = '1';
            _buf[1] = m_DecimalSeparatorUni;
            _buf[2] = '0';
            _buf[3] = ' ';
            _buf[4] = m_SI[expo+1];
            _buf[5] = m_B;
            return 6;
        } else {
            int len = sprintf(buf, "%u", significant);
            chartouni(buf, _buf, len);
            _buf[len] = ' ';
            _buf[len+1] = m_SI[expo];
            _buf[len+2] = m_B;
            return len+3;
        }
    }
}

int ByteCountFormatter::Adaptive8_Impl(uint64_t _size, unsigned short _buf[8])
{
    char buf[128];
    int len = 0;
    if( _size < 999 ) { // bytes, ABC bytes format, 5 symbols max
        len = sprintf(buf, "%llu", _size);
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_B;
        return len+2;
    }
    else if( _size < 999ul * m_Exponent[1] ) { // kilobytes, ABC KB format, 6 symbols max
        len = sprintf(buf, "%.0f", (double)_size / double(m_Exponent[1]));
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[1];
        _buf[len+2] = m_B;
        return len+3;
    }
    else if( _size < 99ul * m_Exponent[2] ) { // megabytes, AB.CD MB format, 8 symbols max
        len = sprintf(buf, "%.2f", (double)_size / double(m_Exponent[2]));
        MessWithSeparator(buf);
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[2];
        _buf[len+2] = m_B;
        return len+3;
    }
    else if( _size < 99ul * m_Exponent[3] ) { // gigabytes, AB.CD GB format, 8 symbols max
        len = sprintf(buf, "%.2f", (double)_size / double(m_Exponent[3]));
        MessWithSeparator(buf);
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[3];
        _buf[len+2] = m_B;
        return len+3;
    }
    else if( _size < 99ul * m_Exponent[4] ) { // terabytes, AB.CD TB format, 8 symbols max
        len = sprintf(buf, "%.2f", (double)_size / double(m_Exponent[4]));
        MessWithSeparator(buf);
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[4];
        _buf[len+2] = m_B;
        return len+3;
    }
    else if( _size < 99ul * m_Exponent[5] ) { // petabytes, AB.CD PB format, 8 symbols max
        len = sprintf(buf, "%.2f", (double)_size / double(m_Exponent[5]));
        MessWithSeparator(buf);
        chartouni(buf, _buf, len);
        _buf[len] = ' ';
        _buf[len+1] = m_SI[5];
        _buf[len+2] = m_B;
        return len+3;
    }
    return 0;
}

void ByteCountFormatter::MessWithSeparator(char *_s)
{
    if( m_DecimalSeparator != '.' && strchr(_s, '.') )
        strsubst(_s, '.', m_DecimalSeparator);
    else if( m_DecimalSeparator != ',' && strchr(_s, ',') )
        strsubst(_s, ',', m_DecimalSeparator);
}
