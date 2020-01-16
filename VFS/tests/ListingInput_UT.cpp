// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFSListingInput.h>
#include <Native.h>
#include <VFSDeclarations.h>

using namespace nc::vfs;
#define PREFIX "[nc::vfs::ListingInput] "

TEST_CASE(PREFIX"Title is preserved after building")
{
    ListingInput input;
    input.title = "Test";
    input.hosts.insert(0, TestEnv().vfs_native);
    input.directories.insert(0, "/");
    auto listing = Listing::Build(std::move(input));
    REQUIRE(listing);
    CHECK( listing->Title() == "Test" );
}

TEST_CASE(PREFIX"Title is preserved after updating")
{
    ListingInput input;
    input.title = "Test";
    input.hosts.insert(0, TestEnv().vfs_native);
    input.directories.insert(0, "/");
    auto orig_listing = Listing::Build(std::move(input));
    REQUIRE(orig_listing);
    auto updated_listing = Listing::ProduceUpdatedTemporaryPanelListing(*orig_listing, {});
    REQUIRE(updated_listing);
    CHECK( updated_listing->Title() == "Test" );
}
