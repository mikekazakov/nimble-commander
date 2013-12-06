//
//  TermParser.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "TermParser.h"
#include "TermScreen.h"
#include "TermTask.h"

#define GRAF_MAP  1
#define LAT1_MAP  0
#define IBMPC_MAP 2
#define USER_MAP  3

/* staight from linux/drivers/char/consolemap.c, GNU GPL:ed */
static const unichar translate_maps[4][256]={
    /* 8-bit Latin-1 mapped to Unicode -- trivial mapping */
    {
        0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
        0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
        0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
        0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
        0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
        0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
        0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
        0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
        0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
        0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
        0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
        0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
        0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
        0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
        0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
        0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
        0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085, 0x0086, 0x0087,
        0x0088, 0x0089, 0x008a, 0x008b, 0x008c, 0x008d, 0x008e, 0x008f,
        0x0090, 0x0091, 0x0092, 0x0093, 0x0094, 0x0095, 0x0096, 0x0097,
        0x0098, 0x0099, 0x009a, 0x009b, 0x009c, 0x009d, 0x009e, 0x009f,
        0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7,
        0x00a8, 0x00a9, 0x00aa, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
        0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7,
        0x00b8, 0x00b9, 0x00ba, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
        0x00c0, 0x00c1, 0x00c2, 0x00c3, 0x00c4, 0x00c5, 0x00c6, 0x00c7,
        0x00c8, 0x00c9, 0x00ca, 0x00cb, 0x00cc, 0x00cd, 0x00ce, 0x00cf,
        0x00d0, 0x00d1, 0x00d2, 0x00d3, 0x00d4, 0x00d5, 0x00d6, 0x00d7,
        0x00d8, 0x00d9, 0x00da, 0x00db, 0x00dc, 0x00dd, 0x00de, 0x00df,
        0x00e0, 0x00e1, 0x00e2, 0x00e3, 0x00e4, 0x00e5, 0x00e6, 0x00e7,
        0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x00ec, 0x00ed, 0x00ee, 0x00ef,
        0x00f0, 0x00f1, 0x00f2, 0x00f3, 0x00f4, 0x00f5, 0x00f6, 0x00f7,
        0x00f8, 0x00f9, 0x00fa, 0x00fb, 0x00fc, 0x00fd, 0x00fe, 0x00ff
    },
    /* VT100 graphics mapped to Unicode */
    {
        0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
        0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
        0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
        0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
        0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
        0x0028, 0x0029, 0x002a, 0x2192, 0x2190, 0x2191, 0x2193, 0x002f,
        0x2588, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
        0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
        0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
        0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
        0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
        0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x00a0,
        0x25c6, 0x2592, 0x2409, 0x240c, 0x240d, 0x240a, 0x00b0, 0x00b1,
        0x2591, 0x240b, 0x2518, 0x2510, 0x250c, 0x2514, 0x253c, 0xf800,
        0xf801, 0x2500, 0xf803, 0xf804, 0x251c, 0x2524, 0x2534, 0x252c,
        0x2502, 0x2264, 0x2265, 0x03c0, 0x2260, 0x00a3, 0x00b7, 0x007f,
        0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085, 0x0086, 0x0087,
        0x0088, 0x0089, 0x008a, 0x008b, 0x008c, 0x008d, 0x008e, 0x008f,
        0x0090, 0x0091, 0x0092, 0x0093, 0x0094, 0x0095, 0x0096, 0x0097,
        0x0098, 0x0099, 0x009a, 0x009b, 0x009c, 0x009d, 0x009e, 0x009f,
        0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7,
        0x00a8, 0x00a9, 0x00aa, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
        0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7,
        0x00b8, 0x00b9, 0x00ba, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
        0x00c0, 0x00c1, 0x00c2, 0x00c3, 0x00c4, 0x00c5, 0x00c6, 0x00c7,
        0x00c8, 0x00c9, 0x00ca, 0x00cb, 0x00cc, 0x00cd, 0x00ce, 0x00cf,
        0x00d0, 0x00d1, 0x00d2, 0x00d3, 0x00d4, 0x00d5, 0x00d6, 0x00d7,
        0x00d8, 0x00d9, 0x00da, 0x00db, 0x00dc, 0x00dd, 0x00de, 0x00df,
        0x00e0, 0x00e1, 0x00e2, 0x00e3, 0x00e4, 0x00e5, 0x00e6, 0x00e7,
        0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x00ec, 0x00ed, 0x00ee, 0x00ef,
        0x00f0, 0x00f1, 0x00f2, 0x00f3, 0x00f4, 0x00f5, 0x00f6, 0x00f7,
        0x00f8, 0x00f9, 0x00fa, 0x00fb, 0x00fc, 0x00fd, 0x00fe, 0x00ff
    },
    /* IBM Codepage 437 mapped to Unicode */
    {
        0x0000, 0x263a, 0x263b, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
        0x25d8, 0x25cb, 0x25d9, 0x2642, 0x2640, 0x266a, 0x266b, 0x263c,
        0x25b6, 0x25c0, 0x2195, 0x203c, 0x00b6, 0x00a7, 0x25ac, 0x21a8,
        0x2191, 0x2193, 0x2192, 0x2190, 0x221f, 0x2194, 0x25b2, 0x25bc,
        0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
        0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
        0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
        0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
        0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
        0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
        0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
        0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
        0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
        0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
        0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
        0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x2302,
        0x00c7, 0x00fc, 0x00e9, 0x00e2, 0x00e4, 0x00e0, 0x00e5, 0x00e7,
        0x00ea, 0x00eb, 0x00e8, 0x00ef, 0x00ee, 0x00ec, 0x00c4, 0x00c5,
        0x00c9, 0x00e6, 0x00c6, 0x00f4, 0x00f6, 0x00f2, 0x00fb, 0x00f9,
        0x00ff, 0x00d6, 0x00dc, 0x00a2, 0x00a3, 0x00a5, 0x20a7, 0x0192,
        0x00e1, 0x00ed, 0x00f3, 0x00fa, 0x00f1, 0x00d1, 0x00aa, 0x00ba,
        0x00bf, 0x2310, 0x00ac, 0x00bd, 0x00bc, 0x00a1, 0x00ab, 0x00bb,
        0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
        0x2555, 0x2563, 0x2551, 0x2557, 0x255d, 0x255c, 0x255b, 0x2510,
        0x2514, 0x2534, 0x252c, 0x251c, 0x2500, 0x253c, 0x255e, 0x255f,
        0x255a, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256c, 0x2567,
        0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256b,
        0x256a, 0x2518, 0x250c, 0x2588, 0x2584, 0x258c, 0x2590, 0x2580,
        0x03b1, 0x00df, 0x0393, 0x03c0, 0x03a3, 0x03c3, 0x00b5, 0x03c4,
        0x03a6, 0x0398, 0x03a9, 0x03b4, 0x221e, 0x03c6, 0x03b5, 0x2229,
        0x2261, 0x00b1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00f7, 0x2248,
        0x00b0, 0x2219, 0x00b7, 0x221a, 0x207f, 0x00b2, 0x25a0, 0x00a0
    },
    /* User mapping -- default to codes for direct font mapping */
    {
        0xf000, 0xf001, 0xf002, 0xf003, 0xf004, 0xf005, 0xf006, 0xf007,
        0xf008, 0xf009, 0xf00a, 0xf00b, 0xf00c, 0xf00d, 0xf00e, 0xf00f,
        0xf010, 0xf011, 0xf012, 0xf013, 0xf014, 0xf015, 0xf016, 0xf017,
        0xf018, 0xf019, 0xf01a, 0xf01b, 0xf01c, 0xf01d, 0xf01e, 0xf01f,
        0xf020, 0xf021, 0xf022, 0xf023, 0xf024, 0xf025, 0xf026, 0xf027,
        0xf028, 0xf029, 0xf02a, 0xf02b, 0xf02c, 0xf02d, 0xf02e, 0xf02f,
        0xf030, 0xf031, 0xf032, 0xf033, 0xf034, 0xf035, 0xf036, 0xf037,
        0xf038, 0xf039, 0xf03a, 0xf03b, 0xf03c, 0xf03d, 0xf03e, 0xf03f,
        0xf040, 0xf041, 0xf042, 0xf043, 0xf044, 0xf045, 0xf046, 0xf047,
        0xf048, 0xf049, 0xf04a, 0xf04b, 0xf04c, 0xf04d, 0xf04e, 0xf04f,
        0xf050, 0xf051, 0xf052, 0xf053, 0xf054, 0xf055, 0xf056, 0xf057,
        0xf058, 0xf059, 0xf05a, 0xf05b, 0xf05c, 0xf05d, 0xf05e, 0xf05f,
        0xf060, 0xf061, 0xf062, 0xf063, 0xf064, 0xf065, 0xf066, 0xf067,
        0xf068, 0xf069, 0xf06a, 0xf06b, 0xf06c, 0xf06d, 0xf06e, 0xf06f,
        0xf070, 0xf071, 0xf072, 0xf073, 0xf074, 0xf075, 0xf076, 0xf077,
        0xf078, 0xf079, 0xf07a, 0xf07b, 0xf07c, 0xf07d, 0xf07e, 0xf07f,
        0xf080, 0xf081, 0xf082, 0xf083, 0xf084, 0xf085, 0xf086, 0xf087,
        0xf088, 0xf089, 0xf08a, 0xf08b, 0xf08c, 0xf08d, 0xf08e, 0xf08f,
        0xf090, 0xf091, 0xf092, 0xf093, 0xf094, 0xf095, 0xf096, 0xf097,
        0xf098, 0xf099, 0xf09a, 0xf09b, 0xf09c, 0xf09d, 0xf09e, 0xf09f,
        0xf0a0, 0xf0a1, 0xf0a2, 0xf0a3, 0xf0a4, 0xf0a5, 0xf0a6, 0xf0a7,
        0xf0a8, 0xf0a9, 0xf0aa, 0xf0ab, 0xf0ac, 0xf0ad, 0xf0ae, 0xf0af,
        0xf0b0, 0xf0b1, 0xf0b2, 0xf0b3, 0xf0b4, 0xf0b5, 0xf0b6, 0xf0b7,
        0xf0b8, 0xf0b9, 0xf0ba, 0xf0bb, 0xf0bc, 0xf0bd, 0xf0be, 0xf0bf,
        0xf0c0, 0xf0c1, 0xf0c2, 0xf0c3, 0xf0c4, 0xf0c5, 0xf0c6, 0xf0c7,
        0xf0c8, 0xf0c9, 0xf0ca, 0xf0cb, 0xf0cc, 0xf0cd, 0xf0ce, 0xf0cf,
        0xf0d0, 0xf0d1, 0xf0d2, 0xf0d3, 0xf0d4, 0xf0d5, 0xf0d6, 0xf0d7,
        0xf0d8, 0xf0d9, 0xf0da, 0xf0db, 0xf0dc, 0xf0dd, 0xf0de, 0xf0df,
        0xf0e0, 0xf0e1, 0xf0e2, 0xf0e3, 0xf0e4, 0xf0e5, 0xf0e6, 0xf0e7,
        0xf0e8, 0xf0e9, 0xf0ea, 0xf0eb, 0xf0ec, 0xf0ed, 0xf0ee, 0xf0ef,
        0xf0f0, 0xf0f1, 0xf0f2, 0xf0f3, 0xf0f4, 0xf0f5, 0xf0f6, 0xf0f7,
        0xf0f8, 0xf0f9, 0xf0fa, 0xf0fb, 0xf0fc, 0xf0fd, 0xf0fe, 0xf0ff
    }
};


