#pragma once

#include <stddef.h>

#include "VFSFile.h"

// TODO: remove this trash
//#define ERROR_OK            0
//#define ERROR_FILENOTEXIST  1
//#define ERROR_FILENOACCESS  2


class FileWindow
{
public:
    enum
    {
        DefaultWindowSize = 32768
    };

    FileWindow();
    ~FileWindow();
    
//    int OpenFile(const char *_path); // will include VFS later
//    int OpenFile(const char *_path, int _window_size);
    // return VFS error codes
    int OpenFile(shared_ptr<VFSFile> _file); // will include VFS later
    int OpenFile(shared_ptr<VFSFile> _file, int _window_size);

    int CloseFile();
    
    bool   FileOpened() const;
    size_t FileSize() const;
    void *Window() const;
    size_t WindowSize() const; // WindowSize can't be larger than FileSize
    size_t WindowPos() const;
    
    int MoveWindow(size_t _offset);
        // move window position in file and immediately reload it's content
        // will move only in valid boundaries. in case of invalid boundaries it will assert and then exit(0)
    
private:
    int ReadFileWindow();
    int ReadFileWindowPart(size_t _offset, size_t _len);
    
    FileWindow(const FileWindow&) = delete;
    void operator=(const FileWindow&_r) = delete;
    
//    int m_FD; // will be some more complex after VFS design
  //  size_t m_FileSize;
    shared_ptr<VFSFile> m_File;
    bool m_ShouldClose;
    void *m_Window;
    size_t m_WindowSize;
    size_t m_WindowPos;
};
