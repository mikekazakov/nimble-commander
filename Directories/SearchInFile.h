//
//  SearchInFile.h
//  Files
//
//  Created by Michael G. Kazakov on 13.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <stdint.h>

class FileWindow;

class SearchInFile
{
public:
    // will not own _file, caller need to close it after work
    // assumes that _file is in exclusive use in SearchInFile - that no one else will alter it
    SearchInFile(FileWindow *_file);
    ~SearchInFile();
    
    dispatch_queue_t Queue(); // called should run all non-trivial methods whithin this queue
                              // one async queue per search object
    
    void MoveCurrentPosition(uint64_t _pos);

    void SetSearchOptions(int _options);
    int SearchOptions();
    
    bool IsEOF() const;
    
    // passing ownage of _string to SearchInFile
    void ToggleTextSearch(CFStringRef _string, int _encoding);
    CFStringRef TextSearchString(); // may be NULL. don't alter it. don't release it
    int TextSearchEncoding(); // may be ENCODING_INVALID

    enum class Result
    {
        Invalid,    // invalid search request
        IOErr,      // I/O error on underlying VFS
        Found,      // searched performed successfuly, found one and returning addresses
        NotFound,   // searched performed successfully, didn't found
        EndOfFile,  // can't seach since current position is already at the end of file
        Canceled    // user did canceled the search. search position will remain at the place when cancelation happen
    };
    
    enum
    {
        OptionCaseSensitive     = 1 << 0,   // default search option is case _insensitive_
        OptionFindWholePhrase   = 1 << 1
    };
    
    typedef bool (^CancelChecker)(void);
    Result Search(uint64_t *_offset/*out*/,
                  uint64_t *_bytes_len/*out*/,
                  CancelChecker _checker); // checker can be nil
    
private:
    SearchInFile(const SearchInFile&); // forbid
    void operator=(const SearchInFile&); // forbid
    
    Result SearchText(uint64_t *_offset, uint64_t *_bytes_len, CancelChecker _checker);
    
    enum class WorkMode
    {
        NotSet,
        Text
        /* binary(hex) and regexp(tempates) later */
    };
    
    FileWindow *m_File;
    uint64_t    m_Position; // position where next search attempt should start
                            // in bytes, should be inside file window

    int         m_SearchOptions;    
    
    // text search related stuff
    CFStringRef m_RequestedTextSearch;
    int         m_TextSearchEncoding;
    
    UniChar    *m_DecodedBuffer;
    uint32_t   *m_DecodedBufferIndx;
    size_t      m_DecodedBufferSize;
    CFStringRef m_DecodedBufferString;
    
    WorkMode    m_WorkMode;
    
    dispatch_queue_t m_Queue;
};