TermParser::TermParser(TermScreen *_scr, TermTask *_task):
    m_Scr(_scr),
    m_Task(_task)
{
    Reset();
}

void TermParser::Reset()
{
    memset(&m_State, 0, sizeof(m_State));
    m_State[0].color = 0x07;
    m_State[0].g0_charset = LAT1_MAP;
    m_State[0].g1_charset = GRAF_MAP;
    m_DefaultColor = 0x07;
    m_TitleLen = 0;
    m_TitleType = 0;
    m_LineAbs = true;
    m_Top = 0;
    m_Bottom = m_Scr->GetHeight();
    m_EscState = S_Normal;
    m_ParamsCnt = 0;
    m_QuestionFlag = false;
    m_ParsingParamNow = 0;
    m_UniChar = 0;
    m_UTFCount = 0;
    m_UniCharsStockLen = 0;
    m_DECPMS_SavedCurX = 0;
    m_DECPMS_SavedCurY = 0;
    
    
    SetTranslate(LAT1_MAP);
    UpdateAttrs();
    m_Scr->GoTo(0, 0);
    EscSave();

    m_Title[m_TitleLen] = 0;
    m_Scr->SetTitle(m_Title);
    
    
//    m_TabStop[8];
    m_TabStop[0]= 0x01010100;
/*    m_TabStop[1]=m_TabStop[2]=m_TabStop[3]=m_TabStop[4]=
    m_TabStop[5]=m_TabStop[6]=m_TabStop[7]=0x01010101;*/
    for(int i = 1; i < 16; ++i)
        m_TabStop[i] = 0x01010101;
}

