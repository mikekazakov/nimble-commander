// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SysLocale.h"
#include <CoreFoundation/CoreFoundation.h>
#include <clocale>
#include <filesystem>
#include <fmt/format.h>
#include <vector>

namespace nc::base {

static std::string GetLocaleValue(CFLocaleRef _locale, CFLocaleKey _key)
{
    CFTypeRef value_cf = CFLocaleGetValue(_locale, _key);
    assert(value_cf);
    char value_c[256];
    if( !CFStringGetCString(static_cast<CFStringRef>(value_cf), value_c, sizeof(value_c) - 1, kCFStringEncodingUTF8) )
        abort();

    return value_c;
}

static std::vector<std::string> ListAllLocales()
{
    const std::filesystem::path dir{"/usr/share/locale"};
    std::vector<std::string> list;
    std::error_code ec;
    for( const auto &dir_entry : std::filesystem::directory_iterator{dir, ec} )
        list.push_back(dir_entry.path().filename());
    return list;
}

void SetSystemLocaleAsCLocale() noexcept
{
    CFLocaleRef loc = CFLocaleCopyCurrent();
    assert(loc);
    if( loc == nullptr )
        abort();

    // NB! do not use CFLocaleGetIdentifier(), as it might contain additional information, e.g. "en_US@rg=gbzzzz"
    const std::string language = GetLocaleValue(loc, kCFLocaleLanguageCode);
    const std::string country = GetLocaleValue(loc, kCFLocaleCountryCode);
    CFRelease(loc);

    // By default let's assume a sane combination of language+country and try that a locale
    const std::string locale = fmt::format("{}_{}.UTF-8", language, country);
    if( setlocale(LC_ALL, locale.c_str()) != nullptr ) {
        // we're happy campers - this combination of language_COUNTRY is a valid locale, done.
        return;
    }

    // try to find a suitable locale for this language manually
    const std::vector<std::string> locales = ListAllLocales();
    const std::string name_prefix = language + "_";
    for( const std::string &name : locales ) {
        if( name.starts_with(name_prefix) && name.ends_with(".UTF-8") ) {
            // looks suitable, try this one
            if( setlocale(LC_ALL, name.c_str()) != nullptr ) {
                // we've set something with this language and UTF-8 as a fallback
                return;
            }
        }
    }

    // as a last resort, if nothing works, fall back to en_US.UTF-8
    setlocale(LC_ALL, "en_US.UTF-8");
}

} // namespace nc::base
