// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/HexadecimalColor.h>
#include <unordered_map>
#include <Utility/SystemInformation.h>

using namespace std;

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

static const std::unordered_map< std::string, NSColor * > g_SystemColors11Plus = {
    { "@blackColor",                             NSColor.blackColor                               },
    { "@darkGrayColor",                          NSColor.darkGrayColor                            },
    { "@lightGrayColor",                         NSColor.lightGrayColor                           },
    { "@whiteColor",                             NSColor.whiteColor                               },
    { "@grayColor",                              NSColor.grayColor                                },
    { "@redColor",                               NSColor.redColor                                 },
    { "@greenColor",                             NSColor.greenColor                               },
    { "@blueColor",                              NSColor.blueColor                                },
    { "@cyanColor",                              NSColor.cyanColor                                },
    { "@yellowColor",                            NSColor.yellowColor                              },
    { "@magentaColor",                           NSColor.magentaColor                             },
    { "@orangeColor",                            NSColor.orangeColor                              },
    { "@brownColor",                             NSColor.brownColor                               },
    { "@clearColor",                             NSColor.clearColor                               },
    { "@controlShadowColor",                     NSColor.controlShadowColor                       },
    { "@controlDarkShadowColor",                 NSColor.controlDarkShadowColor                   },
    { "@controlColor",                           NSColor.controlColor                             },
    { "@controlHighlightColor",                  NSColor.controlHighlightColor                    },
    { "@controlLightHighlightColor",             NSColor.controlLightHighlightColor               },
    { "@controlTextColor",                       NSColor.controlTextColor                         },
    { "@controlBackgroundColor",                 NSColor.controlBackgroundColor                   },
    { "@selectedControlColor",                   NSColor.selectedControlColor                     },
    { "@secondarySelectedControlColor",          NSColor.secondarySelectedControlColor            },
    { "@selectedControlTextColor",               NSColor.selectedControlTextColor                 },
    { "@disabledControlTextColor",               NSColor.disabledControlTextColor                 },
    { "@textColor",                              NSColor.textColor                                },
    { "@textBackgroundColor",                    NSColor.textBackgroundColor                      },
    { "@selectedTextColor",                      NSColor.selectedTextColor                        },
    { "@selectedTextBackgroundColor",            NSColor.selectedTextBackgroundColor              },
    { "@gridColor",                              NSColor.gridColor                                },
    { "@keyboardFocusIndicatorColor",            NSColor.keyboardFocusIndicatorColor              },
    { "@windowBackgroundColor",                  NSColor.windowBackgroundColor                    },
    { "@underPageBackgroundColor",               NSColor.underPageBackgroundColor                 },
    { "@labelColor",                             NSColor.labelColor                               },
    { "@secondaryLabelColor",                    NSColor.secondaryLabelColor                      },
    { "@tertiaryLabelColor",                     NSColor.tertiaryLabelColor                       },
    { "@quaternaryLabelColor",                   NSColor.quaternaryLabelColor                     },
    { "@scrollBarColor",                         NSColor.scrollBarColor                           },
    { "@knobColor",                              NSColor.knobColor                                },
    { "@selectedKnobColor",                      NSColor.selectedKnobColor                        },
    { "@windowFrameColor",                       NSColor.windowFrameColor                         },
    { "@windowFrameTextColor",                   NSColor.windowFrameTextColor                     },
    { "@selectedMenuItemColor",                  NSColor.selectedMenuItemColor                    },
    { "@selectedMenuItemTextColor",              NSColor.selectedMenuItemTextColor                },
    { "@highlightColor",                         NSColor.highlightColor                           },
    { "@shadowColor",                            NSColor.shadowColor                              },
    { "@headerColor",                            NSColor.headerColor                              },
    { "@headerTextColor",                        NSColor.headerTextColor                          },
    { "@alternateSelectedControlColor",          NSColor.alternateSelectedControlColor            },
    { "@alternateSelectedControlTextColor",      NSColor.alternateSelectedControlTextColor        },    
    { "@controlAlternatingRowBackgroundColors0", NSColor.controlAlternatingRowBackgroundColors[0] },
    { "@controlAlternatingRowBackgroundColors1", NSColor.controlAlternatingRowBackgroundColors[1] },
    { "@linkColor",                              NSColor.linkColor                                },
    { "@placeholderTextColor",                   NSColor.placeholderTextColor                     },
    { "@systemRedColor",                         NSColor.systemRedColor                           },    
    { "@systemGreenColor",                       NSColor.systemGreenColor                         },
    { "@systemBlueColor",                        NSColor.systemBlueColor                          },    
    { "@systemOrangeColor",                      NSColor.systemOrangeColor                        },
    { "@systemYellowColor",                      NSColor.systemYellowColor                        },
    { "@systemBrownColor",                       NSColor.systemBrownColor                         },
    { "@systemPinkColor",                        NSColor.systemPinkColor                          },
    { "@systemPurpleColor",                      NSColor.systemPurpleColor                        },
    { "@systemGrayColor",                        NSColor.systemGrayColor                          }    
};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static const std::unordered_map< std::string, NSColor * > g_SystemColors13Plus()
{
    return  {
    { "@findHighlightColor",                     NSColor.findHighlightColor                       }
    };
}

