// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/FileWindow.h>

/**
 * This class encapsulates working with file windows and decoding raw data into UniChars.
 * BigFileViewDataBackend has no ownership on FileWindow, it should be released by caller's code.
 */
class BigFileViewDataBackend
{
public:
    BigFileViewDataBackend(FileWindow &_fw, int _encoding);

    ////////////////////////////////////////////////////////////////////////////////////////////
    // settings
    int Encoding() const;
    void SetEncoding(int _encoding);

    ////////////////////////////////////////////////////////////////////////////////////////////
    // operations
    int MoveWindowSync(uint64_t _pos); // return VFS error code
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    // data access
    
    /**
     * Returns true if FileWindow is buffering whole file contents.
     * Thus no window movements is needed (and cannot be done).
     */
    bool        IsFullCoverage() const;
    
    /**
     * Whole file size.
     */
    uint64_t    FileSize() const;

    /**
     * Position of a file window (offset of it's first byte from the beginning of a file).
     */
    uint64_t    FilePos()  const;
    
    const void *Raw() const;            // data of current file window
    
    /**
     * File window size. It will not change while this object lives
     */
    uint64_t    RawSize() const;
    
    const UniChar     *UniChars() const;      // decoded buffer
    const uint32_t    *UniCharToByteIndeces() const;  // byte indeces within file window of decoded unichars
    uint32_t           UniCharsSize() const;   // decoded buffer size in unichars

    ////////////////////////////////////////////////////////////////////////////////////////////
    // handlers
    void SetOnDecoded(void (^_handler)());
private:
    void DecodeBuffer(); // called by internal update logic
    
    FileWindow &m_FileWindow;
    int         m_Encoding;
    void        (^m_OnDecoded)() = nullptr;

    unique_ptr<UniChar[]> m_DecodeBuffer;   // decoded buffer with unichars
                                            // useful size of m_DecodedBufferSize

    unique_ptr<uint32_t[]> m_DecodeBufferIndx;    // array indexing every m_DecodeBuffer unicode character into a
                                            // byte offset within original file window
                                            // useful size of m_DecodedBufferSize
    
    size_t          m_DecodedBufferSize = 0;// amount of unichars
};


inline uint64_t BigFileViewDataBackend::FileSize() const
{
    return m_FileWindow.FileSize();
}

inline uint64_t BigFileViewDataBackend::FilePos() const
{
    return m_FileWindow.WindowPos();
}

inline const void *BigFileViewDataBackend::Raw() const
{
    return m_FileWindow.Window();
}

inline uint64_t BigFileViewDataBackend::RawSize() const
{
    return m_FileWindow.WindowSize();
}

inline const UniChar *BigFileViewDataBackend::UniChars() const
{
    return m_DecodeBuffer.get();
}

inline const uint32_t *BigFileViewDataBackend::UniCharToByteIndeces() const
{
    return m_DecodeBufferIndx.get();
}

inline uint32_t BigFileViewDataBackend::UniCharsSize() const
{
    return (uint32_t)m_DecodedBufferSize;
}

inline bool BigFileViewDataBackend::IsFullCoverage() const
{
    return m_FileWindow.FileSize() == m_FileWindow.WindowSize();
}