#if defined(HAVE_UNICODE_UNORM2_H)
- (NSString *) _normalizedICUStringOfType: (const char*)normalization mode: (UNormalization2Mode)mode
{
    UErrorCode            err;
    const UNormalizer2    *normalizer;
    int32_t               length;
    int32_t               newLength;
    NSString              *newString;
    
    length = (uint32_t)[self length];
    if (0 == length)
    {
        return @"";       // Simple case ... empty string
    }
    
    err = 0;
    normalizer = unorm2_getInstance(NULL, normalization, mode, &err);
    if (U_FAILURE(err))
    {
        [NSException raise: NSCharacterConversionException
                    format: @"libicu unorm2_getInstance() failed"];
    }
    
    if (length < 200)
    {
        unichar   src[length];
        unichar   dst[length*3];
        
        /* For a short string, it's very efficient to just use on-stack
         * buffers for the libicu work, and then let the standard string
         * initialiser convert that to an inline string.
         */
        [self getCharacters: (unichar *)src range: NSMakeRange(0, length)];
        err = 0;
        newLength = unorm2_normalize(normalizer, (UChar*)src, length,
                                     (UChar*)dst, length*3, &err);
        if (U_FAILURE(err))
        {
            [NSException raise: NSCharacterConversionException
                        format: @"precompose/decompose failed"];
        }
        newString = [[NSString alloc] initWithCharacters: dst length: newLength];
    }
    else
    {
        unichar   *src;
        unichar   *dst;
        
        /* For longer strings, we copy the source into a buffer on the heap
         * for the libicu operation, determine the length needed for the
         * output buffer, then do the actual conversion to build the string.
         */
        src = (unichar*)malloc(length * sizeof(unichar));
        [self getCharacters: (unichar*)src range: NSMakeRange(0, length)];
        err = 0;
        newLength = unorm2_normalize(normalizer, (UChar*)src, length,
                                     0, 0, &err);
        if (U_BUFFER_OVERFLOW_ERROR != err)
        {
            free(src);
            [NSException raise: NSCharacterConversionException
                        format: @"precompose/decompose length check failed"];
        }
#if	GS_WITH_GC
        dst = NSAllocateCollectable(newLength * sizeof(unichar), 0);
#else
        dst = NSZoneMalloc(NSDefaultMallocZone(), newLength * sizeof(unichar));
#endif
        err = 0;
        unorm2_normalize(normalizer, (UChar*)src, length,
                         (UChar*)dst, newLength, &err);
        free(src);
        if (U_FAILURE(err))
        {
#if	!GS_WITH_GC
            NSZoneFree(NSDefaultMallocZone(), dst);
#endif
            [NSException raise: NSCharacterConversionException
                        format: @"precompose/decompose failed"];
        }
        newString = [[NSString alloc] initWithCharactersNoCopy: dst
                                                        length: newLength
                                                  freeWhenDone: YES];
    }
    
    return AUTORELEASE(newString);
}
#endif

void TermParser::Flush()
{
    if( m_UniCharsStockLen == 0 ) return;
    
    bool hi = false;
    for(int i = 0; i < m_UniCharsStockLen; ++i)
        if(m_UniCharsStock[i] > 0x7F)
        {
            hi = true;
            break;
        }
    
    unsigned short *chars = 0;
    int chars_len = 0;
    
    unsigned short recomp[16384];
    
    if(!hi)
    {
        chars = m_UniCharsStock;
        chars_len = m_UniCharsStockLen;
    }
    else
    {
        // REWRITE THIS USING ICU!!!!!!!!!!!
/*
#if (GS_USE_ICU == 1) && defined(HAVE_UNICODE_UNORM2_H)
        return [self _normalizedICUStringOfType: "nfc" mode: UNORM2_COMPOSE];
#else
*/
        NSString *orig = [NSString stringWithCharacters:m_UniCharsStock length:m_UniCharsStockLen];
        NSString *comp = [orig precomposedStringWithCanonicalMapping];
        int comp_len = (int)[comp length];
        [comp getCharacters:recomp];
    
//        for(int i = 0; i < comp_len; ++i)
//            m_Scr->PutCh(recomp[i]);
        chars = recomp;
        chars_len = comp_len;
    }
    
    for(int i = 0; i < chars_len; ++i)
    {
        if(m_Scr->GetCursorX() >= m_Scr->GetWidth())
        {
            CR();
            LF();
        }
        
        m_Scr->PutCh(chars[i]);
    }
    
    m_UniCharsStockLen = 0;
}

