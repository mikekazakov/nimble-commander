#include "FileWindow.h"
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>
#include <memory.h>

FileWindow::FileWindow()
{
    m_FD = -1;
    m_FileSize = -1;
    m_Window = 0;
    m_WindowPos = -1;
    m_WindowSize = -1;
}

FileWindow::~FileWindow()
{
    assert(!FileOpened()); // no OOP! file windows should be closed explicitly right after it became out of need
}

bool FileWindow::FileOpened() const
{
    if(m_Window == 0)
    {
        // sanity check
        assert(m_FD == -1);
        assert(m_WindowPos == -1);
        assert(m_WindowSize == -1);
        assert(m_FileSize == -1);
        return false;
    }
    return true;
}

int FileWindow::OpenFile(const char *_path)
{
    return OpenFile(_path, DefaultWindowSize);
}

int FileWindow::OpenFile(const char *_path, int _window_size)
{
    if(FileOpened())
    {
        assert(0); // using Open on already opened file means saniy breach, which should not be
        exit(0);
    }
    
    if(access(_path, F_OK) == -1)
        return ERROR_FILENOTEXIST;
    
    if(access(_path, R_OK) == -1)
        return ERROR_FILENOACCESS;
    
    struct stat stat_buffer;
    if(stat(_path, &stat_buffer) != 0)
        return ERROR_FILENOACCESS;
    
    if((stat_buffer.st_mode & S_IFMT) == S_IFDIR )
        return ERROR_FILENOACCESS; // we can't read directory entries with regular I/O
    
    int newfd = open(_path, O_RDONLY);
    if(newfd == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    
    m_FD = newfd;
    
    off_t epos = lseek(m_FD, 0, SEEK_END);
    if(epos == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    
    m_FileSize = epos;
    
    
    if(m_FileSize < _window_size)
        m_WindowSize = m_FileSize;
    else
        m_WindowSize = _window_size;
    
    m_Window = malloc(m_WindowSize);
    m_WindowPos = 0;
    
    int ret = ReadFileWindow();
    if(ret != ERROR_OK)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    
    return ERROR_OK;
}

int FileWindow::CloseFile()
{
    if(!FileOpened())
    {
        assert(0); // closing a not-opened file means sanity breach, which should not be
        exit(0);
    }
    
    int ret = close(m_FD);
    if(ret == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    
    free(m_Window);
    m_FD = -1;
    m_Window = 0;
    m_FileSize = -1;
    m_WindowPos = -1;
    m_WindowSize = -1;
    
    return ERROR_OK;
}

int FileWindow::ReadFileWindow()
{
    if(m_WindowSize > 0) // no meaning in reading 0-bytes window
    {
        size_t r = pread(m_FD, m_Window, m_WindowSize, m_WindowPos);
        if(r == -1)
        {
            assert(0); // TODO: handle this situation later
            exit(0);
        }
        if(r != m_WindowSize)
        {
            assert(0); // TODO: handle this situation later
            exit(0);
        }
    }
    
    return ERROR_OK;
}

int FileWindow::ReadFileWindowPart(size_t _offset, size_t _len)
{
    assert(_offset + _len <= m_WindowSize);
    if(_len == 0)
        return ERROR_OK;
    
    size_t r = pread(m_FD, (unsigned char*)m_Window + _offset, _len, m_WindowPos + _offset);
    if(r == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    if(r != _len)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    
    return ERROR_OK;
}

size_t FileWindow::FileSize() const
{
    assert(FileOpened());
    return m_FileSize;
}

void *FileWindow::Window() const
{
    assert(FileOpened());
    return m_Window;
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

int FileWindow::MoveWindow(size_t _offset)
{
    // TODO: need more intelligent reading - in case of overlapping window movements we don't need to read a whole block
    
    assert(FileOpened());
    
    if(_offset == m_WindowPos)
        return ERROR_OK;
    
    if(_offset + m_WindowSize > m_FileSize)
    {
        // invalid call. just kill ourselves
        assert(0);
        exit(0);
    }
    
    // check for overlapping window movements
   if( (_offset >= m_WindowPos && _offset <= m_WindowPos + m_WindowSize) ||
        (_offset + m_WindowSize >= m_WindowPos && _offset <= m_WindowPos)
       )
    {
        // read only unknown data
        if(_offset >= m_WindowPos && _offset <= m_WindowPos + m_WindowSize)
        {
            memmove(m_Window,
                    (const unsigned char*)m_Window + _offset - m_WindowPos,
                    m_WindowSize - (_offset - m_WindowPos)
                    );
            size_t off = m_WindowSize - (_offset - m_WindowPos);
            size_t len = _offset - m_WindowPos;
            m_WindowPos = _offset;
            return ReadFileWindowPart(off, len);
        }
        else
        {
            memmove( (unsigned char*)m_Window + m_WindowSize - (_offset + m_WindowSize - m_WindowPos),
                    m_Window,
                    _offset + m_WindowSize - m_WindowPos
                    );
            size_t off = 0;
            size_t len = m_WindowPos - _offset;
            m_WindowPos = _offset;
            return ReadFileWindowPart(off, len);
        }
    }
    else
    {
        // no overlapping - just move and read all window
        m_WindowPos = _offset;
        return ReadFileWindow();
    }
}
