#include "Tests.h"
#include "SearchInFile.h"
#include "VFSGenericMemReadOnlyFile.h"
#include <Utility/Encodings.h>

using nc::vfs::FileWindow;
using nc::vfs::SearchInFile;
using nc::vfs::GenericMemReadOnlyFile;
#define PREFIX "[nc::vfs::SearchInFile] "

TEST_CASE(PREFIX "Throws if FileWindow is not open")
{
    FileWindow fw;
    CHECK_THROWS( SearchInFile{fw} );
}

TEST_CASE(PREFIX "Does simple search")
{
    std::string memory = "0123456789hello56789";
    auto mem_file = std::make_shared<GenericMemReadOnlyFile>(nullptr, nullptr, memory);
    mem_file->Open(VFSFlags::OF_Read);
    FileWindow fw;
    fw.OpenFile(mem_file);
    auto search = SearchInFile{fw};
    
    SECTION("Search for 0123") {
        search.ToggleTextSearch(CFSTR("0123"), encodings::ENCODING_UTF8);
        
        uint64_t offset, bytes_len;
        auto result = search.Search(&offset, &bytes_len);
        CHECK( result == SearchInFile::Result::Found );
        CHECK( offset == 0 );
        CHECK( bytes_len == 4 );
    }
}

