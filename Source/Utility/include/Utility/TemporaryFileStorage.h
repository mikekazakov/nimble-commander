// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>
#include <optional>
#include <stdio.h>
#include <unistd.h>

namespace nc::utility {

class TemporaryFileStorage
{
public :
    virtual ~TemporaryFileStorage() = default;
    
    /**
     * Filenames handling:
     * If _filename is non-empty TemporaryFileStorage will ensure that the new file or directory
     * will have this filename and there was no collision with previously existing ones (doesn't
     * overwrite exiting entries). Otherwise the filename will be a combination of upper-case
     * letters and numbers with no extension.
     */

    /**
     * Creates a new temp directory.
     * Resulting path will contain a trailing slash.
     */
    virtual std::optional<std::string> MakeDirectory( std::string_view _filename = {} ) = 0;
    
    struct OpenedFile {
        OpenedFile() = default;
        OpenedFile(OpenedFile&&);
        OpenedFile(const OpenedFile&) = delete;
        ~OpenedFile();
        OpenedFile &operator=(const OpenedFile&) = delete;
        OpenedFile &operator=(OpenedFile&&);
        std::string path;
        int file_descriptor = -1;
    };
    /**
     * Opens a new file and returns a POSIX I/O file descriptor.
     */
    virtual std::optional<OpenedFile> OpenFile( std::string_view _filename = {} ) = 0;
    
    /**
     * Creates a new empty file.
     */
    virtual std::optional<std::string> MakeFile( std::string_view _filename = {} );
    
    /**
     * Writes a new temp file with a provided _memory.
     */
    virtual std::optional<std::string> MakeFileFromMemory( std::string_view _memory,
                                                           std::string_view _filename = {} );
};
        
inline TemporaryFileStorage::OpenedFile::OpenedFile(OpenedFile&& _rhs):
    path{std::move(_rhs.path)},
    file_descriptor{_rhs.file_descriptor}    
{
    _rhs.file_descriptor = -1;
}
    
inline TemporaryFileStorage::OpenedFile::~OpenedFile()
{
    if( file_descriptor != -1 )
        close(file_descriptor);
}
    
inline TemporaryFileStorage::OpenedFile &
    TemporaryFileStorage::OpenedFile::operator=(TemporaryFileStorage::OpenedFile &&_rhs)
{
    if( this != &_rhs ) {
        if( file_descriptor != -1 )
            close(file_descriptor);
        file_descriptor = _rhs.file_descriptor;
        _rhs.file_descriptor = -1;
        path = std::move(_rhs.path);
    }
    return *this;
}

}

