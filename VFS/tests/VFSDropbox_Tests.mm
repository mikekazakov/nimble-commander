#include "tests_common.h"
#include <VFS/NetDropbox.h>
#include <VFS/../../source/NetDropbox/File.h>

using namespace nc::vfs;

static const auto g_Account = NCE(nc::env::test::dropbox_account);
static const auto g_Token = NCE(nc::env::test::dropbox_token);

static vector<uint8_t> MakeNoise(size_t size);

@interface VFSDropbox_Tests : XCTestCase
@end

@implementation VFSDropbox_Tests

- (void)testStatfs
{
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);

    VFSStatFS statfs;
    XCTAssert( host->StatFS( "/", statfs ) == 0 );
    XCTAssert( statfs.total_bytes == 2147483648 );
    XCTAssert( statfs.free_bytes > 0 && statfs.free_bytes < statfs.total_bytes );
    XCTAssert( statfs.volume_name == "mike.kazakov+ncdropboxtest@gmail.com" );
}

- (void)testInvalidCredentials
{
    try {
        shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account,
            "-SupposingThisWillNeverBecameAValidAccessTokeForDropboxOAuth2AAA");
        XCTAssert( false );
    }
    catch(...) {
        XCTAssert( true );
    }
}

- (void)testStatOnExistingFile
{
    auto filepath = "/TestSet01/11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg";

    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    
    VFSStat stat;
    XCTAssert( host->Stat( filepath, stat, 0 ) == 0 );
    XCTAssert( stat.mode_bits.reg == true );
    XCTAssert( stat.mode_bits.dir == false );
    XCTAssert( stat.size == 190892 );
    
    auto date = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian ]
        components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay
        fromDate:[NSDate dateWithTimeIntervalSince1970:stat.mtime.tv_sec]];
    XCTAssert(date.year == 2017 && date.month == 4 && date.day == 3);
}

- (void)testStatOnNonExistingFile
{
    auto filepath = "/TestSet01/this_file_does_not_exist!!!.jpg";

    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    
    VFSStat stat;
    XCTAssert( host->Stat( filepath, stat, 0 ) != 0 );
}

- (void)testStatOnExistingFolder
{
    auto filepath = "/TestSet01/";

    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    
    VFSStat stat;
    XCTAssert( host->Stat( filepath, stat, 0 ) == 0 );
    XCTAssert( stat.mode_bits.dir == true );
    XCTAssert( stat.mode_bits.reg == false );
}

- (void)testDirectoryIterating
{
    auto filepath = "/TestSet01/";
    auto must_be = set<string>{ {"1ee0209db65d40d68277687017871bda.gif", "5465bdfd6afa44288520f2c84d2bb011.jpg",
    "11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg", "11779310-R3L8T8D-650-funny-jumping-cats-91__880.jpg",
    "BsQMH1kCUAALgMC.jpg", "f447bd6f4f6a47e6a355b7b44f2a326f.jpg", "kvxnws0o3i3g.jpg", "vw1yzox23csh.jpg"
    }  };
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    
    set<string> filenames;
    int rc = host->IterateDirectoryListing(filepath, [&](const VFSDirEnt &_e){
        filenames.emplace( _e.name );
        return true;
    });
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( filenames == must_be );
}

- (void)testLargeDirectoryIterating
{
    auto filepath = "/TestSet02/";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    set<string> filenames;
    int rc = host->IterateDirectoryListing(filepath, [&](const VFSDirEnt &_e){
        filenames.emplace( _e.name );
        return true;
    });
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( filenames.count("ActionShortcut.h") );
    XCTAssert( filenames.count("xattr.h") );
    XCTAssert( filenames.size() == 501 );
}

- (void)testDirectoryListing
{
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    VFSListingPtr listing;
    XCTAssert( host->FetchDirectoryListing("/", listing, 0) == VFSError::Ok );
}

- (void)testBasicFileRead
{
    auto filepath = "/TestSet01/11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    shared_ptr<VFSFile> file;
    int rc = host->CreateFile(filepath, file);
    XCTAssert( rc == VFSError::Ok );

    rc = file->Open( VFSFlags::OF_Read );
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( file->Size() == 190892 );
    
    auto data = file->ReadFile();
    XCTAssert( data );
    XCTAssert( data->size() == 190892 );
    XCTAssert( data->back() == 0xD9 );
}

