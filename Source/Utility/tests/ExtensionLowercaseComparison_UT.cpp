// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "ExtensionLowercaseComparison.h"
#include <string_view>

#define PREFIX "nc::utility::ExtensionLowercaseComparison "

using nc::utility::ExtensionsLowercaseList;

TEST_CASE(PREFIX "ExtensionsLowercaseList - empty")
{
    const ExtensionsLowercaseList l({});
    CHECK(l.contains("png") == false);
    CHECK(l.contains("") == false);
}

TEST_CASE(PREFIX "ExtensionsLowercaseList - Basic usage scenario")
{
    const ExtensionsLowercaseList l("    ,jpg    ,    PNG   ,TxT");
    CHECK(l.contains("png") == true);
    CHECK(l.contains("Png") == true);
    CHECK(l.contains("PNG") == true);
    CHECK(l.contains("jpg") == true);
    CHECK(l.contains("JPG") == true);
    CHECK(l.contains("jpG") == true);
    CHECK(l.contains("txt") == true);
    CHECK(l.contains("TxT") == true);
    CHECK(l.contains("TXT") == true);
    CHECK(l.contains("") == false);
    CHECK(l.contains(",") == false);
}

TEST_CASE(PREFIX "ExtensionsLowercaseList - Long ext")
{
    const ExtensionsLowercaseList l("This_Is_A_Very_Long_Extension_That_Cannot_For_Sure_Fit_Into_SBO");
    CHECK(l.contains("this_is_a_very_long_extension_that_cannot_for_sure_fit_into_sbo") == true);
}