void TermParser::EatByte(unsigned char _byte)
{
    unsigned char c = _byte;
    
    if(c < 32) Flush();
    
    switch (c)
    {
        case  0: return;
        case  7: if(m_EscState == S_TitleBuf)
                 {
                     m_Title[m_TitleLen] = 0;
                     m_Scr->SetTitle(m_Title);
                     m_EscState = S_Normal;
                     return;
                 }
                 NSBeep();
                 return;
        case  8: m_Scr->DoCursorLeft(); return;
        case  9: HT(); return;
        case 10:
        case 11:
        case 12: LF(); return;
        case 13: CR(); return;
        case 24:
        case 26: m_EscState = S_Normal; return;
        case 27: m_EscState = S_Esc; return;
        default: break;
    }
    
    switch (m_EscState)
    {
        case S_Esc:
            m_EscState = S_Normal;
            switch (c)
            {
                case '[': m_EscState = S_LeftBr;    return;
                case ']': m_EscState = S_RightBr;   return;
                case '(': m_EscState = S_SetG0;     return;
                case ')': m_EscState = S_SetG1;     return;
                case '>':  /* Numeric keypad - ignoring now */  return;
                case '=':  /* Appl. keypad - ignoring now */    return;
                case '7': EscSave();    return;
                case '8': EscRestore(); return;
                case 'E': CR();         return;
                case 'D': LF();         return;
                case 'M': RI();         return;
                case 'c': Reset();      return;
                default: printf("missed Esc char: %d(\'%c\')\n", (int)c, c); return;
            }
            
        case S_RightBr:
            switch (c)
            {
                case '0':
                case '1':
                case '2':
                    m_TitleType = c - '0';
                    m_EscState = S_TitleSemicolon;
                    return;
                case 'P':
//                NSDebugLLog(@"term",@"ignore ESnonstd P");
                    m_EscState = S_Normal;
//                    vc_state = ESpalette;
                    return;
                case 'R':
//                NSDebugLLog(@"term",@"ignore ESnonstd R");
                    m_EscState = S_Normal;
                default: printf("non-std right br char: %d(\'%c\')\n", (int)c, c); return;                    
            }
            
            m_EscState = S_Normal;
            return;
            
        case S_TitleSemicolon:
            if (c==';') {
                m_EscState = S_TitleBuf;
                m_TitleLen = 0;
            }
            else
                m_EscState = S_Normal;
            return;
            
        case S_TitleBuf:
            if(m_TitleLen == m_TitleMaxLen)
                m_EscState = S_Normal;
            else
                m_Title[m_TitleLen++] = c;
            return;
            
        case S_LeftBr:
            memset(m_Params, 0, sizeof(m_Params));
            m_ParamsCnt = 0;
            m_EscState = S_ProcParams;
            m_ParsingParamNow = false;
            m_QuestionFlag = false;
            if(c == '?') {
                m_QuestionFlag = true;
                return;
            }
                 
        case S_ProcParams:
            if(c == ';' && m_ParamsCnt < MaxParams - 1) {
                m_ParamsCnt++;
                return;
            } else if( c >= '0' && c <= '9' ) {
                m_ParsingParamNow = true;
                m_Params[m_ParamsCnt] *= 10;
                m_Params[m_ParamsCnt] += c - '0';
                return;
            } else
                m_EscState = S_GotParams;

        case S_GotParams:
            if(m_ParsingParamNow) {
                m_ParsingParamNow = false;
                m_ParamsCnt++;
            }
            
            m_EscState = S_Normal;
            switch(c) {
                case 'h': CSI_DEC_PMS(true);  return;
                case 'l': CSI_DEC_PMS(false); return;
            }
            
            switch(c) {
                case 'A': CSI_n_A(); return;
                case 'B': case 'e': CSI_n_B(); return;
                case 'C': case 'a': CSI_n_C(); return;
                case 'd': CSI_n_d(); return;
                case 'D': CSI_n_D(); return;
                case 'H': case 'f': CSI_n_H(); return;
                case 'G': case '`': CSI_n_G(); return;
                case 'J': CSI_n_J(); return;
                case 'K': CSI_n_K(); return;
                case 'm': CSI_n_m(); return;
                case 'M': CSI_n_M(); return;
                case 'P': CSI_n_P(); return;
                case 'X': CSI_n_X(); return;
                case 's': EscSave(); return;
                case 'u': EscRestore(); return;
                case 'r': CSI_n_r(); return;
                default: printf("unhandled: CSI %c\n", c);
            }
            return;
        
        case S_SetG0:
            if (c == '0')       m_State[0].g0_charset  = GRAF_MAP;
            else if (c == 'B')  m_State[0].g0_charset  = LAT1_MAP;
            else if (c == 'U')  m_State[0].g0_charset  = IBMPC_MAP;
            else if (c == 'K')  m_State[0].g0_charset  = USER_MAP;
            SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
            return;
            
        case S_SetG1:
            if (c == '0')       m_State[0].g1_charset  = GRAF_MAP;
            else if (c == 'B')  m_State[0].g1_charset  = LAT1_MAP;
            else if (c == 'U')  m_State[0].g1_charset  = IBMPC_MAP;
            else if (c == 'K')  m_State[0].g1_charset  = USER_MAP;
            SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
            return;
            
        default:
            if(c > 0x7f) {
                if (m_UTFCount && (c&0xc0)==0x80) {
                    m_UniChar = (m_UniChar<<6) | (c&0x3f);
                    m_UTFCount--;
                    if(m_UTFCount)
                        return;
                }
                else {
                    if ((c & 0xe0) == 0xc0) {
                        m_UTFCount = 1;
                        m_UniChar = (c & 0x1f);
                    }
                    else if ((c & 0xf0) == 0xe0) {
                        m_UTFCount = 2;
                        m_UniChar = (c & 0x0f);
                    }
                    else if ((c & 0xf8) == 0xf0) {
                        m_UTFCount = 3;
                        m_UniChar = (c & 0x07);
                    }
                    else if ((c & 0xfc) == 0xf8) {
                        m_UTFCount = 4;
                        m_UniChar = (c & 0x03);
                    }
                    else if ((c & 0xfe) == 0xfc) {
                        m_UTFCount = 5;
                        m_UniChar = (c & 0x01);
                    }
                    else
                        m_UTFCount = 0;
                    return;
                }
            }
            else if (m_TranslateMap != 0 && m_TranslateMap != translate_maps[0] ) {
//                if (toggle_meta)
//                    c|=0x80;
                m_UniChar = m_TranslateMap[c];
            }
            else {
                m_UniChar = c;
            }
            
            m_UniCharsStock[m_UniCharsStockLen++] = m_UniChar;
            
            return;
    }
    
/*    switch (c)
	{
        case 0:
            return;
        case 7:
            if (vc_state==EStitle_buf)
            {
                NSString *new_title;
                title_buf[title_len]=0;
                new_title=[NSString stringWithCString: title_buf];
                [ts ts_setTitle: new_title  type: title_type];
                vc_state=ESnormal;
                
                return;
            }
            NSBeep();
            return;
        case 8:
            if (x>0)
            {
                x--;
                [ts ts_goto: x:y];
            }
            return;
        case 9:
            while (x < width - 1) {
                x++;
                if (tab_stop[x >> 5] & (1 << (x & 31)))
                    break;
            }
            [ts ts_goto: x:y];
            return;
        case 10: case 11: case 12:
            lf();
			return;
        case 13:
            cr();
            return;
        case 14:
            charset = 1;
            translate = set_translate(G1_charset,currcons);
            disp_ctrl = 1;
            return;
        case 15:
            charset = 0;
            translate = set_translate(G0_charset,currcons);
            disp_ctrl = 0;
            return;
        case 24: case 26:
            vc_state = ESnormal;
            return;
        case 27:
            vc_state = ESesc;
            return;
        case 127:
            //		del(currcons);
            return;
        case 128+27:			// This kills UTF-8 unless we do some funky stuff
            if (!utf_count) {
                vc_state = ESsquare;
                return;
            }
	}*/
    
    
    
}

