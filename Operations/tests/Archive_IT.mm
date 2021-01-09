// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include "../source/Copying/Copying.h"
#include "../source/Compression/Compression.h"
#include <sys/stat.h>
#include <sys/xattr.h>
#include <vector>

using namespace nc;
using namespace nc::ops;
using namespace std::literals;

#define PREFIX "Archive Tests: "

// TODO: are these Compression or Copying tests in the end? need to decide.

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result);
static std::vector<std::byte> MakeNoise(size_t _size);

static std::vector<VFSListingItem> FetchItems(const std::string &_directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

TEST_CASE(PREFIX "valid signature after extracting an application")
{
    TempTestDir tmp_dir;
    const auto source_fn = "Chess.app";
    const auto source_dir = std::filesystem::path("/System/Applications");
    const auto source_path = source_dir/source_fn;
    auto item = FetchItems(source_dir, {source_fn}, *TestEnv().vfs_native);
    Compression comp_operation{item, tmp_dir.directory.native(), TestEnv().vfs_native};
    comp_operation.Start();
    comp_operation.Wait();
    REQUIRE( comp_operation.State() == nc::ops::OperationState::Completed );
    const auto archive_path = comp_operation.ArchivePath();
    const auto host = std::make_shared<vfs::ArchiveHost>(archive_path.c_str(),
                                                         TestEnv().vfs_native);
    int cmp_result = 0;
    REQUIRE(VFSCompareEntries("/"s + source_fn, host, source_path, TestEnv().vfs_native, cmp_result)
            == 0);
    REQUIRE(cmp_result == 0);

    CopyingOptions copy_opts;
    Copying copy_operation(FetchItems("/", {source_fn}, *host),
               tmp_dir.directory.native(),
               TestEnv().vfs_native,
               copy_opts);
    copy_operation.Start();
    copy_operation.Wait();
    REQUIRE( copy_operation.State() == nc::ops::OperationState::Completed );

    const auto command =
        "/usr/bin/codesign --verify --no-strict "s + (tmp_dir.directory / source_fn).native();
    REQUIRE(system(command.c_str()) == 0);
}

TEST_CASE(PREFIX "Compressing an item with big xattrs")
{
    TempTestDir tmp_dir;
    const auto source_fn = "file";
    const auto xattr_name = "some_xattr";
    const auto source_path = tmp_dir.directory/source_fn;
    const auto xattr_size = size_t(543210);
    const auto orig_noise = MakeNoise(xattr_size);
    REQUIRE( close( creat(source_path.c_str(), 0755) ) == 0 );
    REQUIRE( setxattr(source_path.c_str(), xattr_name, orig_noise.data(), xattr_size, 0, 0) == 0);
    auto item = FetchItems(tmp_dir.directory, {source_fn}, *TestEnv().vfs_native);

    Compression operation{item, tmp_dir.directory.native(), TestEnv().vfs_native};
    operation.Start();
    operation.Wait();
    REQUIRE( operation.State() == nc::ops::OperationState::Completed );

    const auto host =
    std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), TestEnv().vfs_native);
    VFSFilePtr file;
    REQUIRE( host->CreateFile(("/"s + source_fn).c_str(), file, {}) == 0 );
    REQUIRE( file != nullptr );
    REQUIRE( file->Open(nc::vfs::Flags::OF_Read) == 0 );
    CHECK( file->Size() == 0 );
    std::vector<std::byte> unpacked_noise(xattr_size);
    REQUIRE( file->XAttrGet(xattr_name, unpacked_noise.data(), xattr_size) == xattr_size);
    CHECK( orig_noise == unpacked_noise );
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

static std::vector<std::byte> MakeNoise(size_t _size)
{
    std::vector<std::byte> bytes(_size);
    for( auto &b: bytes )
        b = static_cast<std::byte>(std::rand() % 256);
    return bytes;
}
