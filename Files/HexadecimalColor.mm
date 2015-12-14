#include "HexadecimalColor.h"

//In some contexts, primarily OpenGL, the term "RGBA" actually means the colors are stored in memory such that R is at the lowest address,
//G after it, B after that, and A last.
//This is not the format described above.
//OpenGL describes the above format as "BGRA" on a little-endian machine and "ARGB" on a big-endian machine.

// RGBA format:
// RRRRRRRRGGGGGGGGBBBBBBBBAAAAAAAA
static inline uint32_t MakeRGBA(uint8_t _r, uint8_t _g, uint8_t _b, uint8_t _a) noexcept
{
    return uint32_t(_r) | ( uint32_t(_g) << 8 ) | ( uint32_t(_b) << 16 ) | ( uint32_t(_a) << 24 );
}

static const auto g_BlackColor = MakeRGBA(0, 0, 0, 255);


static inline int HexToInt( char _c ) noexcept
{
    if( _c >= 48 && _c <= 57  ) return _c - 48;         // 0..9
    if( _c >= 65 && _c <= 70  ) return _c - 65 + 10;    // A..F
    if( _c >= 97 && _c <= 102 ) return _c - 97 + 10;    // a..F
    return 0;
}

static inline int DupHex( int _h) noexcept
{
    return _h * 16 + _h;
}

uint32_t HexadecimalColorStringToRGBA( string_view _string ) noexcept
{
    if( _string.length() < 4 || _string[0] != '#' )
        return g_BlackColor;
    
    if( _string.length() >= 9 ) // #RRGGBBAA
        return MakeRGBA(HexToInt(_string[1])*16 + HexToInt(_string[2]),
                        HexToInt(_string[3])*16 + HexToInt(_string[4]),
                        HexToInt(_string[5])*16 + HexToInt(_string[6]),
                        HexToInt(_string[7])*16 + HexToInt(_string[8])
                        );
    if( _string.length() >= 7 ) // #RRGGBB
        return MakeRGBA(HexToInt(_string[1])*16 + HexToInt(_string[2]),
                        HexToInt(_string[3])*16 + HexToInt(_string[4]),
                        HexToInt(_string[5])*16 + HexToInt(_string[6]),
                        255
                        );
    if( _string.length() >= 5 ) // #RGBA
        return MakeRGBA(DupHex(HexToInt(_string[1])),
                        DupHex(HexToInt(_string[2])),
                        DupHex(HexToInt(_string[3])),
                        DupHex(HexToInt(_string[4]))
                        );
    if( _string.length() >= 4 ) // #RGB
        return MakeRGBA(DupHex(HexToInt(_string[1])),
                        DupHex(HexToInt(_string[2])),
                        DupHex(HexToInt(_string[3])),
                        255
                        );
    
    return g_BlackColor;
}

void HexadecimalColorRGBAToString( uint32_t _rgba, char _string[10] ) noexcept
{
    static const char hex[] = "0123456789ABCDEF";
    uint8_t r = uint8_t (_rgba        & 0x000000FF);
    uint8_t g = uint8_t((_rgba >> 8)  & 0x000000FF);
    uint8_t b = uint8_t((_rgba >> 16) & 0x000000FF);
    uint8_t a = uint8_t((_rgba >> 24) & 0x000000FF);
    
    _string[0] = '#';
    _string[1] = hex[ r >>  4 ];
    _string[2] = hex[ r & 0xF ];
    _string[3] = hex[ g >>  4 ];
    _string[4] = hex[ g & 0xF ];
    _string[5] = hex[ b >>  4 ];
    _string[6] = hex[ b & 0xF ];
    if( a != 255 ) {
        _string[7] = hex[ a >>  4 ];
        _string[8] = hex[ a & 0xF ];
        _string[9] = 0;
    }
    else {
        _string[7] = 0;
    }
}

@implementation NSColor (HexColorInterface)

+ (NSColor*)colorWithRGBA:(uint32_t)_rgba
{
    return [NSColor colorWithCalibratedRed:double( _rgba         & 0x000000FF) / 255.
                                     green:double((_rgba >>  8)  & 0x000000FF) / 255.
                                      blue:double((_rgba >> 16)  & 0x000000FF) / 255.
                                     alpha:double((_rgba >> 24)  & 0x000000FF) / 255.
            ];
}

+ (NSColor*)colorWithHexString:(const char*)_hex
{
    return [NSColor colorWithRGBA:HexadecimalColorStringToRGBA(_hex ? _hex : "")];
}

+ (NSColor*)colorWithHexStdString:(const string&)_hex
{
    return [NSColor colorWithRGBA:HexadecimalColorStringToRGBA(_hex)];
}

- (uint32_t)toRGBA
{
    double r, g, b, a;
    if( self.colorSpace == NSColorSpace.genericRGBColorSpace  )
        [self getRed:&r green:&g blue:&b alpha:&a];
    else
        [[self colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];

    return MakeRGBA((uint8_t)( MIN(1.0f, MAX(0.0f, r)) * 255.),
                    (uint8_t)( MIN(1.0f, MAX(0.0f, g)) * 255.),
                    (uint8_t)( MIN(1.0f, MAX(0.0f, b)) * 255.),
                    (uint8_t)( MIN(1.0f, MAX(0.0f, a)) * 255.)
                    );
}

- (NSString*)toHexString
{
    char buf[16];
    HexadecimalColorRGBAToString( [self toRGBA], buf );
    return [NSString stringWithUTF8String:buf];
}

@end
