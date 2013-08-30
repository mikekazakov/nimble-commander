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
//    m_FD = -1;
//    m_FileSize = -1;
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
//        assert(m_FD == -1);
        assert(m_WindowPos == -1);
        assert(m_WindowSize == -1);
//        assert(m_FileSize == -1);
        return false;
    }
    return true;
}

//int OpenFile(std::shared_ptr<VFSFile> _file); // will include VFS later
//int OpenFile(std::shared_ptr<VFSFile> _file, int _window_size);


//int FileWindow::OpenFile(const char *_path)
int FileWindow::OpenFile(std::shared_ptr<VFSFile> _file)
{
    return OpenFile(_file, DefaultWindowSize);
}

int FileWindow::OpenFile(std::shared_ptr<VFSFile> _file, int _window_size)
//int FileWindow::OpenFile(const char *_path, int _window_size)
{
/*    if(FileOpened())
    {
        assert(0); // using Open on already opened file means sanity breach, which should not be
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
//        assert(0); // TODO: handle this situation later
//        exit(0);
        return ERROR_FILENOACCESS;
    }
    
    m_FD = newfd;
    
    off_t epos = lseek(m_FD, 0, SEEK_END);
    if(epos == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    
    m_FileSize = epos;*/
    
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
    {
//        assert(0); // TODO: handle this situation later
//        exit(0);
        return ret;
    }
    
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
    
/*    int ret = close(m_FD);
    if(ret == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }*/
    
//    free(m_Window);
//    m_FD = -1;
//    m_Window = 0;
//    m_FileSize = -1;
//    m_WindowPos = -1;
//    m_WindowSize = -1;
    
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
    
/*    size_t r = pread(m_FD, (unsigned char*)m_Window + _offset, _len, m_WindowPos + _offset);
    if(r == -1)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }
    if(r != _len)
    {
        assert(0); // TODO: handle this situation later
        exit(0);
    }*/
    
/*    off_t seekret = m_File->Seek(m_WindowPos + _offset, VFSFile::Seek_Set);
    if(seekret < 0)
        return (int)seekret;
    
    ssize_t readret = m_File->Read((unsigned char*)m_Window + _offset, _len);
    if(readret < 0)
        return (int)readret;*/
    
    ssize_t readret = m_File->ReadAt(m_WindowPos + _offset, (unsigned char*)m_Window + _offset, _len);
    if(readret < 0)
        return (int)readret;
    
    if(readret != _len)
    {
        assert(0);
        // need to write a cycle here to read a full size
        return VFSError::GenericError;
    }
    
    return VFSError::Ok;
}

size_t FileWindow::FileSize() const
{
    assert(FileOpened());
//    return m_FileSize;
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
    // TODO: need more intelligent reading - in case of overlapping window movements we don't need to read a whole block
    
    assert(FileOpened());
    
    if(_offset == m_WindowPos)
        return VFSError::Ok;
    
    if(_offset + m_WindowSize > m_File->Size())
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
