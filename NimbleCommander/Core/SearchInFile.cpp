// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SearchInFile.h"
#include <Utility/Encodings.h>
#include "FileWindow.h"
#include <exception>

static const unsigned g_MaximumCodeUnit = 2;

static bool IsWholePhrase(CFStringRef _string, CFRange _range)
{
    static CFCharacterSetRef set = CFCharacterSetGetPredefined(kCFCharacterSetAlphaNumeric);
    assert( _range.length > 0 );
    assert( _range.location >= 0 );

    if(_range.location > 0)
        if( CFCharacterSetIsCharacterMember(set, CFStringGetCharacterAtIndex(_string, _range.location - 1)) )
            return false;

    if(_range.location + _range.length < CFStringGetLength(_string))
        if( CFCharacterSetIsCharacterMember(set, CFStringGetCharacterAtIndex(_string, _range.location + _range.length)) )
            return false;

    return true;
}

SearchInFile::SearchInFile(FileWindow &_file):
    m_File(_file),
    m_Position(0),
    m_WorkMode(WorkMode::NotSet),
    m_RequestedTextSearch(0),
    m_DecodedBufferString(0),
    m_TextSearchEncoding(encodings::ENCODING_INVALID),
    m_SearchOptions(0)
{
    if( !m_File.FileOpened() )
        throw std::invalid_argument("FileWindow should be opened");
    m_Position = _file.WindowPos();
    m_DecodedBuffer = std::make_unique<uint16_t[]>(_file.WindowSize());
    m_DecodedBufferIndx = std::make_unique<uint32_t[]>(_file.WindowSize());
}

SearchInFile::~SearchInFile()
{
    if(m_RequestedTextSearch != 0)
        CFRelease(m_RequestedTextSearch);
    if(m_DecodedBufferString != 0)
        CFRelease(m_DecodedBufferString);
}

void SearchInFile::MoveCurrentPosition(uint64_t _pos)
{
    assert( (m_File.FileSize() > 0 && _pos < m_File.FileSize()) || _pos == 0 );
    m_Position = _pos;

    if(m_File.WindowSize() + m_Position > m_File.FileSize())
        m_File.MoveWindow(m_File.FileSize() - m_File.WindowSize());
    else
        m_File.MoveWindow(m_Position);
}

void SearchInFile::ToggleTextSearch(CFStringRef _string, int _encoding)
{
    if(m_RequestedTextSearch != 0)
        CFRelease(m_RequestedTextSearch);
    m_RequestedTextSearch = CFStringCreateCopy(0, _string);
    m_TextSearchEncoding = _encoding;
    
    m_WorkMode = WorkMode::Text;
}

SearchInFile::Result SearchInFile::Search(uint64_t *_offset, uint64_t *_bytes_len, CancelChecker _checker)
{
    if(m_WorkMode == WorkMode::Text)
        return SearchText(_offset, _bytes_len, _checker);
    
    return Result::NotFound;
}

bool SearchInFile::IsEOF() const
{
    return m_Position >= m_File.FileSize();
}

SearchInFile::Result SearchInFile::SearchText(uint64_t *_offset, uint64_t *_bytes_len, CancelChecker _checker)
{
    if(m_File.FileSize() == 0)
        return Result::NotFound; // for singular case
    
    if(m_File.FileSize() < (size_t)encodings::BytesForCodeUnit(m_TextSearchEncoding))
        return Result::NotFound; // for singular case
    
    if(m_Position >= m_File.FileSize())
        return Result::EndOfFile; // when finished searching
    
    if(CFStringGetLength(m_RequestedTextSearch) <= 0)
        return Result::Invalid;

    while(true)
    {
        if(m_Position >= m_File.FileSize())
            break; // when finished searching

        if(_checker && _checker())
            return Result::Canceled;
        
        // move our load window inside a file
        size_t window_pos = m_Position;
        size_t left_window_gap = 0;
        if(window_pos + m_File.WindowSize() > m_File.FileSize())
        {
            window_pos = m_File.FileSize() - m_File.WindowSize();
            left_window_gap = m_Position - window_pos;
        }
        m_File.MoveWindow(window_pos);
        assert(m_Position >= m_File.WindowPos() &&
               m_Position < m_File.WindowPos() + m_File.WindowSize()); // sanity check
        
        // get UniChars from this window using given encoding
        assert(encodings::BytesForCodeUnit(m_TextSearchEncoding) <= 2); // TODO: support for UTF-32 in the future
        bool isodd = (encodings::BytesForCodeUnit(m_TextSearchEncoding) == 2) && ((m_File.WindowPos() & 1) == 1);
        encodings::InterpretAsUnichar(m_TextSearchEncoding,
                                      (const unsigned char*) m_File.Window() + left_window_gap  + (isodd ? 1 : 0),
                                      m_File.WindowSize() - left_window_gap  - (isodd ? 1 : 0),
                                      m_DecodedBuffer.get(),
                                      m_DecodedBufferIndx.get(),
                                      &m_DecodedBufferSize);

        assert(m_DecodedBufferSize != 0);
        
        // use this UniChars to produce a regular CFString
        if(m_DecodedBufferString != 0)
            CFRelease(m_DecodedBufferString);
        m_DecodedBufferString = CFStringCreateWithCharactersNoCopy(0,
                                                                   m_DecodedBuffer.get(),
                                                                   m_DecodedBufferSize,
                                                                   kCFAllocatorNull);

        CFRange result = CFStringFind (
                                       m_DecodedBufferString,
                                       m_RequestedTextSearch,
                                       (m_SearchOptions & OptionCaseSensitive) ? 0 : kCFCompareCaseInsensitive
                                       );

        if(result.location == kCFNotFound)
        {
            // lets proceed further
            if(m_File.WindowPos() + m_File.WindowSize() < m_File.FileSize())
            { // can move on
                // left some space in the tail to exclude situations when searched text is cut between the windows
                assert(left_window_gap == 0);
                assert(size_t(CFStringGetLength(m_RequestedTextSearch) * g_MaximumCodeUnit) < m_File.WindowSize());
                m_Position = m_Position + m_File.WindowSize() - CFStringGetLength(m_RequestedTextSearch) * g_MaximumCodeUnit;
            }
            else
            { // this is the end (c)
                m_Position = m_File.FileSize();
            }
        }
        else
        {
            assert(size_t(result.location + result.length) <= m_DecodedBufferSize); // sanity check
            // check for whole phrase is this option is set
            if( (m_SearchOptions & OptionFindWholePhrase) && !IsWholePhrase(m_DecodedBufferString, result) )
            {
                // false alarm - just move position beyond found part ang go on
                m_Position = m_Position + m_DecodedBufferIndx[result.location+result.length];
                continue;
            }
            
            if(_offset != nullptr)
                *_offset = m_Position + m_DecodedBufferIndx[result.location];
            
            if(_offset != nullptr)
                *_bytes_len = (size_t(result.location + result.length) < m_DecodedBufferSize ?
                               m_DecodedBufferIndx[result.location+result.length] :
                               m_File.WindowSize() - left_window_gap )
                                - m_DecodedBufferIndx[result.location];
            m_Position = m_Position + m_DecodedBufferIndx[result.location+result.length];
            return Result::Found;
        }
    }
    
    return Result::NotFound;
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
