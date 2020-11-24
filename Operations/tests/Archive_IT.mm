// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include "../source/Copying/Copying.h"
#include "../source/Compression/Compression.h"
#include "Environment.h"
#include <sys/stat.h>

using namespace nc;
using namespace nc::ops;
using namespace std::literals;

#define PREFIX "Archive Tests: "

[[clang::no_destroy]] static const std::string g_Preffix =
    std::string(NCE(nc::env::test::ext_data_prefix)) + "archives/";
[[clang::no_destroy]] static const std::string g_Adium = g_Preffix + "adium.app.zip";
[[clang::no_destroy]] static const std::string g_Files = g_Preffix + "files-1.1.0(1341).zip";
[[clang::no_destroy]] static const std::string g_FileWithXAttr = "Leopard WaR3z.icns";

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result);

static std::vector<VFSListingItem> FetchItems(const std::string &_directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

TEST_CASE(PREFIX "adium.zip - copy from VFS")
{
    if( !std::filesystem::exists(g_Adium) ) {
        std::cout << "skipping test: no " << g_Adium << std::endl;
        return;
    }

    TempTestDir tmp_dir;
    std::shared_ptr<vfs::ArchiveHost> host;
    try {
        host = std::make_shared<vfs::ArchiveHost>(g_Adium.c_str(), TestEnv().vfs_native);
    } catch( VFSErrorException &e ) {
        REQUIRE(e.code() == 0);
        return;
    }

    CopyingOptions opts;
    Copying op(FetchItems("/", {"Adium.app"}, *host),
               tmp_dir.directory.native(),
               TestEnv().vfs_native,
               opts);
    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(
        VFSCompareEntries(
            "/Adium.app", host, tmp_dir.directory / "Adium.app", TestEnv().vfs_native, result) ==
        0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "extracted Files - signature")
{
    if( !std::filesystem::exists(g_Files) ) {
        std::cout << "skipping test: no " << g_Files << std::endl;
        return;
    }

    TempTestDir tmp_dir;
    std::shared_ptr<vfs::ArchiveHost> host;
    try {
        host = std::make_shared<vfs::ArchiveHost>(g_Files.c_str(), TestEnv().vfs_native);
    } catch( VFSErrorException &e ) {
        REQUIRE(e.code() == 0);
        return;
    }

    CopyingOptions opts;
    Copying op(FetchItems("/", {"Files.app"}, *host),
               tmp_dir.directory.native(),
               TestEnv().vfs_native,
               opts);
    op.Start();
    op.Wait();

    const auto command =
        "/usr/bin/codesign --verify "s + (tmp_dir.directory / "Files.app").native();
    REQUIRE(system(command.c_str()) == 0);
}

TEST_CASE(PREFIX "Compressing items with big xattrs")
{
    if( !std::filesystem::exists(g_Preffix + g_FileWithXAttr) ) {
        std::cout << "skipping test: no " << g_FileWithXAttr << std::endl;
        return;
    }

    TempTestDir tmp_dir;
    auto item = FetchItems(g_Preffix, {g_FileWithXAttr}, *TestEnv().vfs_native);

    Compression operation{item, tmp_dir.directory.native(), TestEnv().vfs_native};
    operation.Start();
    operation.Wait();

    std::shared_ptr<vfs::ArchiveHost> host;
    try {
        host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(),
                                                  TestEnv().vfs_native);
    } catch( VFSErrorException &e ) {
        REQUIRE(e.code() == 0);
        return;
    }

    int result = 0;
    REQUIRE(VFSCompareEntries("/" + g_FileWithXAttr,
                              host,
                              g_Preffix + g_FileWithXAttr,
                              TestEnv().vfs_native,
                              result) == 0);
    REQUIRE(result == 0);
}

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now

    VFSStat st1, st2;
    int ret;
    if( (ret = _file1_host->Stat(_file1_full_path.c_str(), st1, VFSFlags::F_NoFollow, 0)) < 0 )
        return ret;

    if( (ret = _file2_host->Stat(_file2_full_path.c_str(), st2, VFSFlags::F_NoFollow, 0)) < 0 )
        return ret;

    if( (st1.mode & S_IFMT) != (st2.mode & S_IFMT) ) {
        _result = -1;
        return 0;
    }

    if( S_ISREG(st1.mode) ) {
        if( int64_t(st1.size) - int64_t(st2.size) != 0 )
            _result = int(int64_t(st1.size) - int64_t(st2.size));
    } else if( S_ISLNK(st1.mode) ) {
        char link1[MAXPATHLEN], link2[MAXPATHLEN];
        if( (ret = _file1_host->ReadSymlink(_file1_full_path.c_str(), link1, MAXPATHLEN, 0)) < 0 )
            return ret;
        if( (ret = _file2_host->ReadSymlink(_file2_full_path.c_str(), link2, MAXPATHLEN, 0)) < 0 )
            return ret;
        if( strcmp(link1, link2) != 0 )
            _result = strcmp(link1, link2);
    } else if( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(
            _file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
                int ret = VFSCompareEntries(_file1_full_path / _dirent.name,
                                            _file1_host,
                                            _file2_full_path / _dirent.name,
                                            _file2_host,
                                            _result);
                if( ret != 0 )
                    return false;
                return true;
            });
    }
    return 0;
}
