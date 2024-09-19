// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/ExtensionsWhitelistImpl.h>
#include <Utility/UTIImpl.h>
#include "Tests.h"

#define PREFIX "ExtensionsWhitelistImpl "

TEST_CASE(PREFIX "tests")
{
    const nc::utility::UTIDBImpl uti_db;
    const nc::vfsicon::ExtensionsWhitelistImpl whitelist(uti_db, {"public.image", "public.movie"});
    CHECK(whitelist.AllowExtension("jpg"));
    CHECK(whitelist.AllowExtension("png"));
    CHECK(whitelist.AllowExtension("tiff"));
    CHECK(whitelist.AllowExtension("mov"));
    CHECK(whitelist.AllowExtension("avi"));

    CHECK(not whitelist.AllowExtension("cpp"));
    CHECK(not whitelist.AllowExtension("mm"));
    CHECK(not whitelist.AllowExtension(""));
    CHECK(not whitelist.AllowExtension("txt"));
}
