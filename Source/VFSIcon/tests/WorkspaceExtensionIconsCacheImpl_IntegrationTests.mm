// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <VFSIcon/WorkspaceExtensionIconsCacheImpl.h>
#include <Utility/UTIImpl.h>

using namespace nc::vfsicon;
using nc::utility::UTIDBImpl;

TEST_CASE("WorkspaceExtensionIconsCacheImpl is initially empty")
{
    UTIDBImpl utidb;
    WorkspaceExtensionIconsCacheImpl cache{utidb};
    CHECK(cache.CachedIconForExtension("jpg") == nil);
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl produces an image for a valid extension")
{
    UTIDBImpl utidb;
    WorkspaceExtensionIconsCacheImpl cache{utidb};
    CHECK(cache.IconForExtension("jpg") != nil);
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl caches the produced result")
{
    UTIDBImpl utidb;
    WorkspaceExtensionIconsCacheImpl cache{utidb};
    cache.IconForExtension("jpg");
    CHECK(cache.CachedIconForExtension("jpg") != nil);
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl doesn't produces an image for invalid extensions")
{
    UTIDBImpl utidb;
    WorkspaceExtensionIconsCacheImpl cache{utidb};
    CHECK(cache.IconForExtension("zxcdsfjkhsbvfwefuvksdvf34534sdf") == nil);
}

TEST_CASE("WorkspaceExtensionIconsCacheImpl provides default images")
{
    UTIDBImpl utidb;
    WorkspaceExtensionIconsCacheImpl cache{utidb};
    CHECK(cache.GenericFileIcon() != nil);
    CHECK(cache.GenericFolderIcon() != nil);
}
