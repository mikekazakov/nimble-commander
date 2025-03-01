// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "NCE.h"
#include <VFS/NetDropbox.h>
#include <VFS/../../source/NetDropbox/File.h>
#include <set>

using namespace nc;
using namespace nc::vfs;
using namespace std::string_literals;

static const auto g_Account = NCE(nc::env::test::dropbox_account);
static const auto g_Token = NCE(nc::env::test::dropbox_token);
static std::vector<uint8_t> MakeNoise(size_t size);

#define PREFIX "VFSDropbox "

static std::shared_ptr<DropboxHost> Spawn()
{
    DropboxHost::Params params;
    params.account = g_Account;
    params.access_token = g_Token;
    params.client_id = NCE(nc::env::dropbox_client_id);
    params.client_secret = NCE(nc::env::dropbox_client_secret);
    return std::make_shared<DropboxHost>(params);
}

TEST_CASE(PREFIX "statfs")
{
    const std::shared_ptr<VFSHost> host = Spawn();
    const VFSStatFS statfs = host->StatFS("/").value();
    CHECK(statfs.total_bytes == 2147483648);
    CHECK(statfs.free_bytes > 0);
    CHECK(statfs.free_bytes < statfs.total_bytes);
    REQUIRE(statfs.volume_name == g_Account);
}

TEST_CASE(PREFIX "invalid credentials")
{
    auto token = "-SupposingThisWillNeverBecameAValidAccessTokeForDropboxOAuth2AAA";
    DropboxHost::Params params;
    params.account = g_Account;
    params.access_token = token;
    params.client_id = NCE(nc::env::dropbox_client_id);
    params.client_secret = NCE(nc::env::dropbox_client_secret);
    CHECK_THROWS_AS(std::make_shared<DropboxHost>(params), ErrorException);
}

TEST_CASE(PREFIX "stat on existing file")
{
    auto filepath = "/TestSet01/11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg";
    const std::shared_ptr<VFSHost> host = Spawn();

    const VFSStat stat = host->Stat(filepath, 0).value();
    CHECK(stat.mode_bits.reg == true);
    CHECK(stat.mode_bits.dir == false);
    CHECK(stat.size == 190892);

    const auto calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    const auto date = [NSDate dateWithTimeIntervalSince1970:static_cast<double>(stat.mtime.tv_sec)];
    const auto components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                        fromDate:date];
    CHECK(components.year == 2017);
    CHECK(components.month == 4);
    CHECK(components.day == 3);
}

TEST_CASE(PREFIX "stat on non existing file")
{
    const auto filepath = "/TestSet01/this_file_does_not_exist!!!.jpg";
    const std::shared_ptr<VFSHost> host = Spawn();
    CHECK(!host->Stat(filepath, 0));
}

TEST_CASE(PREFIX "stat on existing folder")
{
    const auto filepath = "/TestSet01/";
    const std::shared_ptr<VFSHost> host = Spawn();

    const VFSStat stat = host->Stat(filepath, 0).value();
    CHECK(stat.mode_bits.dir == true);
    CHECK(stat.mode_bits.reg == false);
}

TEST_CASE(PREFIX "directory iterating")
{
    const auto filepath = "/TestSet01/";
    const auto must_be = std::set<std::string>{{"1ee0209db65d40d68277687017871bda.gif",
                                                "5465bdfd6afa44288520f2c84d2bb011.jpg",
                                                "11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg",
                                                "11779310-R3L8T8D-650-funny-jumping-cats-91__880.jpg",
                                                "BsQMH1kCUAALgMC.jpg",
                                                "f447bd6f4f6a47e6a355b7b44f2a326f.jpg",
                                                "kvxnws0o3i3g.jpg",
                                                "vw1yzox23csh.jpg"}};
    const std::shared_ptr<VFSHost> host = Spawn();

    std::set<std::string> filenames;
    REQUIRE(host->IterateDirectoryListing(filepath, [&](const VFSDirEnt &_e) {
        filenames.emplace(_e.name);
        return true;
    }));
    CHECK(filenames == must_be);
}

TEST_CASE(PREFIX "large directory iterating")
{
    const auto filepath = "/TestSet02/";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::set<std::string> filenames;
    REQUIRE(host->IterateDirectoryListing(filepath, [&](const VFSDirEnt &_e) {
        filenames.emplace(_e.name);
        return true;
    }));
    CHECK(filenames.count("ActionShortcut.h"));
    CHECK(filenames.count("xattr.h"));
    CHECK(filenames.size() == 501);
}

