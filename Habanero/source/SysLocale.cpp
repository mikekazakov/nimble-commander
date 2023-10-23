// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SysLocale.h"
#include <locale.h>
#include <CoreFoundation/CoreFoundation.h>

namespace nc::base {

void SetSystemLocaleAsCLocale() noexcept
{
    CFLocaleRef loc = CFLocaleCopyCurrent();
    if( loc == nullptr )
        abort();
    CFStringRef ident = CFLocaleGetIdentifier(loc);
    if( ident == nullptr )
        abort();
    char locale[256];
    if( auto l = CFStringGetCStringPtr(ident, kCFStringEncodingUTF8) )
        strcpy(locale, l);
    else
        CFStringGetCString(ident, locale, sizeof(locale) - 1, kCFStringEncodingUTF8);
    CFRelease(loc);
    strcat(locale, ".UTF-8");
    if( setlocale(LC_ALL, locale) == nullptr )
        abort();
}

} // namespace nc::base