- (void)testReadingFileWithNonASCIISymbols
{
    auto filepath = @"/TestSet03/Это фотка котега $о ВСЯкими #\"символами\"!!!.jpg";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    shared_ptr<VFSFile> file;
    int rc = host->CreateFile(filepath.UTF8String, file);
    XCTAssert( rc == VFSError::Ok );

    rc = file->Open( VFSFlags::OF_Read );
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( file->Size() == 253899 );
    
    auto data = file->ReadFile();
    XCTAssert( data );
    XCTAssert( data->size() == 253899 );
    XCTAssert( data->front() == 0xFF );
    XCTAssert( data->back() == 0xD9 );
}

- (void)testReadingNonExistingFile
{
    auto filepath = "/TestSet01/jggweofgewufygweufguwefg.jpg";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    shared_ptr<VFSFile> file;
    int rc = host->CreateFile(filepath, file);
    XCTAssert( rc == VFSError::Ok );

    rc = file->Open( VFSFlags::OF_Read );
    XCTAssert( rc != VFSError::Ok );
    XCTAssert( !file->IsOpened() );
}

- (void)testSimpleUpload
{
    const auto to_upload = "Hello, world!"s;
    auto filepath = "/FolderToModify/test.txt";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );
    
    XCTAssert( file->Open( VFSFlags::OF_Read ) == VFSError::Ok );
    auto uploaded = file->ReadFile();
    XCTAssert( uploaded );
    XCTAssert( uploaded->size() == size(to_upload) );
    XCTAssert( equal( uploaded->begin(), uploaded->end(), to_upload.begin() ) );
    XCTAssert( file->Close() == VFSError::Ok );
    
    host->Unlink(filepath);
}

- (void)testUploadWithInvalidName
{
    const auto to_upload = "Hello, world!"s;
    auto filepath = "/FolderToModify/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\\/test.txt";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );

    bool op1 = file->Open( VFSFlags::OF_Write ) == VFSError::Ok;
    bool op2 = file->SetUploadSize( to_upload.size() ) == VFSError::Ok;
    bool op3 = file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok;
    bool op4 = file->Close() == VFSError::Ok;
    XCTAssert( !op1 || !op2 || !op3 || !op4 );
}

- (void)testSimpleUploadWithOverwrite
{
    const auto to_upload = "Hello, world!"s;
    auto filepath = "/FolderToModify/test.txt";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );
    
    
    const auto to_upload_new = "Hello, world, again!"s;
    XCTAssert( file->Open( VFSFlags::OF_Write | VFSFlags::OF_Truncate ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload_new.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload_new), (int)size(to_upload_new) ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );
    
    XCTAssert( file->Open( VFSFlags::OF_Read ) == VFSError::Ok );
    auto uploaded = file->ReadFile();
    XCTAssert( uploaded );
    XCTAssert( uploaded->size() == size(to_upload_new) );
    XCTAssert( equal( uploaded->begin(), uploaded->end(), to_upload_new.begin() ) );
    XCTAssert( file->Close() == VFSError::Ok );
    
    host->Unlink(filepath);
}

- (void)testUnfinishedUpload
{
    const auto to_upload = "Hello, world!"s;
    auto filepath = "/FolderToModify/test.txt";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload)-1 ) == VFSError::Ok );
    XCTAssert( file->Close() != VFSError::Ok );

    XCTAssert( host->Exists(filepath) == false );
}

- (void)testZeroSizedUpload
{
    auto filepath = "/FolderToModify/zero.txt";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( 0 ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );

    VFSStat stat;
    XCTAssert( host->Stat(filepath, stat, 0) == VFSError::Ok );
    XCTAssert( stat.size == 0 );
    host->Unlink(filepath);
}

- (void)testDecentSizedUpload
{
    const auto length = 5*1024*1024; // 5Mb upload / download
    auto filepath = "/FolderToModify/SomeRubbish.bin";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );

    vector<uint8_t> to_upload = MakeNoise(length);

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Read ) == VFSError::Ok );
    auto uploaded = file->ReadFile();
    XCTAssert( uploaded );
    XCTAssert( uploaded->size() == size(to_upload) );
    XCTAssert( equal( uploaded->begin(), uploaded->end(), to_upload.begin() ) );
    XCTAssert( file->Close() == VFSError::Ok );

    host->Unlink(filepath);    
}

