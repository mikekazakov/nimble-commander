// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UTIImpl.h"
#include "UnitTests_main.h"

using nc::utility::UTIDBImpl;

#define PREFIX "nc::utility::UTIDBImpl "
TEST_CASE(PREFIX "getting uti by extension works")
{
    UTIDBImpl db;
    CHECK(db.UTIForExtension("jpg") == "public.jpeg");
    CHECK(db.UTIForExtension("icns") == "com.apple.icns");
    CHECK(db.UTIForExtension("pdf") == "com.adobe.pdf");
}

TEST_CASE(PREFIX "getting uti by extension is case insensitive")
{
    UTIDBImpl db;
    CHECK(db.UTIForExtension("jpg") == "public.jpeg");
    CHECK(db.UTIForExtension("JPG") == "public.jpeg");
    CHECK(db.UTIForExtension("Jpg") == "public.jpeg");
    CHECK(db.UTIForExtension("jPG") == "public.jpeg");
}
