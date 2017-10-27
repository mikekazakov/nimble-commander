// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/Encodings.h>

#include <string>

class FontCache;

struct DoubleColor
{
    double r = 0.;
    double g = 0.;
    double b = 0.;
    double a = 1.;
    DoubleColor() = default;
    DoubleColor(double _r, double _g, double _b, double _a):
        r(_r), g(_g), b(_b), a(_a) {}
    DoubleColor( uint32_t _rgba ):
        r(double( _rgba         & 0x000000FF) / 255.),
        g(double((_rgba >>  8)  & 0x000000FF) / 255.),
        b(double((_rgba >> 16)  & 0x000000FF) / 255.),
        a(double((_rgba >> 24)  & 0x000000FF) / 255.)
    {
    }
#ifdef __OBJC__
    DoubleColor(NSColor *_c)
    {
        static const auto generic_rgb = NSColorSpace.genericRGBColorSpace;
        if( _c == nil )
            throw invalid_argument( "_c==nil" );
        [[_c colorUsingColorSpace:generic_rgb] getRed:&r green:&g blue:&b alpha:&a];
    }
    inline NSColor* ToNSColor() const {
        return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
    }
#endif
    [[deprecated]] void Set(CGContextRef _context) const {
        CGContextSetRGBFillColor(_context, r, g, b, a);
    };
    inline bool operator==(const DoubleColor& _r) const {
        return memcmp(this, &_r, sizeof(*this)) == 0;
    }
    inline bool operator!=(const DoubleColor& _r) const {
        return memcmp(this, &_r, sizeof(*this)) != 0;
    }
};

