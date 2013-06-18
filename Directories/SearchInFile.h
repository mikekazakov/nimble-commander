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
    // will not own _file, called need to close it after work
    // assumes that _file is in exclusive use in SearchInFile - that no one else will alter it
    SearchInFile(FileWindow *_file);
    
    ~SearchInFile();
    
    void MoveCurrentPosition(uint64_t _pos);

    void SetSearchOptions(int _options);
    int SearchOptions();
    
    // passing ownage of _string to SearchInFile
    void ToggleTextSearch(CFStringRef _string, int _encoding);
    CFStringRef TextSearchString(); // may be NULL. don't alter it. don't release it
    int TextSearchEncoding(); // may be ENCODING_INVALID
    
    bool Search(uint64_t *_offset, uint64_t *_bytes_len); // TODO: add stopping handler as a block
    
    enum
    {
        OptionCaseSensitive = 1 << 0 // default search option is case _insensitive_
    };
    
private:
    SearchInFile(const SearchInFile&); // forbid
    void operator=(const SearchInFile&); // forbid
    
    bool SearchText(uint64_t *_offset, uint64_t *_bytes_len);
    
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
};