TEST_CASE(PREFIX "directory listing")
{
    const std::shared_ptr<VFSHost> host = Spawn();
    CHECK(host->FetchDirectoryListing("/", 0));
}

TEST_CASE(PREFIX "large directory listing")
{
    const auto dirpath = "/TestSet02/";
    const std::shared_ptr<VFSHost> host = Spawn();
    const VFSListingPtr listing = host->FetchDirectoryListing(dirpath, Flags::F_NoDotDot).value();

    std::set<std::string> filenames;
    for( const auto &item : *listing )
        filenames.emplace(item.Filename());

    CHECK(filenames.count("ActionShortcut.h"));
    CHECK(filenames.count("xattr.h"));
    CHECK(filenames.size() == 501);
}

TEST_CASE(PREFIX "basic file read")
{
    const auto filepath = "/TestSet01/11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg";
    const std::shared_ptr<VFSHost> host = Spawn();
    const VFSFilePtr file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    CHECK(file->Size() == 190892);

    auto data = file->ReadFile();
    REQUIRE(data);
    CHECK(data->size() == 190892);
    CHECK(data->back() == 0xD9);
}

TEST_CASE(PREFIX "reading file with non ASCII symbols")
{
    const auto filepath = "/TestSet03/Это фотка котега $о ВСЯкими #\"символами\"!!!.jpg";
    const std::shared_ptr<VFSHost> host = Spawn();
    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    CHECK(file->Size() == 253899);

    auto data = file->ReadFile();
    REQUIRE(data);
    CHECK(data->size() == 253899);
    CHECK(data->front() == 0xFF);
    CHECK(data->back() == 0xD9);
}

TEST_CASE(PREFIX "reading non-existing file")
{
    const auto filepath = "/TestSet01/jggweofgewufygweufguwefg.jpg";
    const std::shared_ptr<VFSHost> host = Spawn();
    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Read) != VFSError::Ok);
    REQUIRE(!file->IsOpened());
}

TEST_CASE(PREFIX "simple upload")
{
    const auto to_upload = "Hello, world!"s;
    const auto filepath = "/FolderToModify/test.txt";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload), std::size(to_upload)));
    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    auto uploaded = file->ReadFile();
    REQUIRE(uploaded);
    REQUIRE(uploaded->size() == size(to_upload));
    REQUIRE(equal(uploaded->begin(), uploaded->end(), to_upload.begin()));
    REQUIRE(file->Close() == VFSError::Ok);

    std::ignore = host->Unlink(filepath);
}

TEST_CASE(PREFIX "upload with invalid name")
{
    const auto to_upload = "Hello, world!"s;
    const auto filepath = R"(/FolderToModify/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/test.txt)";
    const std::shared_ptr<VFSHost> host = Spawn();

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    const bool op1 = file->Open(VFSFlags::OF_Write) == VFSError::Ok;
    const bool op2 = file->SetUploadSize(to_upload.size()) == VFSError::Ok;
    const bool op3 = file->WriteFile(std::data(to_upload), std::size(to_upload)).has_value();
    const bool op4 = file->Close() == VFSError::Ok;
    CHECK((!op1 || !op2 || !op3 || !op4));
}

TEST_CASE(PREFIX "simple upload with overwrite")
{
    const auto to_upload = "Hello, world!"s;
    const auto filepath = "/FolderToModify/test.txt";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload), std::size(to_upload)));
    REQUIRE(file->Close() == VFSError::Ok);

    const auto to_upload_new = "Hello, world, again!"s;
    REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Truncate) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload_new.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload_new), std::size(to_upload_new)));
    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    auto uploaded = file->ReadFile();
    REQUIRE(uploaded);
    REQUIRE(uploaded->size() == std::size(to_upload_new));
    REQUIRE(std::equal(uploaded->begin(), uploaded->end(), to_upload_new.begin()));
    REQUIRE(file->Close() == VFSError::Ok);

    std::ignore = host->Unlink(filepath);
}

TEST_CASE(PREFIX "UnfinishedUpload")
{
    const auto to_upload = "Hello, world!"s;
    const auto filepath = "/FolderToModify/test.txt";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload), std::size(to_upload) - 1));
    REQUIRE(file->Close() != VFSError::Ok);

    REQUIRE(host->Exists(filepath) == false);
}

TEST_CASE(PREFIX "zero sized upload")
{
    const auto filepath = "/FolderToModify/zero.txt";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(0) == VFSError::Ok);
    REQUIRE(file->Close() == VFSError::Ok);

    const VFSStat stat = host->Stat(filepath, 0).value();
    REQUIRE(stat.size == 0);
    std::ignore = host->Unlink(filepath);
}

