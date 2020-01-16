// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <memory>

struct TestEnvironment {
    std::shared_ptr<nc::utility::NativeFSManager> native_fs_man; 
    std::shared_ptr<nc::vfs::NativeHost> vfs_native;
};

const TestEnvironment& TestEnv() noexcept;
