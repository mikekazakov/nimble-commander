// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSError.h>
#include <string>
#include <string_view>
#include <span>

namespace nc::vfs::webdav {

class WriteBuffer;
class ReadBuffer;

// TODO: "NonBlocking" is a lie - it's blocking. Need to find a better term
class Connection
{
public:
    static constexpr size_t ConcludeBodyWrite = std::numeric_limits<size_t>::max() - 1;
    static constexpr size_t AbortBodyWrite = std::numeric_limits<size_t>::max() - 2;
    static constexpr size_t AbortBodyRead = std::numeric_limits<size_t>::max() - 1;

    virtual ~Connection() = default;

    // Resets the connection to a pristine state regarding settings
    virtual void Clear() = 0;

    //==============================================================================================
    // Setting a request up. All these functions copy the input data
    virtual std::expected<void, Error> SetCustomRequest(std::string_view _request) = 0;
    virtual std::expected<void, Error> SetURL(std::string_view _url) = 0;
    virtual std::expected<void, Error> SetHeader(std::span<const std::string_view> _header) = 0;
    virtual std::expected<void, Error> SetBody(std::span<const std::byte> _body) = 0;
    virtual std::expected<void, Error> SetNonBlockingUpload(size_t _upload_size) = 0;
    virtual void MakeNonBlocking() = 0;

    //==============================================================================================
    // Queries
    virtual std::expected<int, Error> PerformBlockingRequest() = 0; // http return code or error
    virtual WriteBuffer &RequestBody() = 0;
    virtual ReadBuffer &ResponseBody() = 0;
    virtual std::string_view ResponseHeader() = 0;

    //==============================================================================================
    // "Multi" queries

    // AbortBodyRead size abort a pending download
    virtual std::expected<void, Error> ReadBodyUpToSize(size_t _target) = 0;

    // assumes the data is already in RequestBody
    // ConcludeBodyWrite and AbortBodyWrite are special 'sizes' that make the function behave
    // differently.
    // ConcludeBodyWrite makes the connection to perform pending operations without stopping once a
    // buffer was drained. AbortBodyWrite makes the connection to softly abort pending operations.
    virtual std::expected<void, Error> WriteBodyUpToSize(size_t _target) = 0;
};

} // namespace nc::vfs::webdav
