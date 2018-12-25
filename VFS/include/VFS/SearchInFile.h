// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <memory>
#include <functional>
#include <optional>
#include <VFS/FileWindow.h>

namespace nc::vfs {

/**
 * Provides a *stateful* searching facilty to find text in VFS file accessible through
 * a FileWindow object.
 * Is thread agnostic.
 */
class SearchInFile
{
public:
    // will not own _file, caller need to close it after work
    // assumes that _file is in exclusive use in SearchInFile - that no one else will alter it
    SearchInFile(nc::vfs::FileWindow &_file);
    ~SearchInFile();
    
    void MoveCurrentPosition(uint64_t _pos);

    void SetSearchOptions(int _options);
    int SearchOptions();
    
    bool IsEOF() const;
    
    void ToggleTextSearch(CFStringRef _string, int _encoding);
    CFStringRef TextSearchString(); // may be NULL. don't alter it. don't release it
    int TextSearchEncoding(); // may be ENCODING_INVALID

    enum class Response : int;
    struct Location {
        uint64_t offset;
        uint64_t bytes_len;
    };
    
    struct Result {
        Response response;
        std::optional<Location> location;
    };
    
    enum
    {
        OptionCaseSensitive     = 1 << 0,   // default search option is case _insensitive_
        OptionFindWholePhrase   = 1 << 1
    };
    
    using CancelChecker = std::function<bool()>;
    Response Search(uint64_t *_offset/*out*/,
                  uint64_t *_bytes_len/*out*/,
                  const CancelChecker &_checker = {}); // checker can be nullptr
    
    Result Search( const CancelChecker &_checker = {} );
    
private:
    SearchInFile(const SearchInFile&); // forbid
    void operator=(const SearchInFile&); // forbid
    
    Response SearchText(uint64_t *_offset, uint64_t *_bytes_len, CancelChecker _checker);
    
    enum class WorkMode
    {
        NotSet,
        Text
        /* binary(hex) and regexp(tempates) later */
    };
    
    nc::vfs::FileWindow &m_File;
    uint64_t    m_Position; // position where next search attempt should start
                            // in bytes, should be inside file + 1 byte
                            // need this because it can point behind end of file to signal that search is ended

    int         m_SearchOptions;    
    
    // text search related stuff
    CFStringRef m_RequestedTextSearch;
    int         m_TextSearchEncoding;
    
    std::unique_ptr<uint16_t[]> m_DecodedBuffer;
    std::unique_ptr<uint32_t[]> m_DecodedBufferIndx;
    
    size_t      m_DecodedBufferSize;
    CFStringRef m_DecodedBufferString;
    
    WorkMode    m_WorkMode;
};

enum class SearchInFile::Response : int
{
    // Invalid search request
    Invalid,
        
    // I/O error on the underlying VFS file
    IOErr,

    // Search performed successfuly, found one entry and returning its address
    Found,
    
    // Search performed successfully, didn't found
    NotFound,
    
    // Can't search since current position is already at the end of the file
    EndOfFile,
    
    // User did cancel the search. The search position will remain at the
    // place when cancellation happened
    Canceled
};

}
