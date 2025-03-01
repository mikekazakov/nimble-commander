// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFSFile.h"

namespace nc::vfs {

/**
 * TODO: write description
 * ....
 * Holds a strong owning reference to a VFS file.
 */
class FileWindow
{
public:
    enum {
        DefaultWindowSize = 32768
    };

    // Default constructor, creates an inactive file window.
    FileWindow() = default;

    // Creates a default objects and calls Attach(). Will throw VFSErrorExpection on error.
    FileWindow(const std::shared_ptr<VFSFile> &_file, int _window_size = DefaultWindowSize);

    // For files with Sequential and Seek read paradigms, FileWindow needs exclusive access to VFSFile, so that no one
    // else can touch it's seek pointers.
    std::expected<void, Error> Attach(const std::shared_ptr<VFSFile> &_file, int _window_size = DefaultWindowSize);

    // Closes the VFSFile pointer and the memory buffer.
    void CloseFile();

    // ...
    bool FileOpened() const;

    // Returns current size of an underlying VFS file, effectively calling File()->Size().
    size_t FileSize() const;

    // Return the raw pointer to the data window in file. Size of this window is WindowSize().
    const void *Window() const;

    // Size of a file window in bytes.
    // WindowSize can't be larger than FileSize.
    size_t WindowSize() const;

    // Returns the current window position in file.
    size_t WindowPos() const;

    // Moves the window position in the file and immediately reload its content.
    // Will move only inside valid boundaries. In case of invalid boundaries returns InvalidCall.
    // Behaves depending on the VFS file - when it supports Random access, it will just move indices.
    // For Seek paradigm it will call Seek().
    // For Sequential paradigm it will read until meets the requested position.
    // In the Sequential case any calls to move _offset lower than the current position fill fail with EINVAL.
    std::expected<void, Error> MoveWindow(size_t _offset);

    // Returns the underlying VFS file.
    const VFSFilePtr &File() const;

private:
    std::expected<void, Error> ReadFileWindowRandomPart(size_t _offset, size_t _len);
    std::expected<void, Error> ReadFileWindowSeqPart(size_t _offset, size_t _len);
    std::expected<void, Error> DoMoveWindowRandom(size_t _offset);
    std::expected<void, Error> DoMoveWindowSeek(size_t _offset);
    std::expected<void, Error> DoMoveWindowSeqential(size_t _offset);

    std::shared_ptr<VFSFile> m_File;
    std::unique_ptr<uint8_t[]> m_Window;
    size_t m_WindowSize = std::numeric_limits<size_t>::max();
    size_t m_WindowPos = std::numeric_limits<size_t>::max();
};

} // namespace nc::vfs
