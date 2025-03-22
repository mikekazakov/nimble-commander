// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TemporaryFileStorage.h"
#include <Base/algo.h>
#include <cstdio>
#include <unistd.h>

namespace nc::utility {

std::optional<std::string> TemporaryFileStorage::MakeFile(std::string_view _filename)
{
    auto opened_file = OpenFile(_filename);
    if( opened_file == std::nullopt )
        return std::nullopt;
    return std::make_optional(std::move(opened_file->path));
}

std::optional<std::string> TemporaryFileStorage::MakeFileFromMemory(std::string_view _memory,
                                                                    std::string_view _filename)
{
    auto opened_file = OpenFile(_filename);
    if( opened_file == std::nullopt )
        return std::nullopt;

    const char *memory = _memory.data();
    ssize_t left = _memory.size();
    while( left > 0 ) {
        const ssize_t written = write(opened_file->file_descriptor, memory, left);
        if( written >= 0 ) {
            left -= written;
            memory += written;
        }
        else {
            unlink(opened_file->path.c_str());
            return std::nullopt;
        }
    }
    return std::make_optional(std::move(opened_file->path));
}

TemporaryFileStorage::OpenedFile::OpenedFile(OpenedFile &&_rhs)
    : path{std::move(_rhs.path)}, file_descriptor{_rhs.file_descriptor}
{
    _rhs.file_descriptor = -1;
}

TemporaryFileStorage::OpenedFile::~OpenedFile()
{
    if( file_descriptor != -1 )
        close(file_descriptor);
}

TemporaryFileStorage::OpenedFile &TemporaryFileStorage::OpenedFile::operator=(TemporaryFileStorage::OpenedFile &&_rhs)
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

} // namespace nc::utility
