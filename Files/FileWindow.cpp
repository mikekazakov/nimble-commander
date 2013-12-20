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

FileWindow::FileWindow():
    m_ShouldClose(false)
{
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
        assert(m_WindowPos == -1);
        assert(m_WindowSize == -1);
        return false;
    }
    return true;
}

int FileWindow::OpenFile(shared_ptr<VFSFile> _file)
{
    return OpenFile(_file, DefaultWindowSize);
}

int FileWindow::OpenFile(shared_ptr<VFSFile> _file, int _window_size)
{
    if(_file->GetReadParadigm() < VFSFile::ReadParadigm::Random)
        return VFSError::InvalidCall;
    
    m_File = _file;
    if(!m_File->IsOpened())
    {
        int res = m_File->Open(VFSFile::OF_Read);
        if( res < 0)
            return res;
        m_ShouldClose = true;
    }
        
    
    if(m_File->Size() < _window_size)
        m_WindowSize = m_File->Size();
    else
        m_WindowSize = _window_size;
    
    m_Window = malloc(m_WindowSize);
    m_WindowPos = 0;
    
    int ret = ReadFileWindow();
    if(ret < 0)
        return ret;
    
    return VFSError::Ok;
}

int FileWindow::CloseFile()
{
    if(FileOpened())
    {
        if(m_ShouldClose)
            m_File->Close();
        m_File.reset();
        free(m_Window);
        m_Window = 0;
        m_WindowPos = -1;
        m_WindowSize = -1;
        m_ShouldClose = false;
    }
    
    return VFSError::Ok;
}

int FileWindow::ReadFileWindow()
{
    return ReadFileWindowPart(0, m_WindowSize);
}

int FileWindow::ReadFileWindowPart(size_t _offset, size_t _len)
{
    if(_len == 0)
        return VFSError::Ok;
    if(_offset + _len > m_WindowSize)
        return VFSError::InvalidCall;
    
    ssize_t readret = m_File->ReadAt(m_WindowPos + _offset, (unsigned char*)m_Window + _offset, _len);
    if(readret < 0)
        return (int)readret;
    
    if(readret < _len) // whatif readret is 0 (EOF) - we may fall into recursion here
        return ReadFileWindowPart(_offset + readret, _len - readret);
    
    return VFSError::Ok;
}

size_t FileWindow::FileSize() const
{
    assert(FileOpened());
    return m_File->Size();
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
    assert(FileOpened());
    
    if(_offset == m_WindowPos)
        return VFSError::Ok;
    
    if(_offset + m_WindowSize > m_File->Size())
    {
        return VFSError::InvalidCall;
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
