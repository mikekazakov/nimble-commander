#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <memory>
#include <assert.h>

namespace nc::viewer {
    
class TextModeWorkingSet
{
public:
    struct Source {
        const char16_t *unprocessed_characters = nullptr;
        const int *mapping_to_byte_offsets = nullptr;
        int characters_number = 0;
        long bytes_offset = 0;
        int bytes_length = 0;
    };
    
    TextModeWorkingSet(const Source &_source);
    TextModeWorkingSet(const TextModeWorkingSet&) = delete;
    ~TextModeWorkingSet();
    void operator=(const TextModeWorkingSet&) = delete;
    
    const char16_t* Characters() const noexcept;
    
    /** Returns the number of UTF16 characters covered by this set. */
    int Length() const noexcept;
    CFStringRef String() const noexcept;
    
    int ToLocalByteOffset( int _character_index ) const; // may be OutOfBounds by 1
    long ToGlobalByteOffset( int _character_index ) const; // may be OutOfBounds by 1
    const int *CharactersByteOffsets() const noexcept;
    
    /**
     * Returns an index of a character that is located at the specified local byte offset.
     * If _local_byte_offset points before any characters - will return -1
     * if _local_byte_offset points after any characters - will return Length().
     */
    int ToLocalCharIndex( int _local_byte_offset ) const noexcept;
    
    /**
     * Converts global bytes range into local byte indices.
     * Does trim in the process - output is guaranteed to be either valid or {kCFNotFound, 0}.
     */
    CFRange ToLocalBytesRange( CFRange _global_bytes_range ) const noexcept;
    
    /** Returns the position of the working set within the file. */
    long GlobalOffset() const noexcept;
    
    /** Returns the number of bytes covered by the working set.  */
    int BytesLength() const noexcept;
    
private:
    /**
     * Characters in UTF16 aka UniChar.
     */
    std::unique_ptr<char16_t[]> m_Characters;
    
    /**
     * Mapping of character index to a byte offset within this working set.
     * Constains an additional element in the end to be able to get length of the same character.
     * It's local offset, to get global one - add it to m_WorkingSetOffset.
     */
    std::unique_ptr<int[]>      m_ToByteIndices;
    
    /**
     * Number of characters, i.e. size of m_Characters and m_ToByteIndices.
     */
     int                        m_CharactersNumber = 0;
    
    /**
     * Offset of this working set(window) from the beginning of the file in bytes.
     */
    long                        m_WorkingSetOffset = 0;
    
    /**
     * Size of this working set in bytes.
     */
    int                         m_WorkingSetSize = 0;
    
    /**
     * CoreFoundation string without ownership - it maps to m_Characters.
     */
    CFStringRef                 m_String = nullptr;
};

inline const char16_t* TextModeWorkingSet::Characters() const noexcept
{
    return m_Characters.get();
}

inline int TextModeWorkingSet::Length() const noexcept
{
    return m_CharactersNumber;
}
    
inline CFStringRef TextModeWorkingSet::String() const noexcept
{
    return m_String;
}
    
inline long TextModeWorkingSet::GlobalOffset() const noexcept
{
    return m_WorkingSetOffset;
}

inline const int *TextModeWorkingSet::CharactersByteOffsets() const noexcept
{
    return m_ToByteIndices.get();
}

inline int TextModeWorkingSet::BytesLength() const noexcept
{
    return m_WorkingSetSize;
}
    
}