namespace oms
{

struct range
{
    int loc;
    int len;
};
    
struct unichars_draw_batch
{
    enum {max = 1024*8};
    struct{
        UniChar c;
        short x;
        short y;
    } chars[max];
    int amount;
    inline unichars_draw_batch():amount(0){};
    inline void clear() {amount = 0;}
    inline void put(UniChar _c, short _x, short _y)
    {
        assert(amount < max);
        chars[amount++] = {_c, _x, _y};
    }
};

    
// graphic configuration
void SetFillColor(CGContextRef _cont, const DoubleColor &_color);
void SetStrokeColor(CGContextRef _cont, const DoubleColor &_color);
void SetParamsForUserReadableText(CGContextRef _context, FontCache *_cache);
void SetParamsForUserASCIIArt(CGContextRef _context, FontCache *_cache);
    
// drawing routines
void DrawSingleUniChar(uint32_t _s, double _x, double _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color);
void DrawSingleUniChar(uint32_t _s, double _x, double _y, CGContextRef _cont, FontCache *_cache);
void DrawSingleUniCharXY(uint32_t _s, int _x, int _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color, const DoubleColor &_bk_color);
void DrawSingleUniCharXY(uint32_t _s, int _x, int _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color);
void DrawSingleUniCharXY(uint32_t _s, int _x, int _y, CGContextRef _cont, FontCache *_cache);
void DrawUniCharsXY(unichars_draw_batch &_batch, CGContextRef _cont, FontCache *_cache);
void DrawString(uint16_t *_s,
                size_t _start,    // position of a first symbol to draw
                size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                double _x,
                double _y,
                CGContextRef _context,
                FontCache *_font_cache,
                const DoubleColor &_text_color
                );
void DrawStringWithBackground(UniChar *_s,
                size_t _start,    // position of a first symbol to draw
                size_t _amount,   // number of unichars to draw, not visible symbols - result may be shorter
                double _x,
                double _y,
                CGContextRef _context,
                FontCache *_font_cache,
                const DoubleColor &_text_color,
                size_t _bk_fill_amount, // amount of symbols places to fill with _bk_color
                const DoubleColor &_bk_color
                );
void DrawStringXY(UniChar *_s,
                size_t _start,    // position of a first symbol to draw
                size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                int _x,
                int _y,
                CGContextRef _context,
                FontCache *_font_cache,
                const DoubleColor &_text_color
                );
void DrawStringWithBackgroundXY(UniChar *_s,
                size_t _start,    // position of a first symbol to draw
                size_t _amount,   // number of unichars to draw, not visible symbols - result may be shorter
                int _x,
                int _y,
                CGContextRef _context,
                FontCache *_font_cache,
                const DoubleColor &_text_color,
                size_t _bk_fill_amount, // amount of symbols places to fill with _bk_color
                const DoubleColor &_bk_color
                );

// unichar strings processing

/**
 * calculates amount of monospace characters need to accommodate whole input string
 */
int CalculateSymbolsSpaceForString(const uint16_t *_s, size_t _amount);

/**
 * calculates maximum amount of unichars that will not exceed _symb_amount when printed
 * returns number of unichars that can be printed starting from 0 pos
 */
int CalculateUniCharsAmountForSymbolsFromLeft(const uint16_t *_s, size_t _unic_amount, size_t _symb_amount);

/**
 * calculates maximum amount of unichars that will not exceed _symb_amount when printed.
 * returns a pair of (Position,Amount)
 */
range CalculateUniCharsAmountForSymbolsFromRight(const uint16_t *_s, size_t _unic_amount, size_t _symb_amount);

int PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(const uint16_t *_s, size_t _unic_amount, size_t _symb_amount, uint16_t *_out);
    // returns a number of actual unichars in _out
    // requires that _symb_amount should be >= 3, otherwise it's meaningless

inline bool IsUnicodeCombiningCharacter(uint32_t a)
{
    return
    (a >= 0x0300 && a <= 0x036F) ||
    (a >= 0x1DC0 && a <= 0x1DFF) ||
    (a >= 0x20D0 && a <= 0x20FF) ||
    (a >= 0xFE20 && a <= 0xFE2F) ;
}
    
extern uint32_t __g_PossibleCompositionEvidence[2048];
inline bool CanCharBeTheoreticallyComposed(uint32_t _c) noexcept
{
    if(_c >= 0x10000)
        return false;
    return (__g_PossibleCompositionEvidence[_c / 32] >> (_c % 32)) & 1;
}
 
extern uint32_t __g_WCWidthTableIsFullSize[2048];
inline unsigned char WCWidthMin1(uint32_t _c) noexcept
{
    if(_c < 0x10000)
        return ((__g_WCWidthTableIsFullSize[_c / 32] >> (_c % 32)) & 1) ? 2 : 1;
    else
        return
        (_c >= 0x10000 && _c <= 0x1fffd) ||
        (_c >= 0x20000 && _c <= 0x2fffd) ||
        (_c >= 0x30000 && _c <= 0x3fffd) ?
        2 : 1;
}
    
template <int _buf_cap>
class StringBuf
{
public:
    enum { Capacity = _buf_cap };
    
    inline StringBuf(){}
    
    inline StringBuf(const StringBuf<Capacity> &_r):
        m_Size(_r.m_Size)
    {
        memcpy(m_Buff, _r.m_Buff, sizeof(uint16_t) * m_Size);
    }
    
    inline uint16_t Size() const { return m_Size; }
    inline uint16_t *Chars() { return m_Buff; }    
    inline const uint16_t *Chars() const { return m_Buff; }
  
    inline void FromUTF8(const string &_utf8)
    {
        FromUTF8(_utf8.c_str(), _utf8.length());
    }
    
    void FromUTF8(const char *_utf8, size_t _utf8_sz)
    {
        assert(_utf8_sz < Capacity);
        size_t sz;
        InterpretUTF8BufferAsUTF16( (const uint8_t*)_utf8,
                                     _utf8_sz,
                                     m_Buff,
                                     &sz,
                                     0xFFFD);
        m_Size = sz;
    }
    
    void FromUniChars(const uint16_t *_unichars, size_t _unichars_amount)
    {
        assert(_unichars_amount <= Capacity);
        memcpy(m_Buff, _unichars, sizeof(uint16_t) * _unichars_amount);
        m_Size = _unichars_amount;
    }
    
