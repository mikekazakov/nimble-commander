// Copyright (C) 2020-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include "../source/Deletion/Deletion.h"
#include "Environment.h"
#include <sys/stat.h>

using namespace nc;
using namespace nc::ops;

#define PREFIX "Operations::Deletion "

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host);

TEST_CASE(PREFIX "Allows cancellation on the phase of source items scanning")
{
    struct MyHost : vfs::NativeHost {
        //        MyHost(nc::utility::NativeFSManager &_native_fs_man) : NativeHost(_native_fs_man) {}
        using NativeHost::NativeHost;
        std::expected<void, Error>
        IterateDirectoryListing(std::string_view _path,
                                const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override
        {
            if( on_iterate_directorying_listing )
                on_iterate_directorying_listing(_path);
            return NativeHost::IterateDirectoryListing(_path, _handler);
        }
        std::function<void(std::string_view _path)> on_iterate_directorying_listing;
    };
    auto native_host = std::make_shared<MyHost>(*TestEnv().native_fs_man, *TestEnv().fsevents_file_update);
    const TempTestDir tmp_dir;
    const auto &d = tmp_dir.directory;
    std::filesystem::create_directories(d / "top/first/second");

    Deletion operation{FetchItems(tmp_dir.directory, {"top"}, *native_host), DeletionType::Permanent};
    SECTION("Top level")
    {
        native_host->on_iterate_directorying_listing = [&](std::string_view _path) {
            if( (d / "top") == _path )
                operation.Stop();                       // stop as soon as this dir is touched
            REQUIRE((d / "top/first") != _path);        // musn't go here later
            REQUIRE((d / "top/first/second") != _path); // musn't go here later
        };
    }
    SECTION("First nested level")
    {
        native_host->on_iterate_directorying_listing = [&](std::string_view _path) {
            if( (d / "top/first") == _path )
                operation.Stop();                       // stop as soon as this dir is touched
            REQUIRE((d / "top/first/second") != _path); // musn't go here later
        };
    }
    operation.Start();
    operation.Wait();

    CHECK(operation.State() == OperationState::Stopped);
    CHECK(std::filesystem::exists(d / "top/first/second"));
}

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    return _host.FetchFlexibleListingItems(_directory_path, _filenames, 0).value_or(std::vector<VFSListingItem>{});
}
