// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>
#include <optional>
#include <stdio.h>
#include <unistd.h>

namespace nc::utility {

class TemporaryFileStorage
{
public:
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
    virtual std::optional<std::string> MakeDirectory(std::string_view _filename = {}) = 0;

    struct OpenedFile {
        OpenedFile() = default;
        OpenedFile(OpenedFile &&) noexcept;
        OpenedFile(const OpenedFile &) = delete;
        ~OpenedFile();
        OpenedFile &operator=(const OpenedFile &) = delete;
        OpenedFile &operator=(OpenedFile &&) noexcept;
        std::string path;
        int file_descriptor = -1;
    };
    /**
     * Opens a new file and returns a POSIX I/O file descriptor.
     */
    virtual std::optional<OpenedFile> OpenFile(std::string_view _filename = {}) = 0;

    /**
     * Creates a new empty file.
     */
    virtual std::optional<std::string> MakeFile(std::string_view _filename = {});

    /**
     * Writes a new temp file with a provided _memory.
     */
    virtual std::optional<std::string> MakeFileFromMemory(std::string_view _memory, std::string_view _filename = {});
};

} // namespace nc::utility