TEST_CASE(PREFIX "decent sized upload")
{
    const auto length = 5 * 1024 * 1024; // 5Mb upload / download
    const auto filepath = "/FolderToModify/SomeRubbish.bin";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();

    std::vector<uint8_t> to_upload = MakeNoise(length);

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload), std::size(to_upload)));
    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    auto uploaded = file->ReadFile();
    REQUIRE(uploaded);
    REQUIRE(uploaded->size() == size(to_upload));
    REQUIRE(equal(uploaded->begin(), uploaded->end(), to_upload.begin()));
    REQUIRE(file->Close() == VFSError::Ok);

    std::ignore = host->Unlink(filepath);
}

TEST_CASE(PREFIX "two-chunk upload")
{
    const auto length = 17 * 1024 * 1024; // 17MB upload / download
    const auto filepath = "/FolderToModify/SomeBigRubbish.bin";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();
    std::dynamic_pointer_cast<dropbox::File>(file)->SetChunkSize(10000000); // 10 Mb chunks

    std::vector<uint8_t> to_upload = MakeNoise(length);

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload), std::size(to_upload)));
    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    auto uploaded = file->ReadFile();
    REQUIRE(uploaded);
    REQUIRE(uploaded->size() == size(to_upload));
    REQUIRE(std::equal(uploaded->begin(), uploaded->end(), to_upload.begin()));
    REQUIRE(file->Close() == VFSError::Ok);

    std::ignore = host->Unlink(filepath);
}

TEST_CASE(PREFIX "multi-chunks upload")
{
    const auto length = 17 * 1024 * 1024; // 17MB upload / download

    const auto filepath = "/FolderToModify/SomeBigRubbish.bin";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();
    std::dynamic_pointer_cast<dropbox::File>(file)->SetChunkSize(5000000); // 5Mb chunks

    std::vector<uint8_t> to_upload = MakeNoise(length);

    REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
    REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(std::data(to_upload), std::size(to_upload)));
    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
    auto uploaded = file->ReadFile();
    REQUIRE(uploaded);
    REQUIRE(uploaded->size() == std::size(to_upload));
    REQUIRE(equal(uploaded->begin(), uploaded->end(), to_upload.begin()));
    REQUIRE(file->Close() == VFSError::Ok);

    std::ignore = host->Unlink(filepath);
}

TEST_CASE(PREFIX "upload edge cases")
{
    const int chunk_size = 1'000'000;
    const int lengths[] = {
        999'999, 1'000'000, 1'000'001, 1'999'999, 2'000'000, 2'000'001, 2'999'999, 3'000'000, 3'000'001};
    const auto filepath = "/FolderToModify/SomeBigRubbish.bin";

    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->Unlink(filepath);

    for( auto length : lengths ) {
        const std::shared_ptr<VFSFile> file = host->CreateFile(filepath).value();
        std::dynamic_pointer_cast<dropbox::File>(file)->SetChunkSize(chunk_size);

        std::vector<uint8_t> to_upload = MakeNoise(length);

        REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
        REQUIRE(file->SetUploadSize(to_upload.size()) == VFSError::Ok);
        REQUIRE(file->WriteFile(data(to_upload), std::size(to_upload)));
        REQUIRE(file->Close() == VFSError::Ok);

        REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
        auto uploaded = file->ReadFile();
        REQUIRE(uploaded);
        REQUIRE(uploaded->size() == std::size(to_upload));
        REQUIRE(equal(uploaded->begin(), uploaded->end(), to_upload.begin()));
        REQUIRE(file->Close() == VFSError::Ok);

        std::ignore = host->Unlink(filepath);
    }
}

TEST_CASE(PREFIX "folder creation and removal")
{
    const auto filepath = "/FolderToModify/NewDirectory/";
    const std::shared_ptr<VFSHost> host = Spawn();
    std::ignore = host->RemoveDirectory(filepath);

    REQUIRE(host->CreateDirectory(filepath, 0));
    REQUIRE(host->Exists(filepath) == true);
    REQUIRE(host->IsDirectory(filepath, 0) == true);
    REQUIRE(host->RemoveDirectory(filepath));
    REQUIRE(host->Exists(filepath) == false);
}

static std::vector<uint8_t> MakeNoise(size_t size)
{
    std::vector<uint8_t> noise(size);
    std::srand(static_cast<unsigned>(time(nullptr)));
    for( size_t i = 0; i < size; ++i )
        noise[i] = static_cast<uint8_t>(std::rand() % 256); // yes, I know that rand() is harmful!
    return noise;
}