- (void)testTwoChunkUpload
{
    const auto length = 17*1024*1024; // 17MB upload / download

    auto filepath = "/FolderToModify/SomeBigRubbish.bin";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );
    dynamic_pointer_cast<dropbox::File>(file)->SetChunkSize(10000000); // 10 Mb chunks
    
    vector<uint8_t> to_upload = MakeNoise(length);

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Read ) == VFSError::Ok );
    auto uploaded = file->ReadFile();
    XCTAssert( uploaded );
    XCTAssert( uploaded->size() == size(to_upload) );
    XCTAssert( equal( uploaded->begin(), uploaded->end(), to_upload.begin() ) );
    XCTAssert( file->Close() == VFSError::Ok );

    host->Unlink(filepath);    
}

- (void)testMultiChunksUpload
{
    const auto length = 17*1024*1024; // 17MB upload / download

    auto filepath = "/FolderToModify/SomeBigRubbish.bin";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    shared_ptr<VFSFile> file;
    XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );
    dynamic_pointer_cast<dropbox::File>(file)->SetChunkSize(5000000); // 5Mb chunks

    vector<uint8_t> to_upload = MakeNoise(length);

    XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
    XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
    XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok );
    XCTAssert( file->Close() == VFSError::Ok );

    XCTAssert( file->Open( VFSFlags::OF_Read ) == VFSError::Ok );
    auto uploaded = file->ReadFile();
    XCTAssert( uploaded );
    XCTAssert( uploaded->size() == size(to_upload) );
    XCTAssert( equal( uploaded->begin(), uploaded->end(), to_upload.begin() ) );
    XCTAssert( file->Close() == VFSError::Ok );

    host->Unlink(filepath);    
}

- (void)testUploadEdgeCases
{
    const int chunk_size = 1'000'000;
    const int lengths[] = {
        999'999,1'000'000, 1'000'001,
        1'999'999, 2'000'000, 2'000'001,
        2'999'999, 3'000'000, 3'000'001
    };
    const auto filepath = "/FolderToModify/SomeBigRubbish.bin";
    
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->Unlink(filepath);
    
    for( auto length: lengths  ) {
    
        shared_ptr<VFSFile> file;
        XCTAssert( host->CreateFile(filepath, file) == VFSError::Ok );
        dynamic_pointer_cast<dropbox::File>(file)->SetChunkSize(chunk_size);
        
        vector<uint8_t> to_upload = MakeNoise(length);
        
        XCTAssert( file->Open( VFSFlags::OF_Write ) == VFSError::Ok );
        XCTAssert( file->SetUploadSize( to_upload.size() ) == VFSError::Ok );
        XCTAssert( file->WriteFile( data(to_upload), (int)size(to_upload) ) == VFSError::Ok );
        XCTAssert( file->Close() == VFSError::Ok );
        
        XCTAssert( file->Open( VFSFlags::OF_Read ) == VFSError::Ok );
        auto uploaded = file->ReadFile();
        XCTAssert( uploaded );
        XCTAssert( uploaded->size() == size(to_upload) );
        XCTAssert( equal( uploaded->begin(), uploaded->end(), to_upload.begin() ) );
        XCTAssert( file->Close() == VFSError::Ok );
        
        host->Unlink(filepath);
    }
}

- (void)testFolderCreationAndRemoval
{
    auto filepath = "/FolderToModify/NewDirectory/";
    shared_ptr<VFSHost> host = make_shared<DropboxHost>(g_Account, g_Token);
    host->RemoveDirectory(filepath);

    XCTAssert( host->CreateDirectory(filepath, 0) == VFSError::Ok );
    XCTAssert( host->Exists(filepath) == true );
    XCTAssert( host->IsDirectory(filepath, 0) == true );
    XCTAssert( host->RemoveDirectory(filepath) == VFSError::Ok );
    XCTAssert( host->Exists(filepath) == false );
}

@end

static vector<uint8_t> MakeNoise(size_t size)
{
    vector<uint8_t> noise(size);
    srand((int)time(0));
    for( int i = 0; i < size; ++i )
        noise[i] = rand() % 256; // yes, I know that rand() is harmful!
    return noise;
}
