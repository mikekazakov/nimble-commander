// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <VFSIcon/WorkspaceExtensionIconsCacheImpl.h>

using namespace nc::vfsicon;

TEST_CASE("WorkspaceExtensionIconsCacheImpl is initially empty")
{
    WorkspaceExtensionIconsCacheImpl cache{};
    CHECK( cache.CachedIconForExtension("jpg") == nil );
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl produces an image for a valid extension")
{
    WorkspaceExtensionIconsCacheImpl cache{};
    CHECK( cache.IconForExtension("jpg") != nil );
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl caches the produced result")
{
    WorkspaceExtensionIconsCacheImpl cache{};
    cache.IconForExtension("jpg");
    CHECK( cache.CachedIconForExtension("jpg") != nil );
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl doesn't produces an image for invalid extensions")
{
    WorkspaceExtensionIconsCacheImpl cache{};
    CHECK( cache.IconForExtension("zxcdsfjkhsbvfwefuvksdvf34534sdf") == nil );
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl provides default images")
{
    WorkspaceExtensionIconsCacheImpl cache{};
    CHECK( cache.GenericFileIcon() != nil );
    CHECK( cache.GenericFolderIcon() != nil );
}
