// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UTIImpl.h"
#include "UnitTests_main.h"

using nc::utility::UTIDBImpl;

#define PREFIX "nc::utility::UTIDBImpl "
TEST_CASE(PREFIX "getting uti by extension works")
{
    const UTIDBImpl db;
    CHECK(db.UTIForExtension("jpg") == "public.jpeg");
    CHECK(db.UTIForExtension("icns") == "com.apple.icns");
    CHECK(db.UTIForExtension("pdf") == "com.adobe.pdf");
}

TEST_CASE(PREFIX "getting uti by extension is case insensitive")
{
    const UTIDBImpl db;
    CHECK(db.UTIForExtension("jpg") == "public.jpeg");
    CHECK(db.UTIForExtension("JPG") == "public.jpeg");
    CHECK(db.UTIForExtension("Jpg") == "public.jpeg");
    CHECK(db.UTIForExtension("jPG") == "public.jpeg");
}

TEST_CASE(PREFIX "IsDeclaredUTI works")
{
    const UTIDBImpl db;
    CHECK(db.IsDeclaredUTI("public.jpeg") == true);
    CHECK(db.IsDeclaredUTI("com.apple.icns") == true);
    CHECK(db.IsDeclaredUTI("com.adobe.pdf") == true);
    CHECK(db.IsDeclaredUTI("com.adobe.abracadabra") == false);
}

TEST_CASE(PREFIX "IsDynamicUTI works")
{
    const UTIDBImpl db;
    CHECK(db.IsDynamicUTI("dyn.ah62d4r34gq81k3p2su1zuppgsm10esvvhzxhe55c") == true);
    CHECK(db.IsDynamicUTI("com.apple.icns") == false);
    CHECK(db.IsDynamicUTI("") == false);
}

TEST_CASE(PREFIX "UTI for non-existing extensions is dynamic")
{
    const UTIDBImpl db;
    CHECK(db.IsDynamicUTI(db.UTIForExtension("iasgduygdiuwbuiwebvciuewtvciue")) == true);
    CHECK(db.IsDynamicUTI(db.UTIForExtension("")) == true);
}

TEST_CASE(PREFIX "ConformsTo works")
{
    const UTIDBImpl db;
    CHECK(db.ConformsTo("public.jpeg", "public.image") == true);
    CHECK(db.ConformsTo("public.jpeg", "public.content") == true);
    CHECK(db.ConformsTo("public.jpeg", "public.text") == false);
    CHECK(db.ConformsTo("", "public.text") == false);
    CHECK(db.ConformsTo("public.jpeg", "") == false);
    CHECK(db.ConformsTo("public.volume", "public.folder") == true);
    CHECK(db.ConformsTo("public.folder", "public.volume") == false);
    CHECK(db.ConformsTo("public.volume", "public.directory") == true);
    CHECK(db.ConformsTo("public.volume", "public.item") == true);
    CHECK(db.ConformsTo("public.folder", "public.directory") == true);
}
