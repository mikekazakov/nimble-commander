// Copyright (C) 2020-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TestEnv.h"
#include <Utility/FSEventsFileUpdateImpl.h>
#include <Utility/NativeFSManagerImpl.h>
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
