//
//  SearchInFile.cpp
//  Files
//
//  Created by Michael G. Kazakov on 13.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileWindow.h"
#import "Encodings.h"
#import "SearchInFile.h"

static const unsigned g_MaximumCodeUnit = 2;

SearchInFile::SearchInFile(FileWindow* _file):
    m_File(_file),
    m_Position(0),
    m_WorkMode(WorkMode::NotSet),
    m_RequestedTextSearch(0),
    m_DecodedBufferString(0),
    m_TextSearchEncoding(ENCODING_INVALID),
    m_SearchOptions(0)
{
    assert(m_File->FileOpened());
    m_Position = _file->WindowPos();
    m_DecodedBuffer = (UniChar*) malloc(sizeof(UniChar) * _file->WindowSize());
    m_DecodedBufferIndx = (uint32_t*) malloc(sizeof(uint32_t) * _file->WindowSize());
}

SearchInFile::~SearchInFile()
{
    if(m_RequestedTextSearch != 0)
        CFRelease(m_RequestedTextSearch);
    if(m_DecodedBufferString != 0)
        CFRelease(m_DecodedBufferString);    
    if(m_DecodedBuffer != 0)
        free(m_DecodedBuffer);
    if(m_DecodedBufferIndx != 0)
        free(m_DecodedBufferIndx);
}

void SearchInFile::MoveCurrentPosition(uint64_t _pos)
{
    assert(_pos < m_File->FileSize());
    m_Position = _pos;

    if(m_File->WindowSize() + m_Position > m_File->FileSize())
        m_File->MoveWindow(m_File->FileSize() - m_File->WindowSize());
    else
        m_File->MoveWindow(m_Position);
}

void SearchInFile::ToggleTextSearch(CFStringRef _string, int _encoding)
{
    if(m_RequestedTextSearch != 0)
        CFRelease(m_RequestedTextSearch);
    m_RequestedTextSearch = _string;
    m_TextSearchEncoding = _encoding;
    
    m_WorkMode = WorkMode::Text;
}

bool SearchInFile::Search(uint64_t *_offset, uint64_t *_bytes_len)
{
    if(m_WorkMode == WorkMode::Text)
        return SearchText(_offset, _bytes_len);
    
    return false;
}

bool SearchInFile::SearchText(uint64_t *_offset, uint64_t *_bytes_len)
{
    if(m_Position >= m_File->FileSize())
        return false; // when finished searching
    
    if(CFStringGetLength(m_RequestedTextSearch) <= 0)
        return false;

    while(true)
    {
        if(m_Position >= m_File->FileSize())
            break; // when finished searching

        // move our load window inside a file
        size_t window_pos = m_Position;
        size_t left_window_gap = 0;
        if(window_pos + m_File->WindowSize() > m_File->FileSize())
        {
            window_pos = m_File->FileSize() - m_File->WindowSize();
            left_window_gap = m_Position - window_pos;
        }
        m_File->MoveWindow(window_pos);
        assert(m_Position >= m_File->WindowPos() &&
               m_Position < m_File->WindowPos() + m_File->WindowSize()); // sanity check
        
        // get UniChars from this window using given encoding
        assert(encodings::BytesForCodeUnit(m_TextSearchEncoding) <= 2); // TODO: support for UTF-32 in the future
        bool isodd = (encodings::BytesForCodeUnit(m_TextSearchEncoding) == 2) && ((m_File->WindowPos() & 1) == 1);
        encodings::InterpretAsUnichar(m_TextSearchEncoding,
                                      (const unsigned char*) m_File->Window() + left_window_gap  + (isodd ? 1 : 0),
                                      m_File->WindowSize() - left_window_gap  - (isodd ? 1 : 0),
                                      m_DecodedBuffer,
                                      m_DecodedBufferIndx,
                                      &m_DecodedBufferSize);

        assert(m_DecodedBufferSize != 0);
        
        // use this UniChars to produce a regular CFString
        if(m_DecodedBufferString != 0)
            CFRelease(m_DecodedBufferString);
        m_DecodedBufferString = CFStringCreateWithCharactersNoCopy(0, m_DecodedBuffer, m_DecodedBufferSize, kCFAllocatorNull);

        CFRange result = CFStringFind (
                                       m_DecodedBufferString,
                                       m_RequestedTextSearch,
                                       (m_SearchOptions & OptionCaseSensitive) ? 0 : kCFCompareCaseInsensitive
                                       );

        if(result.location == kCFNotFound)
        {
            // lets proceed further
            if(m_File->WindowPos() + m_File->WindowSize() < m_File->FileSize())
            { // can move on
                // left some space in the tail to exclude situations when searched text is cut between the windows
                assert(left_window_gap == 0);
                assert(CFStringGetLength(m_RequestedTextSearch) * g_MaximumCodeUnit < m_File->WindowSize());
                m_Position = m_Position + m_File->WindowSize() - CFStringGetLength(m_RequestedTextSearch) * g_MaximumCodeUnit;
            }
            else
            { // this is the end (c)
                m_Position = m_File->FileSize();
            }
        }
        else
        {
            assert(result.location + result.length <= m_DecodedBufferSize);
            
            *_offset = m_Position + m_DecodedBufferIndx[result.location];
            *_bytes_len = (result.location + result.length < m_DecodedBufferSize ?
                           m_DecodedBufferIndx[result.location+result.length] :
                           m_File->WindowSize() - left_window_gap )
                            - m_DecodedBufferIndx[result.location];
            m_Position = m_Position + m_DecodedBufferIndx[result.location+result.length];
            return true;
        }
    }
    
    return false;
}

CFStringRef SearchInFile::TextSearchString()
{
    return m_RequestedTextSearch;
}

int SearchInFile::TextSearchEncoding()
{
    return m_TextSearchEncoding;
}

void SearchInFile::SetSearchOptions(int _options)
{
    m_SearchOptions = _options;
}

int SearchInFile::SearchOptions()
{
    return m_SearchOptions;
}