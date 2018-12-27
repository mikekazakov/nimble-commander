// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TemporaryFileStorage.h"
#include <Habanero/algo.h>
#include <stdio.h>
#include <unistd.h>

namespace nc::utility {

std::optional<std::string> TemporaryFileStorage::MakeFile( std::string_view _filename )
{
    auto opened_file = OpenFile(_filename);
    if( opened_file == std::nullopt )
        return std::nullopt;
    return std::make_optional( std::move(opened_file->path) );
}

std::optional<std::string> TemporaryFileStorage::MakeFileFromMemory( std::string_view _memory,
                                                                     std::string_view _filename )
{
    auto opened_file = OpenFile(_filename);
    if( opened_file == std::nullopt )
        return std::nullopt;

    const char *memory = _memory.data();
    ssize_t left = _memory.size();
    while( left > 0 ) {
        ssize_t written = write( opened_file->file_descriptor, memory, left );
        if( written >= 0 ) {
            left -= written;
            memory += written;
        }
        else {
            unlink( opened_file->path.c_str() );
            return std::nullopt;
        }
    }
    return std::make_optional( std::move(opened_file->path) );
}

}
