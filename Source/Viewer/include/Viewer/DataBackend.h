// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/FileWindow.h>
#include <Utility/Encodings.h>
#include <MacTypes.h>
#include <functional>
#include <filesystem>

namespace nc::viewer {

/**
 * This class encapsulates working with file windows and decoding raw data into UniChars.
 * BigFileViewDataBackend has no ownership on FileWindow, it should be released by caller's code.
 */
class DataBackend
{
public:
    DataBackend(std::shared_ptr<nc::vfs::FileWindow> _fw, utility::Encoding _encoding);

    ////////////////////////////////////////////////////////////////////////////////////////////
    // settings
    utility::Encoding Encoding() const;
    void SetEncoding(utility::Encoding _encoding);

    ////////////////////////////////////////////////////////////////////////////////////////////
    // operations
    std::expected<void, Error> MoveWindowSync(uint64_t _pos);

    ////////////////////////////////////////////////////////////////////////////////////////////
    // data access

    /**
     * Returns true if FileWindow is buffering whole file contents.
     * Thus no window movements is needed (and cannot be done).
     */
    bool IsFullCoverage() const;

    /**
     * Whole file size.
     */
    uint64_t FileSize() const;

    /**
     * Position of a file window (offset of it's first byte from the beginning of a file).
     */
    uint64_t FilePos() const;

    const void *Raw() const; // data of current file window

    /**
     * File window size. It will not change while this object lives
     */
    uint64_t RawSize() const;

    const UniChar *UniChars() const;              // decoded buffer
    const uint32_t *UniCharToByteIndeces() const; // byte indeces within file window of decoded unichars
    uint32_t UniCharsSize() const;                // decoded buffer size in unichars

    // Returns a filename component of the underlying VFS file's path
    std::filesystem::path FileName() const;

private:
    void DecodeBuffer(); // called by internal update logic

    std::shared_ptr<nc::vfs::FileWindow> m_FileWindow;
    utility::Encoding m_Encoding;

    // decoded buffer with unichars
    // useful size of m_DecodedBufferSize
    std::unique_ptr<UniChar[]> m_DecodeBuffer;

    // array indexing every m_DecodeBuffer unicode character into a
    // byte offset within original file window
    // useful size of m_DecodedBufferSize
    std::unique_ptr<uint32_t[]> m_DecodeBufferIndx;

    // amount of unichars
    size_t m_DecodedBufferSize = 0;
};

inline uint64_t DataBackend::FileSize() const
{
    return m_FileWindow->FileSize();
}

inline uint64_t DataBackend::FilePos() const
{
    return m_FileWindow->WindowPos();
}

inline const void *DataBackend::Raw() const
{
    return m_FileWindow->Window();
}

inline uint64_t DataBackend::RawSize() const
{
    return m_FileWindow->WindowSize();
}

inline const UniChar *DataBackend::UniChars() const
{
    return m_DecodeBuffer.get();
}

inline const uint32_t *DataBackend::UniCharToByteIndeces() const
{
    return m_DecodeBufferIndx.get();
}

inline uint32_t DataBackend::UniCharsSize() const
{
    return static_cast<uint32_t>(m_DecodedBufferSize);
}

inline bool DataBackend::IsFullCoverage() const
{
    return m_FileWindow->FileSize() == m_FileWindow->WindowSize();
}

} // namespace nc::viewer
