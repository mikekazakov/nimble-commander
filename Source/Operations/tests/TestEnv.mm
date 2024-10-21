// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TestEnv.h"
#include <Utility/FSEventsFileUpdateImpl.h>
#include <Utility/NativeFSManagerImpl.h>
#include <VFS/NetSFTP.h>
#include <memory>

const TestEnvironment &TestEnv() noexcept
{
    [[clang::no_destroy]] static const std::unique_ptr<TestEnvironment> env = [] {
        auto e = std::make_unique<TestEnvironment>();
        e->fsevents_file_update = std::make_shared<nc::utility::FSEventsFileUpdateImpl>();
        e->native_fs_man = std::make_shared<nc::utility::NativeFSManagerImpl>();
        e->vfs_native = std::make_shared<nc::vfs::NativeHost>(*e->native_fs_man, *e->fsevents_file_update);
        return e;
    }();
    return *env;
}

std::shared_ptr<nc::vfs::SFTPHost> TestEnvironment::SpawnSFTPHost()
{
    // TODO: remove the evil copy&paste of the config
    const auto ubuntu2004_address = "127.0.0.1";
    const auto ubuntu2004_port = 9022;
    const auto ubuntu2004_user = "user1";
    const auto ubuntu2004_passwd = "Oc6har5tOu34";
    return std::make_shared<nc::vfs::SFTPHost>(
        ubuntu2004_address, ubuntu2004_user, ubuntu2004_passwd, "", ubuntu2004_port);
}