static const std::unordered_map< std::string, NSColor * > SystemColors14Plus()
{
    return {
    { "@separatorColor",                         NSColor.separatorColor                           },
    { "@selectedContentBackgroundColor",         NSColor.selectedContentBackgroundColor           }, 
{"@unemphasizedSelectedContentBackgroundColor", NSColor.unemphasizedSelectedContentBackgroundColor},
    { "@alternatingContentBackgroundColors0",    NSColor.alternatingContentBackgroundColors[0]    },
    { "@alternatingContentBackgroundColors1",    NSColor.alternatingContentBackgroundColors[1]    },
    { "@unemphasizedSelectedTextBackgroundColor",NSColor.unemphasizedSelectedTextBackgroundColor  },
    { "@unemphasizedSelectedTextColor",          NSColor.unemphasizedSelectedTextColor            },    
    { "@controlAccentColor",                     NSColor.controlAccentColor                      }
    };
}

#pragma clang diagnostic pop

static const std::unordered_map< std::string, NSColor * > g_SystemColors = []{
    auto base = g_SystemColors11Plus;
    const auto system_version = nc::utility::GetOSXVersion();
    if( system_version >= nc::utility::OSXVersion::OSX_13 ) {
        const auto colors = g_SystemColors13Plus();
        base.insert( std::begin(colors), std::end(colors) );
    }
    if( system_version >= nc::utility::OSXVersion::OSX_14 ) {
        const auto colors = SystemColors14Plus();
        base.insert( std::begin(colors), std::end(colors) );
    }
    return base;
}();

static NSColor *DecodeSystemColor( const string &_color )
{
    if( _color.empty() || _color.front() != '@' )
        return nil;
    
    auto it = g_SystemColors.find(_color);
    if( it != g_SystemColors.end() )
        return it->second;
    return nil;
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
    if( auto sc = DecodeSystemColor(_hex ? _hex : "") )
        return sc;
    else
        return [NSColor colorWithRGBA:HexadecimalColorStringToRGBA(_hex ? _hex : "")];
}

+ (NSColor*)colorWithHexStdString:(const string&)_hex
{
    if( auto sc = DecodeSystemColor(_hex) )
        return sc;
    else
        return [NSColor colorWithRGBA:HexadecimalColorStringToRGBA(_hex)];
}

- (uint32_t)toRGBA
{
    double r, g, b, a;
     if(![self.colorSpaceName isEqualToString:@"NSNamedColorSpace"] &&
         self.colorSpace == NSColorSpace.genericRGBColorSpace )
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
    if( [self.colorSpaceName isEqualToString:NSNamedColorSpace] ) {
        auto i = find_if( begin(g_SystemColors), end(g_SystemColors), [&](auto &v) {
            return v.second == self;
        });
        if( i != end(g_SystemColors) )
            return [NSString stringWithUTF8String:i->first.c_str()];
    }
    
    char buf[16];
    HexadecimalColorRGBAToString( [self toRGBA], buf );
    return [NSString stringWithUTF8String:buf];
}

- (string)toHexStdString
{
    if( [self.colorSpaceName isEqualToString:NSNamedColorSpace] ) {
        auto i = find_if( begin(g_SystemColors), end(g_SystemColors), [&](auto &v) {
            return v.second == self;
        });
        if( i != end(g_SystemColors) )
            return i->first;
    }

    char buf[16];
    HexadecimalColorRGBAToString( [self toRGBA], buf );
    return string(buf);
}

@end
