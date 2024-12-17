// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <catch2/catch_all.hpp>
#include <filesystem>
#include <Utility/FSEventsFileUpdate.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <memory>

struct TempTestDir {
    TempTestDir();
    ~TempTestDir();
    std::filesystem::path directory;
};

struct TestEnvironment {
    std::shared_ptr<nc::utility::FSEventsFileUpdate> fsevents_file_update;
    std::shared_ptr<nc::utility::NativeFSManager> native_fs_man;
    std::shared_ptr<nc::vfs::NativeHost> vfs_native;
};

const TestEnvironment &TestEnv() noexcept;
