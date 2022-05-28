// Copyright (C) 2013-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CLI.h"
#include <Habanero/CFPtr.h>
#include <string_view>

extern "C" int NSApplicationMain(int argc, const char *argv[]);

static void SetLocale()
{
    const auto current_locale = nc::base::CFPtr<CFLocaleRef>::adopt(CFLocaleCopyCurrent());
    const CFStringRef cf_ident = CFLocaleGetIdentifier(current_locale.get());
    char buf[256] = "en_US";
    CFStringGetCString(cf_ident, buf, sizeof(buf) - 1, kCFStringEncodingUTF8);
    strcat(buf, ".UTF-8");
    setlocale(LC_ALL, buf);
}

int main(int argc, char *argv[])
{
    nc::bootstrap::ProcessCLIUsage(argc, argv);
    if( !std::string_view(setlocale(LC_COLLATE, nullptr)).contains("UTF-8") )
        SetLocale();
    return NSApplicationMain(argc, const_cast<const char **>(argv));
}