void TermParser::SetTranslate(int _charset)
{
    if(_charset < 0 || _charset >= 4)
        m_TranslateMap = translate_maps[0];
    m_TranslateMap = translate_maps[_charset];
}

void TermParser::CSI_n_J()
{
    m_Scr->DoEraseScreen(m_Params[0]);
}

void TermParser::CSI_n_A()
{
    m_Scr->DoCursorUp( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void TermParser::CSI_n_B()
{
    m_Scr->DoCursorDown( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void TermParser::CSI_n_C()
{
    m_Scr->DoCursorRight( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void TermParser::CSI_n_D()
{
    m_Scr->DoCursorLeft( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void TermParser::CSI_n_G()
{
    m_Params[0]--;
    m_Scr->GoTo(m_Params[0], m_Scr->GetCursorY());
}

void TermParser::CSI_n_d()
{
    m_Params[0]--;
    DoGoTo(m_Scr->GetCursorX(), m_Params[0]);
}

void TermParser::CSI_n_H()
{
    m_Params[0]--;
    m_Params[1]--;
    DoGoTo(m_Params[1], m_Params[0]);
}

void TermParser::CSI_n_K()
{
    m_Scr->DoEraseInLine(m_Params[0]);
}

void TermParser::CSI_n_X()
{
    if(m_Params[0] == 0)
        m_Params[0]++;
    int pos = m_Scr->GetCursorX();
    m_Scr->DoEraseCharacters(m_Params[0] + pos > m_Scr->GetWidth() ?
                             m_Scr->GetWidth() - pos :
                             m_Params[0]
                             );
}

void TermParser::CSI_n_M()
{
    unsigned n = m_Params[0];
    if(n > m_Scr->GetHeight() - m_Scr->GetCursorY())
        n = m_Scr->GetHeight() - m_Scr->GetCursorY();
    else if(n == 0)
        n = 1;
    m_Scr->DoScrollUp(m_Scr->GetCursorY(), m_Bottom, n);
}

void TermParser::SetDefaultAttrs()
{
    m_State[0].color = m_DefaultColor;
    m_State[0].intensity = 0;
    m_State[0].underline = false;
    m_State[0].reverse = false;
}

void TermParser::UpdateAttrs()
{
    m_Scr->SetColor(m_State[0].color);
    m_Scr->SetIntensity(m_State[0].intensity);
    m_Scr->SetUnderline(m_State[0].underline);
    m_Scr->SetReverse(m_State[0].reverse);
}

void TermParser::CSI_n_m()
{
    for(int i = 0; i < m_ParamsCnt; ++i)
        switch (m_Params[i]) {
            case 0:  SetDefaultAttrs();             break;
			case 1:
            case 21:
            case 22: m_State[0].intensity = 1;      break;
			case 2:  m_State[0].intensity = 0;      break;
			case 4:  m_State[0].underline = true;   break;
			case 24: m_State[0].underline = false;  break;
            case 7:  m_State[0].reverse   = true;   break;
            case 27: m_State[0].reverse   = false;  break;
            case 30: m_State[0].color =  TermScreenColors::Black          | (m_State[0].color & 0x38); break;
            case 31: m_State[0].color =  TermScreenColors::Red            | (m_State[0].color & 0x38); break;
            case 32: m_State[0].color =  TermScreenColors::Green          | (m_State[0].color & 0x38); break;
            case 33: m_State[0].color =  TermScreenColors::Yellow         | (m_State[0].color & 0x38); break;
            case 34: m_State[0].color =  TermScreenColors::Blue           | (m_State[0].color & 0x38); break;
            case 35: m_State[0].color =  TermScreenColors::Magenta        | (m_State[0].color & 0x38); break;
            case 36: m_State[0].color =  TermScreenColors::Cyan           | (m_State[0].color & 0x38); break;
            case 37: m_State[0].color =  TermScreenColors::White          | (m_State[0].color & 0x38); break;
            case 40: m_State[0].color = (TermScreenColors::Black   << 3 ) | (m_State[0].color & 0x07); break;
            case 41: m_State[0].color = (TermScreenColors::Red     << 3 ) | (m_State[0].color & 0x07); break;
            case 42: m_State[0].color = (TermScreenColors::Green   << 3 ) | (m_State[0].color & 0x07); break;
            case 43: m_State[0].color = (TermScreenColors::Yellow  << 3 ) | (m_State[0].color & 0x07); break;
            case 44: m_State[0].color = (TermScreenColors::Blue    << 3 ) | (m_State[0].color & 0x07); break;
            case 45: m_State[0].color = (TermScreenColors::Magenta << 3 ) | (m_State[0].color & 0x07); break;
            case 46: m_State[0].color = (TermScreenColors::Cyan    << 3 ) | (m_State[0].color & 0x07); break;
            case 47: m_State[0].color = (TermScreenColors::White   << 3 ) | (m_State[0].color & 0x07); break;
			case 39: m_State[0].color = (m_DefaultColor & 0x07) | (m_State[0].color & 0x38); m_State[0].underline = false; break;
			case 49: m_State[0].color = (m_DefaultColor & 0x38) | (m_State[0].color & 0x07); break;
            // [...] MANY MORE HERE
            default: printf("unhandled CSI_n_m: %d\n", m_Params[i]);
        }
    UpdateAttrs();
    
/*
 #define foreground (color & 0x0f)
 #define background (color & 0xf0)
 int i;
	for (i=0;i<=npar;i++)
		switch (par[i]) {
			case 0:	// all attributes off
				[self _default_attr];
				break;
			case 1:
				intensity = 2;
				break;
			case 2:
				intensity = 0;
				break;
			case 4:
				underline = 1;
				break;
			case 5:
				blink = 1;
				break;
			case 7:
				reverse = 1;
				break;
			case 10: // ANSI X3.64-1979 (SCO-ish?)
                     //Select primary font, don't display
                      // control chars if defined, don't set
                      // bit 8 on output.

				translate = set_translate(charset == 0
                                          ? G0_charset
                                          : G1_charset,currcons);
				disp_ctrl = 0;
				toggle_meta = 0;
				break;
			case 11: // ANSI X3.64-1979 (SCO-ish?)
                    //Select first alternate font, lets
                      // chars < 32 be displayed as ROM chars.
                      //
				translate = set_translate(IBMPC_MAP,currcons);
				disp_ctrl = 1;
				toggle_meta = 0;
				break;
			case 12: // ANSI X3.64-1979 (SCO-ish?)
                      // Select second alternate font, toggle
                      // high bit before displaying as ROM char.
                      //
				translate = set_translate(IBMPC_MAP,currcons);
				disp_ctrl = 1;
				toggle_meta = 1;
				break;
			case 21:
			case 22:
				intensity = 1;
				break;
			case 24:
				underline = 0;
				break;
			case 25:
				blink = 0;
				break;
			case 27:
				reverse = 0;
				break;
			case 38: // ANSI X3.64-1979 (SCO-ish?)
                      // Enables underscore, white foreground
                      // with white underscore (Linux - use
                      // default foreground).
                      //
				color = (def_color & 0x0f) | background;
				underline = 1;
				break;
			case 39: // ANSI X3.64-1979 (SCO-ish?)
                      // Disable underline option.
                      // Reset colour to default? It did this
                      // before...
                
				color = (def_color & 0x0f) | background;
				underline = 0;
				break;
			case 49:
				color = (def_color & 0xf0) | foreground;
				break;
			default:
				if (par[i] >= 30 && par[i] <= 37)
					color = color_table[par[i]-30]
                    | background;
				else if (par[i] >= 40 && par[i] <= 47)
					color = (color_table[par[i]-40]<<4)
                    | foreground;
				break;
		}
    
	[self _update_attr]*/
    
}

void TermParser::CSI_DEC_PMS(bool _on)
{
    for(int i = 0; i < m_ParamsCnt; ++i)
        if(m_QuestionFlag)
            switch (m_Params[i]) /* DEC private modes set/reset */
            {
                case 1:			/* Cursor keys send ^[Ox/^[[x */
/*                    if (on_off)
                    {
                        set_kbd(decckm);
                    }
                    else
                    {
                        clr_kbd(decckm);
                    }*/
                    /*NOT YET IMPLEMENTED*/
                    break;
                case 6:			/* Origin relative/absolute */
                    m_LineAbs = !_on;
                    DoGoTo(0, 0);
                    break;
                case 7:			/* Autowrap on/off */
//                    decawm = on_off;
                    /*NOT YET IMPLEMENTED*/
                    printf("autowrap: %d\n", (int) _on);
                    break;
				case 47: // alternate screen buffer mode
					if(_on) m_Scr->SaveScreen();
					else    m_Scr->RestoreScreen();
					break;
                case 1048:
                    if(_on) {
                        m_DECPMS_SavedCurX = m_Scr->GetCursorX();
                        m_DECPMS_SavedCurY = m_Scr->GetCursorY();
                    }
                    else
                        m_Scr->GoTo(m_DECPMS_SavedCurX, m_DECPMS_SavedCurY);
                    break;
                case 1049:
                    if(_on) {
                        m_DECPMS_SavedCurX = m_Scr->GetCursorX();
                        m_DECPMS_SavedCurY = m_Scr->GetCursorY();
                        m_Scr->SaveScreen();
                        m_Scr->DoEraseScreen(2);
                    }
                    else {
                        m_Scr->GoTo(m_DECPMS_SavedCurX, m_DECPMS_SavedCurY);
                        m_Scr->RestoreScreen();
                    }
                    break;
                    
                    
/*
"Pm = 47"
h   Use Alternate Screen Buffer
l   Use Normal Screen Buffer
"Pm = 1047"
h   Use Alternate Screen Buffer
l   Use Normal Screen Buffer - clear Alternate Screen Buffer if returning from it
"Pm = 1048"
h   Save cursor position
l   Restore cursor position
"Pm = 1049"
h   Use Alternate Screen Buffer - clear Alternate Screen Buffer if switching to it
l   Use Normal Screen Buffer
*/
                default:
                    printf("unhandled CSI_DEC_PMS?: %d on:%d\n", m_Params[i], (int)_on);
            }
        else
            switch (m_Params[i]) /* ANSI modes set/reset */
            {
                case 4:			/* Insert Mode on/off */
//                    decim = on_off;
                    printf("insert: %d\n", (int)_on);
                    break;
                default:
                    printf("unhandled CSI_DEC_PMS: %d on:%d\n", m_Params[i], (int)_on);
            }
}

void TermParser::ProcessKeyDown(NSEvent *_event)
{
    NSString*  const character = [_event charactersIgnoringModifiers];
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
//    unsigned short const keycode = [_event keyCode];
//    NSLog(@"%i", (int) keycode);
    

//    static char buf[20];

    NSUInteger modflag = [_event modifierFlags];
    int mod=0;
    if((modflag & NSControlKeyMask) && (modflag&NSShiftKeyMask)) mod=6;
    else if(modflag & NSControlKeyMask) mod=5;
    else if(modflag & NSShiftKeyMask) mod=2;
    
    
    const char *seq_resp = 0;
//#define CURSOR_MOD_UP        "\033[1;%dA"
//#define KEY_FUNCTION_FORMAT  "\033[%d~"
    switch (unicode)
    {
        case NSUpArrowFunctionKey:      seq_resp = "\eOA"; break;
        case NSDownArrowFunctionKey:    seq_resp = "\eOB"; break;
        case NSRightArrowFunctionKey:   seq_resp = "\eOC"; break;
        case NSLeftArrowFunctionKey:    seq_resp = "\eOD"; break;
        case NSF1FunctionKey:           seq_resp = "\eOP"; break;
        case NSF2FunctionKey:           seq_resp = "\eOQ"; break;
        case NSF3FunctionKey:           seq_resp = "\eOR"; break;
        case NSF4FunctionKey:           seq_resp = "\eOS"; break;
        case NSF5FunctionKey:           seq_resp = "\e[15~"; break;
        case NSF6FunctionKey:           seq_resp = "\e[17~"; break;
        case NSF7FunctionKey:           seq_resp = "\e[18~"; break;
        case NSF8FunctionKey:           seq_resp = "\e[19~"; break;
        case NSF9FunctionKey:           seq_resp = "\e[20~"; break;
        case NSF10FunctionKey:          seq_resp = "\e[21~"; break;
        case NSF11FunctionKey:          seq_resp = "\e[23~"; break;
        case NSF12FunctionKey:          seq_resp = "\e[24~"; break;
        case NSHomeFunctionKey:         seq_resp = "\e[1~"; break;
        case NSInsertFunctionKey:       seq_resp = "\e[2~"; break;
        case NSDeleteFunctionKey:       seq_resp = "\e[3~"; break;
        case NSEndFunctionKey:          seq_resp = "\e[4~"; break;
        case NSPageUpFunctionKey:       seq_resp = "\e[5~"; break;
        case NSPageDownFunctionKey:     seq_resp = "\e[6~"; break;
        case 9: /* tab */
            if (modflag & NSShiftKeyMask) /* do we really getting these messages? */
                seq_resp = "\e[Z";
            else
                seq_resp = "\011";
            break;
            
//        case NSDownArrowFunctionKey: m_Task->WriteChildInput("\033[1B", 4); return;
//        case NSDownArrowFunctionKey: m_Task->WriteChildInput("\033OP", 3); return;
            
            /*
#define CURSOR_MOD_DOWN      "\033[1;%dB"
#define CURSOR_MOD_UP        "\033[1;%dA"
#define CURSOR_MOD_RIGHT     "\033[1;%dC"
#define CURSOR_MOD_LEFT      "\033[1;%dD"
*/
    }
    
    if(seq_resp != 0) {
        m_Task->WriteChildInput(seq_resp, (int)strlen(seq_resp));
        return;
        
    }
    
    // process regular keys down
    if(modflag & NSControlKeyMask) {
        unsigned short cc = 0xFFFF;
        if (unicode >= 'a' && unicode <= 'z')                           cc = unicode - 'a' + 1;
        else if (unicode == ' ' || unicode == '2' || unicode == '@')    cc = 0;
        else if (unicode == '[')                                        cc = 27;
        else if (unicode == '\\')                                       cc = 28;
        else if (unicode == ']')                                        cc = 29;
        else if (unicode == '^' || unicode == '6')                      cc = 30;
        else if (unicode == '-' || unicode == '_')                      cc = 31;
        m_Task->WriteChildInput(&cc, 1);
        return;
    }

    const char* utf8 = [character UTF8String];
    m_Task->WriteChildInput(utf8, (int)strlen(utf8));
    
//    unsigned char c = unicode;
//    m_Task->WriteChildInput(&c, 1);
}

void TermParser::CSI_n_P()
{
    int p = m_Params[0];
    
//    if(p + m_Scr->GetCursorX() >= m_Scr->GetWidth() )
//        p = m_Scr->GetWidth() - m_Scr->GetCursorX() - 1;
    if(p > m_Scr->GetWidth() - m_Scr->GetCursorX())
        p = m_Scr->GetWidth() - m_Scr->GetCursorX();
    else if(!p)
        p = 1;
    m_Scr->DoShiftRowLeft(p);
//    m_Scr->DoEraseCharacters(p);
    
/*	if (nr > width - x)
		nr = width - x;
	else if (!nr)
		nr = 1;
	delete_char(currcons, nr);*/
/*#define delete_char(foo,nr) do { \
[ts ts_shiftRow: y  at: x+nr  delta: -nr]; \
[ts ts_putChar: video_erase_char  count: nr  at: width-nr:y]; \
} while (0)*/
    /*	screen_char_t *aLine;
	int i;
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deleteCharacter]: %d", __FILE__, __LINE__, n);
#endif
    
    if (CURSOR_X >= 0 && CURSOR_X < WIDTH &&
        CURSOR_Y >= 0 && CURSOR_Y < HEIGHT)
    {
		int idx;
		
		idx=CURSOR_Y*WIDTH;
		if (n+CURSOR_X>WIDTH) n=WIDTH-CURSOR_X;
		
		// get the appropriate screen line
		aLine = [self getLineAtScreenIndex: CURSOR_Y];
		
		if (n<WIDTH)
		{
			memmove(aLine + CURSOR_X, aLine + CURSOR_X + n, (WIDTH-CURSOR_X-n)*sizeof(screen_char_t));
		}
		for(i = 0; i < n; i++)
		{
			aLine[WIDTH-n+i].ch = 0;
			aLine[WIDTH-n+i].fg_color = [TERMINAL foregroundColorCodeReal];
			aLine[WIDTH-n+i].bg_color = [TERMINAL backgroundColorCodeReal];
		}
		memset(dirty+idx+CURSOR_X,1,WIDTH-CURSOR_X);
    };*/
    
    
}

void TermParser::EscSave()
{
/*
 #define save_cur(foo) do { \
 saved_x		= x; \
 saved_y		= y; \
 s_intensity	= intensity; \
 s_underline	= underline; \
 s_blink		= blink; \
 s_reverse	= reverse; \
 s_charset	= charset; \
 s_color		= color; \
 saved_G0	= G0_charset; \
 saved_G1	= G1_charset; \
 } while (0)
 */
    m_State[0].x = m_Scr->GetCursorX();
    m_State[0].y = m_Scr->GetCursorY();
    memcpy(&m_State[1], &m_State[0], sizeof(m_State[0]));
}

void TermParser::EscRestore()
{
/*
 #define restore_cur(foo) do { \
 gotoxy(currcons,saved_x,saved_y); \
 intensity	= s_intensity; \
 underline	= s_underline; \
 blink		= s_blink; \
 reverse		= s_reverse; \
 charset		= s_charset; \
 color		= s_color; \
 G0_charset	= saved_G0; \
 G1_charset	= saved_G1; \
 translate	= set_translate(charset ? G1_charset : G0_charset,currcons); \
 } while (0)
 */
    memcpy(&m_State[0], &m_State[1], sizeof(m_State[0]));
    m_Scr->GoTo(m_State[0].x, m_State[0].y);
    SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
    UpdateAttrs();
}

void TermParser::CSI_n_r()
{
//Esc[Line;Liner	Set top and bottom lines of a window	DECSTBM
//    int a  =10;
    if(m_Params[0] == 0)  m_Params[0]++;
    if(m_Params[1] == 0)  m_Params[1] = m_Scr->GetHeight();

    // Minimum allowed region is 2 lines
    if(m_Params[0] < m_Params[1] && m_Params[1] <= m_Scr->GetHeight())
    {
        m_Top       = m_Params[0] - 1;
        m_Bottom    = m_Params[1];
//        DoGoTo(0, 0);
    }
}

void TermParser::DoGoTo(int _x, int _y)
{
    if(!m_LineAbs)
    {
        _y += m_Top;
        
        if(_y < m_Top) _y = m_Top;
        else if(_y >= m_Bottom) _y = m_Bottom - 1;
    }
    
    m_Scr->GoTo(_x, _y);
}

void TermParser::RI()
{
    if(m_Scr->GetCursorY() == m_Top)
        m_Scr->DoScrollDown(m_Top, m_Bottom, 1);
    else
        m_Scr->DoCursorUp();
}

void TermParser::LF()
{
    if(m_Scr->GetCursorY()+1 == m_Bottom)
        m_Scr->DoScrollUp(m_Top, m_Bottom, 1);
    else
        m_Scr->DoCursorDown();
}

void TermParser::CR()
{
    m_Scr->GoTo(0, m_Scr->GetCursorY());
}

void TermParser::HT()
{
    int x = m_Scr->GetCursorX();
    while(x < m_Scr->GetWidth() - 1) {
        ++x;
        if(m_TabStop[x >> 5] & (1 << (x & 31)))
            break;
    }
    m_Scr->GoTo(x, m_Scr->GetCursorY());
}