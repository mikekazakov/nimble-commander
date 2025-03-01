// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/FileWindow.h>
#include <cassert>

namespace nc::vfs {

FileWindow::FileWindow(const std::shared_ptr<VFSFile> &_file, int _window_size)
{
    const std::expected<void, Error> rc = Attach(_file, _window_size);
    if( !rc )
        throw ErrorException{rc.error()};
}

bool FileWindow::FileOpened() const
{
    return m_Window != nullptr;
}

std::expected<void, Error> FileWindow::Attach(const std::shared_ptr<VFSFile> &_file, int _window_size)
{
    if( !_file->IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( _file->GetReadParadigm() == VFSFile::ReadParadigm::NoRead )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    m_File = _file;
    m_WindowSize = std::min(m_File->Size(), static_cast<ssize_t>(_window_size));
    m_Window = std::make_unique<uint8_t[]>(m_WindowSize);
    m_WindowPos = 0;

    if( m_File->GetReadParadigm() == VFSFile::ReadParadigm::Random ) {
        const int ret = ReadFileWindowRandomPart(0, m_WindowSize);
        if( ret < 0 )
            return std::unexpected(VFSError::ToError(ret));
    }
    else {
        const int ret = ReadFileWindowSeqPart(0, m_WindowSize);
        if( ret < 0 )
            return std::unexpected(VFSError::ToError(ret));
    }

    return {};
}

int FileWindow::CloseFile()
{
    m_File.reset();
    m_Window.reset();
    m_WindowPos = -1;
    m_WindowSize = -1;
    return VFSError::Ok;
}

int FileWindow::ReadFileWindowRandomPart(size_t _offset, size_t _len)
{
    if( _len == 0 )
        return VFSError::Ok;

    if( _offset + _len > m_WindowSize )
        return VFSError::InvalidCall;

    const ssize_t readret = m_File->ReadAt(m_WindowPos + _offset, m_Window.get() + _offset, _len);
    if( readret < 0 )
        return static_cast<int>(readret);

    if( readret == 0 )
        return VFSError::UnexpectedEOF;

    if( static_cast<size_t>(readret) < _len )
        return ReadFileWindowRandomPart(_offset + readret, _len - readret);

    return VFSError::Ok;
}

int FileWindow::ReadFileWindowSeqPart(size_t _offset, size_t _len)
{
    if( _len == 0 )
        return VFSError::Ok;

    if( _offset + _len > m_WindowSize )
        return VFSError::InvalidCall;

    const ssize_t readret = m_File->Read(m_Window.get() + _offset, _len);
    if( readret < 0 )
        return static_cast<int>(readret);

    if( readret == 0 )
        return VFSError::UnexpectedEOF;

    if( static_cast<size_t>(readret) < _len )
        return ReadFileWindowSeqPart(_offset + readret, _len - readret);

    return VFSError::Ok;
}

int FileWindow::MoveWindow(size_t _offset)
{
    if( !FileOpened() )
        return VFSError::InvalidCall;

    if( _offset == m_WindowPos )
        return VFSError::Ok;

    if( _offset + m_WindowSize > static_cast<size_t>(m_File->Size()) )
        return VFSError::InvalidCall;

    switch( m_File->GetReadParadigm() ) {
        case VFSFile::ReadParadigm::Random:
            return DoMoveWindowRandom(_offset);
        case VFSFile::ReadParadigm::Seek:
            return DoMoveWindowSeek(_offset);
        case VFSFile::ReadParadigm::Sequential:
            return DoMoveWindowSeqential(_offset);
        case VFSFile::ReadParadigm::NoRead:
            return VFSError::InvalidCall;
    }

    return VFSError::InvalidCall;
}

int FileWindow::DoMoveWindowRandom(size_t _offset)
{
    // check for overlapping window movements
    if( _offset >= m_WindowPos && _offset <= m_WindowPos + m_WindowSize ) {
        // the new offset is within current window, read only unknown data
        std::memmove(m_Window.get(), m_Window.get() + _offset - m_WindowPos, m_WindowSize - (_offset - m_WindowPos));
        const size_t off = m_WindowSize - (_offset - m_WindowPos);
        const size_t len = _offset - m_WindowPos;
        m_WindowPos = _offset;
        return ReadFileWindowRandomPart(off, len);
    }
    else if( _offset + m_WindowSize >= m_WindowPos && _offset <= m_WindowPos ) {
        // the new offset is before current offset, but windows do overlap
        std::memmove(m_Window.get() + m_WindowPos - _offset, m_Window.get(), _offset + m_WindowSize - m_WindowPos);
        const size_t off = 0;
        const size_t len = m_WindowPos - _offset;
        m_WindowPos = _offset;
        return ReadFileWindowRandomPart(off, len);
    }
    else {
        // no overlapping - just move and read all window
        m_WindowPos = _offset;
        return ReadFileWindowRandomPart(0, m_WindowSize);
    }
}

int FileWindow::DoMoveWindowSeek(size_t _offset)
{
    // TODO: not efficient implementation, update me
    const ssize_t ret = m_File->Seek(_offset, VFSFile::Seek_Set);
    if( ret < 0 )
        return static_cast<int>(ret);

    m_WindowPos = _offset;
    return ReadFileWindowSeqPart(0, m_WindowSize);
}

int FileWindow::DoMoveWindowSeqential(size_t _offset)
{
    // check for possible variants
    if( _offset >= m_WindowPos && _offset <= m_WindowPos + m_WindowSize ) {
        // overlapping
        std::memmove(m_Window.get(), m_Window.get() + _offset - m_WindowPos, m_WindowSize - (_offset - m_WindowPos));
        const size_t off = m_WindowSize - (_offset - m_WindowPos);
        const size_t len = _offset - m_WindowPos;
        m_WindowPos = _offset;
        const int ret = ReadFileWindowSeqPart(off, len);
        if( ret == 0 )
            assert(ssize_t(m_WindowPos + m_WindowSize) == m_File->Pos());
        return ret;
    }
    else if( _offset >= m_WindowPos ) {
        // need to move forward
        assert(m_File->Pos() < ssize_t(_offset));
        const size_t to_skip = _offset - m_File->Pos();

        int ret = static_cast<int>(m_File->Skip(to_skip));
        if( ret < 0 )
            return ret;

        m_WindowPos = _offset;
        ret = ReadFileWindowSeqPart(0, m_WindowSize);
        return ret;
    }
    else // invalid case - moving back was requested
        return VFSError::InvalidCall;
}

size_t FileWindow::FileSize() const
{
    assert(FileOpened());
    return m_File->Size();
}

const void *FileWindow::Window() const
{
    assert(FileOpened());
    return m_Window.get();
}

size_t FileWindow::WindowSize() const
{
    assert(FileOpened());
    return m_WindowSize;
}

size_t FileWindow::WindowPos() const
{
    assert(FileOpened());
    return m_WindowPos;
}

const VFSFilePtr &FileWindow::File() const
{
    return m_File;
}

} // namespace nc::vfs
