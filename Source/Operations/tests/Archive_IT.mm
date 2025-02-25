// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

static std::expected<int, Error> VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                                                   const VFSHostPtr &_file1_host,
                                                   const std::filesystem::path &_file2_full_path,
                                                   const VFSHostPtr &_file2_host);
static std::vector<std::byte> MakeNoise(size_t _size);

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    return _host.FetchFlexibleListingItems(_directory_path, _filenames, 0).value_or(std::vector<VFSListingItem>{});
}

TEST_CASE(PREFIX "valid signature after extracting an application")
{
    const TempTestDir tmp_dir;
    const auto source_fn = "Chess.app";
    const auto source_dir = std::filesystem::path("/System/Applications");
    const auto source_path = source_dir / source_fn;
    auto item = FetchItems(source_dir, {source_fn}, *TestEnv().vfs_native);
    Compression comp_operation{item, tmp_dir.directory.native(), TestEnv().vfs_native};
    comp_operation.Start();
    comp_operation.Wait();
    REQUIRE(comp_operation.State() == nc::ops::OperationState::Completed);
    const auto archive_path = comp_operation.ArchivePath();
    const auto host = std::make_shared<vfs::ArchiveHost>(archive_path.c_str(), TestEnv().vfs_native);
    REQUIRE(VFSCompareEntries("/"s + source_fn, host, source_path, TestEnv().vfs_native).value() == 0);

    const CopyingOptions copy_opts;
    Copying copy_operation(
        FetchItems("/", {source_fn}, *host), tmp_dir.directory.native(), TestEnv().vfs_native, copy_opts);
    copy_operation.Start();
    copy_operation.Wait();
    REQUIRE(copy_operation.State() == nc::ops::OperationState::Completed);

    const auto command = "/usr/bin/codesign --verify --no-strict "s + (tmp_dir.directory / source_fn).native();
    REQUIRE(system(command.c_str()) == 0);
}

TEST_CASE(PREFIX "Compressing an item with big xattrs")
{
    const TempTestDir tmp_dir;
    const auto source_fn = "file";
    const auto xattr_name = "some_xattr";
    const auto source_path = tmp_dir.directory / source_fn;
    const auto xattr_size = size_t(543210);
    const auto orig_noise = MakeNoise(xattr_size);
    REQUIRE(close(creat(source_path.c_str(), 0755)) == 0);
    REQUIRE(setxattr(source_path.c_str(), xattr_name, orig_noise.data(), xattr_size, 0, 0) == 0);
    auto item = FetchItems(tmp_dir.directory, {source_fn}, *TestEnv().vfs_native);

    Compression operation{item, tmp_dir.directory.native(), TestEnv().vfs_native};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == nc::ops::OperationState::Completed);

    const auto host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), TestEnv().vfs_native);
    const VFSFilePtr file = host->CreateFile("/"s + source_fn).value();
    REQUIRE(file != nullptr);
    REQUIRE(file->Open(nc::vfs::Flags::OF_Read) == 0);
    CHECK(file->Size() == 0);
    std::vector<std::byte> unpacked_noise(xattr_size);
    REQUIRE(file->XAttrGet(xattr_name, unpacked_noise.data(), xattr_size) == xattr_size);
    CHECK(orig_noise == unpacked_noise);
}

static std::expected<int, Error> VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                                                   const VFSHostPtr &_file1_host,
                                                   const std::filesystem::path &_file2_full_path,
                                                   const VFSHostPtr &_file2_host)
{
    // not comparing flags, perm, times, xattrs, acls etc now

    const std::expected<VFSStat, Error> st1 = _file1_host->Stat(_file1_full_path.c_str(), VFSFlags::F_NoFollow);
    if( !st1 )
        return std::unexpected(st1.error());

    const std::expected<VFSStat, Error> st2 = _file2_host->Stat(_file2_full_path.c_str(), VFSFlags::F_NoFollow);
    if( !st2 )
        return std::unexpected(st2.error());

    if( (st1->mode & S_IFMT) != (st2->mode & S_IFMT) ) {
        return -1;
    }

    if( S_ISREG(st1->mode) ) {
        if( int64_t(st1->size) - int64_t(st2->size) != 0 )
            return int(int64_t(st1->size) - int64_t(st2->size));
    }
    else if( S_ISLNK(st1->mode) ) {
        const std::expected<std::string, Error> link1 = _file1_host->ReadSymlink(_file1_full_path.c_str());
        if( !link1 )
            return std::unexpected(link1.error());

        const std::expected<std::string, Error> link2 = _file2_host->ReadSymlink(_file2_full_path.c_str());
        if( !link2 )
            return std::unexpected(link2.error());

        if( strcmp(link1->c_str(), link2->c_str()) != 0 )
            return strcmp(link1->c_str(), link2->c_str());
    }
    else if( S_ISDIR(st1->mode) ) {
        std::expected<int, Error> result = 0;
        std::ignore = _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            result = VFSCompareEntries(
                _file1_full_path / _dirent.name, _file1_host, _file2_full_path / _dirent.name, _file2_host);
            return result.has_value();
        });
        return result;
    }
    return 0;
}

static std::vector<std::byte> MakeNoise(size_t _size)
{
    std::vector<std::byte> bytes(_size);
    for( auto &b : bytes )
        b = static_cast<std::byte>(std::rand() % 256);
    return bytes;
}
