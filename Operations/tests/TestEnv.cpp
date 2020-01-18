// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TestEnv.h"
#include <memory>

const TestEnvironment& TestEnv() noexcept
{
    static const std::unique_ptr<TestEnvironment> env = []{
        auto e = std::make_unique<TestEnvironment>();
        e->native_fs_man = std::make_shared<nc::utility::NativeFSManager>();
        e->vfs_native = std::make_shared<nc::vfs::NativeHost>( *e->native_fs_man );
        return e;
    }();
    return *env;
}
