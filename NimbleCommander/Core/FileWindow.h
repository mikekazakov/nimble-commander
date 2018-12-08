// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFS/VFSFile.h"

class FileWindow
{
public:
    enum
    {
        DefaultWindowSize = 32768
    };

    /**
     * For files with Sequential and Seek read paradigms, FileWindow need exclusive access to VFSFile,
     * so that no one else can touch it's seek pointers.
     */
    int OpenFile(const std::shared_ptr<VFSFile> &_file, int _window_size = DefaultWindowSize);

    int CloseFile();
    bool FileOpened() const;
    
    /**
     * Returns size of an underlying VFS file.
     */
    size_t FileSize() const;
    
    /**
     * Raw pointer to a data window in file. Size of this window is WindowSize.
     */
    void *Window() const;
    
    /**
     * WindowSize can't be larger than FileSize.
     */
    size_t WindowSize() const;
    
    /**
     * Current window position in file.
     */
    size_t WindowPos() const;
    
    /**
     * Move window position in file and immediately reload it's content.
     * Will move only in valid boundaries. in case of invalid boundaries return InvalidCall.
     * Behaves depending on VFS files - when it supports Random access, it will just move indeces.
     * For Seek paradigm it will call Seek().
     * For Sequential paradigm it will read until met the requested position.
     * In Sequential case any call to move _offset lower than current position fill fail with InvalidCall error.
     */
    int MoveWindow(size_t _offset);
    
    /**
     * Returns underlying VFS file.
     */
    const VFSFilePtr& File() const;
    
private:
    int ReadFileWindowRandomPart(size_t _offset, size_t _len);
    int ReadFileWindowSeqPart(size_t _offset, size_t _len);

    std::shared_ptr<VFSFile> m_File;
    std::unique_ptr<uint8_t[]> m_Window;
    size_t m_WindowSize = std::numeric_limits<size_t>::max();
    size_t m_WindowPos = std::numeric_limits<size_t>::max();
};
