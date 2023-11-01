// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SysLocale.h"
#include <locale.h>
#include <locale.h>
#include <fmt/format.h>
#include <CoreFoundation/CoreFoundation.h>

namespace nc::base {

void SetSystemLocaleAsCLocale() noexcept
{
    CFLocaleRef loc = CFLocaleCopyCurrent();
    assert(loc);
    if( loc == nullptr )
        abort();

    // NB! do not use CFLocaleGetIdentifier(), as it might contain additional information, e.g. "en_US@rg=gbzzzz"

    CFTypeRef language_cf = CFLocaleGetValue(loc, kCFLocaleLanguageCode);
    assert(language_cf);
    char language_c[256];
    if( !CFStringGetCString(
            static_cast<CFStringRef>(language_cf), language_c, sizeof(language_c) - 1, kCFStringEncodingUTF8) )
        abort();

    CFTypeRef country_cf = CFLocaleGetValue(loc, kCFLocaleCountryCode);
    assert(country_cf);
    char country_c[256];
    if( !CFStringGetCString(
            static_cast<CFStringRef>(country_cf), country_c, sizeof(country_c) - 1, kCFStringEncodingUTF8) )
        abort();

    const std::string locale = fmt::format("{}_{}.UTF-8", language_c, country_c);
    if( setlocale(LC_ALL, locale.c_str()) == nullptr ) {
        fmt::print(stderr, "failed to set C locale to '{}', aborting\n", locale);
        abort();
    }
}

} // namespace nc::base
