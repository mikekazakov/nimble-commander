// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <NativeSpecialDirectories.h>
#include <Habanero/algo.h>

using namespace nc::vfs;
using namespace nc::vfs::native;
#define PREFIX "[nc::vfs::native] "

static VFSNativeHost& host()
{
    return *TestEnv().vfs_native;
}

static bool ListingHas(const Listing& listing, const std::string& _filename){
    return std::any_of(listing.begin(), listing.end(), [&](auto &item){
        return item.Filename() == _filename;
    });
};

static bool ListingHas(const VFSListingPtr& listing, const std::string& _filename){
    return ListingHas(*listing, _filename);
};

TEST_CASE(PREFIX "Does produces unified Application directory")
{    
    const auto marker_path = "/Applications/__nc_fetch_probe__";
    auto rm_marker = [&]{ unlink(marker_path); };
    rm_marker();
    REQUIRE( close( creat( marker_path, 0755 ) ) == 0 );
    auto marker_cleanup = at_scope_end([&]{ rm_marker(); });

    VFSListingPtr listing;
    int rc = 0; 
    SECTION("No ..") {
        rc = FetchUnifiedApplicationsListing(host(), listing, Flags::F_NoDotDot, {});
    }
    SECTION("With ..") {
        rc = FetchUnifiedApplicationsListing(host(), listing, Flags::None, {});
    }
    
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(listing != nullptr);
    REQUIRE(listing->IsUniform() == false);    
    CHECK( ListingHas(listing, "..") == false );
    CHECK( ListingHas(listing, "Mail.app") );
    CHECK( ListingHas(listing, "__nc_fetch_probe__") );
    CHECK( ListingHas(listing, "some_meaningless_rubbish_that_nobody_would_every_have") == false );
}

TEST_CASE(PREFIX "FetchUnifiedListing fetches contents from both directories")
{
    TestDir test_dir_holder;
    std::string test_dir = test_dir_holder.directory; 
    
    REQUIRE( mkdir((test_dir + "A").c_str(), 0755) == 0);
    REQUIRE( mkdir((test_dir + "B").c_str(), 0755) == 0);
    REQUIRE( close( creat( (test_dir + "A/a").c_str(), 0755 ) ) == 0 );
    REQUIRE( close( creat( (test_dir + "B/b").c_str(), 0755 ) ) == 0 );

    VFSListingPtr listing;
    const int rc = FetchUnifiedListing(host(),
                                       (test_dir + "A").c_str(),
                                       (test_dir + "B").c_str(),
                                       listing,
                                       VFSFlags::None,
                                       {} );
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(listing != nullptr);
    REQUIRE(listing->IsUniform() == false);
    CHECK( listing->Count() == 2 );
    CHECK( ListingHas(listing, "a") );
    CHECK( ListingHas(listing, "b") );
}

TEST_CASE(PREFIX "FetchUnifiedListing succeeds when user directory doesn't exist")
{
    TestDir test_dir_holder;
    std::string test_dir = test_dir_holder.directory; 
    
    REQUIRE( mkdir((test_dir + "A").c_str(), 0755) == 0);
    REQUIRE( close( creat( (test_dir + "A/a").c_str(), 0755 ) ) == 0 );

    VFSListingPtr listing;
    const int rc = FetchUnifiedListing(host(),
                                       (test_dir + "A").c_str(),
                                       (test_dir + "B").c_str(),
                                       listing,
                                       VFSFlags::None,
                                       {} );
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(listing != nullptr);
    REQUIRE(listing->IsUniform() == true);
    CHECK( listing->Count() == 1 );
    CHECK( ListingHas(listing, "a") );
}