    void FromChars(const uint8_t *_chars, size_t _chars_amount)
    {
        assert(_chars_amount <= Capacity);
        for(int i = 0; i < _chars_amount; ++i)
            m_Buff[i] = _chars[i];
        m_Size = _chars_amount;
    }
    
    void FromCFString(CFStringRef _str)
    {
        int len = (int)CFStringGetLength(_str);
        assert( len <= Capacity );
        CFStringGetCharacters(_str, CFRangeMake(0, len), m_Buff);
        m_Size = len;
    }

    void AddLeadingPaddingChars(uint16_t _char, size_t _amount)
    {
        assert( m_Size + _amount <= Capacity );
        memmove( m_Buff + _amount, m_Buff, sizeof(uint16_t)*m_Size );
        for(int i = 0; i < _amount; ++i)
            m_Buff[i] = _char;
        m_Size += _amount;
    }
    
    void RemoveLeadingPaddingChars(uint16_t _char)
    {
        int amount = 0;
        while( amount < m_Size && m_Buff[amount] == _char )
            amount++;
        memmove( m_Buff, m_Buff + amount, sizeof(uint16_t)*(m_Size-amount) );
        m_Size -= amount;
    }
    
    unsigned Space() const
    {
        return CalculateSymbolsSpaceForString(m_Buff, m_Size);
    }
    
    unsigned MaxForSpaceLeft(unsigned _space) const
    {
        return CalculateUniCharsAmountForSymbolsFromLeft(m_Buff, m_Size, _space);
    }

    range MaxForSpaceRight(unsigned _space) const
    {
        return CalculateUniCharsAmountForSymbolsFromRight(m_Buff, m_Size, _space);
    }
    
    void TrimEllipsisLeft(unsigned _max_space)
    {
        uint16_t tmp[Capacity];
        int n = PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(m_Buff, m_Size, _max_space, tmp);
        memcpy(m_Buff, tmp, sizeof(uint16_t) * n);
        m_Size = n;
    }
    
    void TrimEllipsisMiddle(unsigned _max_space)
    {
        unsigned orig_space = CalculateSymbolsSpaceForString(m_Buff, m_Size);
        if( orig_space <= _max_space )
            return;
        
        unsigned left = MaxForSpaceLeft( (_max_space-3) / 2 + (_max_space-3) % 2 );
        range right = MaxForSpaceRight( (_max_space-3) / 2 );

        memmove(m_Buff + left + 3, m_Buff+right.loc, sizeof(uint16_t)*right.len);
        m_Buff[left+0] = '.';
        m_Buff[left+1] = '.';
        m_Buff[left+2] = '.';
        m_Size = left + 3 + right.len;
    }
    
    void TrimRight(unsigned _max_space)
    {
        int len = CalculateUniCharsAmountForSymbolsFromLeft(m_Buff, m_Size, _max_space);
        if( len < m_Size )
            m_Size = len;
    }
    
    bool CanBeComposed() const
    {
        for(int i = 0; i < m_Size; ++i)
            if(CanCharBeTheoreticallyComposed(m_Buff[i]))
                return true;
        return false;
    }
    
    void NormalizeToFormC()
    {
        auto s = CFStringCreateMutableWithExternalCharactersNoCopy(0, m_Buff, m_Size, Capacity, kCFAllocatorNull);
        if(s == nullptr)
            return;
        CFStringNormalize(s, kCFStringNormalizationFormC);
        m_Size = CFStringGetLength(s);
        CFRelease(s);
    }

private:
    uint16_t m_Size = 0;
    uint16_t m_Buff[Capacity];
};

class Context
{
public:
    Context(CGContextRef _cg_context, FontCache* _font_cache);

    void SetFillColor(const DoubleColor &_color);
    void SetupForText();
    void SetupForASCIIArt();
    
    void DrawString(uint16_t *_s,
                      size_t _start,    // position of a first symbol to draw
                      size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                      int _x,
                      int _y,
                      const DoubleColor &_text_color
                      );
    
    void DrawBackground(const DoubleColor &_color, int _x, int _y, int _w, int _h = 1);

private:
    CGContextRef m_CGContext;
    FontCache   *m_FontCache;
};
    
}
