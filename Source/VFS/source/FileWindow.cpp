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
        if( const std::expected<void, Error> ret = ReadFileWindowRandomPart(0, m_WindowSize); !ret )
            return std::unexpected(ret.error());
    }
    else {
        if( const std::expected<void, Error> ret = ReadFileWindowSeqPart(0, m_WindowSize); !ret )
            return std::unexpected(ret.error());
    }

    return {};
}

void FileWindow::CloseFile()
{
    m_File.reset();
    m_Window.reset();
    m_WindowPos = -1;
    m_WindowSize = -1;
}

std::expected<void, Error> FileWindow::ReadFileWindowRandomPart(size_t _offset, size_t _len)
{
    if( _len == 0 )
        return {};

    if( _offset + _len > m_WindowSize )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const std::expected<size_t, Error> readret = m_File->ReadAt(m_WindowPos + _offset, m_Window.get() + _offset, _len);
    if( !readret )
        return std::unexpected(readret.error());

    if( readret == 0 )
        return std::unexpected(Error{Error::POSIX, EIO});

    if( *readret < _len )
        return ReadFileWindowRandomPart(_offset + *readret, _len - *readret);

    return {};
}

std::expected<void, Error> FileWindow::ReadFileWindowSeqPart(size_t _offset, size_t _len)
{
    if( _len == 0 )
        return {};

    if( _offset + _len > m_WindowSize )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const ssize_t readret = m_File->Read(m_Window.get() + _offset, _len);
    if( readret < 0 )
        return std::unexpected(VFSError::ToError(static_cast<int>(readret)));

    if( readret == 0 )
        return std::unexpected(Error{Error::POSIX, EIO});

    if( static_cast<size_t>(readret) < _len )
        return ReadFileWindowSeqPart(_offset + readret, _len - readret);

    return {};
}

std::expected<void, Error> FileWindow::MoveWindow(size_t _offset)
{
    if( !FileOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( _offset == m_WindowPos )
        return {};

    if( _offset + m_WindowSize > static_cast<size_t>(m_File->Size()) )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    switch( m_File->GetReadParadigm() ) {
        case VFSFile::ReadParadigm::Random:
            return DoMoveWindowRandom(_offset);
        case VFSFile::ReadParadigm::Seek:
            return DoMoveWindowSeek(_offset);
        case VFSFile::ReadParadigm::Sequential:
            return DoMoveWindowSeqential(_offset);
        case VFSFile::ReadParadigm::NoRead:
            return std::unexpected(Error{Error::POSIX, EINVAL});
    }

    return std::unexpected(Error{Error::POSIX, EINVAL});
}

std::expected<void, Error> FileWindow::DoMoveWindowRandom(size_t _offset)
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

std::expected<void, Error> FileWindow::DoMoveWindowSeek(size_t _offset)
{
    // TODO: not efficient implementation, update me
    const ssize_t ret = m_File->Seek(_offset, VFSFile::Seek_Set);
    if( ret < 0 )
        return std::unexpected(VFSError::ToError(static_cast<int>(ret)));

    m_WindowPos = _offset;
    return ReadFileWindowSeqPart(0, m_WindowSize);
}

std::expected<void, Error> FileWindow::DoMoveWindowSeqential(size_t _offset)
{
    // check for possible variants
    if( _offset >= m_WindowPos && _offset <= m_WindowPos + m_WindowSize ) {
        // overlapping
        std::memmove(m_Window.get(), m_Window.get() + _offset - m_WindowPos, m_WindowSize - (_offset - m_WindowPos));
        const size_t off = m_WindowSize - (_offset - m_WindowPos);
        const size_t len = _offset - m_WindowPos;
        m_WindowPos = _offset;
        const std::expected<void, Error> ret = ReadFileWindowSeqPart(off, len);
        if( ret )
            assert(ssize_t(m_WindowPos + m_WindowSize) == m_File->Pos());
        return ret;
    }
    else if( _offset >= m_WindowPos ) {
        // need to move forward
        assert(m_File->Pos() < ssize_t(_offset));
        const size_t to_skip = _offset - m_File->Pos();

        if( const std::expected<void, nc::Error> ret = m_File->Skip(to_skip); !ret )
            return ret;

        m_WindowPos = _offset;
        return ReadFileWindowSeqPart(0, m_WindowSize);
    }
    else // invalid case - moving back was requested
        return std::unexpected(Error{Error::POSIX, EINVAL});
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
