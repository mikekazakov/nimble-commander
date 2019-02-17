#pragma once

#include <CoreText/CoreText.h>
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
    int Length() const noexcept;
    CFStringRef String() const noexcept;
    
    int ToLocalByteOffset( int _character_index ) const; // may be OutOfBounds by 1
    long ToGlobalByteOffset( int _character_index ) const; // may be OutOfBounds by 1
    const int *CharactersByteOffsets() const noexcept;
    
    long GlobalOffset() const noexcept;
    
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
    
}
