// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/Mem.h>
#include <Base/algo.h>

using namespace nc::vfs;
// using nc::vfs::MemHost;
#define PREFIX "VFSMem "

// static VFSNativeHost& host()
//{
//     return *TestEnv().vfs_native;
// }
//
// static bool ListingHas(const Listing& listing, const std::string& _filename){
//     return std::any_of(listing.begin(), listing.end(), [&](auto &item){
//         return item.Filename() == _filename;
//     });
// };
//
// static bool ListingHas(const VFSListingPtr& listing, const std::string& _filename){
//     return ListingHas(*listing, _filename);
// };

TEST_CASE(PREFIX "constructible")
{
    REQUIRE_NOTHROW(std::make_shared<MemHost>());
}
