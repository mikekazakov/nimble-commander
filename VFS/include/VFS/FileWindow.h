// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
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
    enum
    {
        DefaultWindowSize = 32768
    };
    
    FileWindow() = default;
    
    /**
     * Creates a default objects and calls Attach(). Will throw VFSErrorExpection on error.
     */
    FileWindow(const std::shared_ptr<VFSFile> &_file, int _window_size = DefaultWindowSize);

    /**
     * For files with Sequential and Seek read paradigms, FileWindow needs exclusive access to
     * VFSFile, so that no one else can touch it's seek pointers.
     * Returns VFSError.
     */
    int Attach(const std::shared_ptr<VFSFile> &_file,
                 int _window_size = DefaultWindowSize);

    /**
     * Closes the VFSFile pointer and the memory buffer.
     */
    int CloseFile();
    bool FileOpened() const;
    
    /**
     * Returns current size of an underlying VFS file, effectively calling File()->Size().
     */
    size_t FileSize() const;
    
    /**
     * Return the raw pointer to the data window in file. Size of this window is WindowSize().
     */
    const void *Window() const;
    
    /**
     * Size of a file window in bytes.
     * WindowSize can't be larger than FileSize.
     */
    size_t WindowSize() const;
    
    /**
     * Returns the current window position in file.
     */
    size_t WindowPos() const;
    
    /**
     * Move window position in file and immediately reload it's content.
     * Will move only in valid boundaries. in case of invalid boundaries return InvalidCall.
     * Behaves depending on VFS files - when it supports Random access, it will just move indeces.
     * For Seek paradigm it will call Seek().
     * For Sequential paradigm it will read until met the requested position.
     * In Sequential case any call to move _offset lower than current position fill fail with
     * InvalidCall error.
     * Returns VFSError.
     */
    int MoveWindow(size_t _offset);
    
    /**
     * Returns underlying VFS file.
     */
    const VFSFilePtr& File() const;
    
private:
    int ReadFileWindowRandomPart(size_t _offset, size_t _len);
    int ReadFileWindowSeqPart(size_t _offset, size_t _len);
    int DoMoveWindowRandom(size_t _offset);
    int DoMoveWindowSeek(size_t _offset);
    int DoMoveWindowSeqential(size_t _offset);

    std::shared_ptr<VFSFile> m_File;
    std::unique_ptr<uint8_t[]> m_Window;
    size_t m_WindowSize = std::numeric_limits<size_t>::max();
    size_t m_WindowPos = std::numeric_limits<size_t>::max();
};

inline size_t FileWindow::FileSize() const
{
    assert(FileOpened());
    return m_File->Size();
}
    
inline const void *FileWindow::Window() const
{
    assert(FileOpened());
    return m_Window.get();
}
    
inline size_t FileWindow::WindowSize() const
{
    assert(FileOpened());
    return m_WindowSize;
}
    
inline size_t FileWindow::WindowPos() const
{
    assert(FileOpened());
    return m_WindowPos;
}
    
inline const VFSFilePtr& FileWindow::File() const
{
    return m_File;
}
    
}
