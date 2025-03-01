// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/PS.h>

using namespace nc::vfs;

#define PREFIX "VFSPS "

TEST_CASE(PREFIX "basic test")
{
    auto host = std::make_shared<PSHost>();
    const VFSListingPtr list = host->FetchDirectoryListing("/", 0).value();

    bool has_launchd = false;
    bool has_kernel_task = false;
    for( auto &i : *list ) {
        if( "    0 - kernel_task.txt" == i.Filename() )
            has_kernel_task = true;
        if( "    1 - launchd.txt" == i.Filename() )
            has_launchd = true;
    }

    CHECK(has_launchd == true);
    CHECK(has_kernel_task == true);
    CHECK(list->Count() > 100); // presumably any modern OSX will have more than 100 processes
}

TEST_CASE(PREFIX "can read info about kernel_task")
{
    auto host = std::make_shared<PSHost>();
    const VFSListingPtr list = host->FetchDirectoryListing("/", 0).value();

    auto it = std::find_if(
        list->begin(), list->end(), [](const auto &item) { return item.Filename().ends_with("kernel_task.txt"); });
    REQUIRE(it != list->end());
    const auto &kernel_task_listing_item = *it;

    const VFSFilePtr file = host->CreateFile(kernel_task_listing_item.Path()).value();
    REQUIRE(file->Open(Flags::OF_Read) == 0);
    const auto file_contents = file->ReadFile();
    REQUIRE(file_contents);
    REQUIRE(!file_contents->empty());
    const std::string_view proc_info(reinterpret_cast<const char *>(file_contents->data()), file_contents->size());

    CHECK(proc_info.contains("Name: kernel_task"));
    CHECK(proc_info.contains("Process user id: 0 (root)"));
}
