// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <vector>
#include <stdint.h>
#include "VFSDeclarations.h"
#include <Base/Error.h>

#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

class VFSFile : public std::enable_shared_from_this<VFSFile>
{
public:
    enum class ReadParadigm : uint8_t {
        // The best possible variant - can read a block of data at a random offset.
        // Seeking is also possible.
        Random = 3,

        // Classic I/O - can seek and sequentially read the requested data.
        Seek = 2,

        // The worst variant - can only read a file sequentially from the beginning
        // (http downloading without resuming for example)
        // Should also support Skip operation, which can be not cheap.
        Sequential = 1,

        // This file cannot be read
        NoRead = 0
    };

    enum class WriteParadigm : uint8_t {
        // Supports writing at a random offset, not currently implemented.
        Random = 4,

        // Classic I/O - can seek and sequentially write the requested data.
        Seek = 3,

        // Can only write a file sequentially from the beginning.
        Sequential = 2,

        // The client code needs to specify the full size of the data that will be written in advance.
        Upload = 1,

        // This file cannot be written to.
        NoWrite = 0
    };

    // Construct a file that points to the specified path on the host.
    // Paths are relative to the host's root.
    VFSFile(std::string_view _relative_path, const VFSHostPtr &_host);

    // Copy constructor is disabled
    VFSFile(const VFSFile &) = delete;

    // Destructor.
    virtual ~VFSFile();

    // Move assignment is disabled
    VFSFile &operator=(const VFSFile &) = delete;

    // Syntax sugar around shared_from_this().
    std::shared_ptr<VFSFile> SharedPtr();

    // Syntax sugar around shared_from_this().
    std::shared_ptr<const VFSFile> SharedPtr() const;

    // Returns the path of this file.
    const char *Path() const noexcept;

    // Returns the host to which this file belongs to.
    const std::shared_ptr<VFSHost> &Host() const;

    // Clone() returns an object of the same type with the same parent host and the relative path.
    // Open status and file positions are not shared.
    // Can return a null pointer in some cases.
    virtual std::shared_ptr<VFSFile> Clone() const;

    // Opens the file with the specified flags, semantics are similar to POSIX open().
    virtual std::expected<void, nc::Error> Open(unsigned long _open_flags,
                                                const VFSCancelChecker &_cancel_checker = {});

    // Returns true if the file is currently opened.
    virtual bool IsOpened() const;

    // Closes the file.
    virtual std::expected<void, nc::Error> Close();

    // Optional, by default vfs doesn't provide such information.
    virtual std::expected<size_t, nc::Error> PreferredIOSize() const;

    // Return the available read paradigm for this VFS at this path.
    // Should return some considerable value even on non-opened files.
    virtual ReadParadigm GetReadParadigm() const;

    // Return the available write paradigm for this VFS at this path.
    // Should return some considerable value even on non-opened files.
    virtual WriteParadigm GetWriteParadigm() const;

    // Reads the specified amount of bytes into the specified buffer.
    // Returns the amount of read bytes, which can be less than requested.
    virtual std::expected<size_t, nc::Error> Read(void *_buf, size_t _size);

    // ReadAt is available only on Random level.
    // It will not move any file pointers.
    // Reads up to _size bytes, may return less.
    virtual std::expected<size_t, nc::Error> ReadAt(off_t _pos, void *_buf, size_t _size);

    // Reads and discards _size bytes.
    virtual std::expected<void, nc::Error> Skip(size_t _size);

    // For Upload write paradigm: sets upload size in advance, so the file object can set up its data structures and
    // do an actual upload on Write() call when the client hits the stated size.
    // May be ignored by other write paradigms.
    // If _size is zero - the file object may perform an actual upload.
    // Default implementation returns Ok.
    virtual std::expected<void, nc::Error> SetUploadSize(size_t _size);

    // Writes up to _size bytes from _buf to the file in a blocking mode.
    // Returns the amount of bytes written.
    virtual std::expected<size_t, nc::Error> Write(const void *_buf, size_t _size);

    static constexpr int Seek_Set = 0;
    static constexpr int Seek_Cur = 1;
    static constexpr int Seek_End = 2;

    // Seek() is available if Read paradigm is Seek or above.
    virtual std::expected<uint64_t, nc::Error> Seek(off_t _off, int _basis);

    // Implementations should always provide Pos(), the base class always returns ENOTSUP.
    virtual std::expected<uint64_t, nc::Error> Pos() const;

    // Implementations should always provide Size(), the base class always returns ENOTSUP.
    virtual std::expected<uint64_t, nc::Error> Size() const;

    // Eof() should always be available, returns true on invalid file state.
    virtual bool Eof() const;

    // XAttrCount() should be always available, returning 0 on non-supported case.
    // This function may cause blocking I/O.
    virtual unsigned XAttrCount() const;

    // Return true to allow further iteration, false to stop it.
    using XAttrIterateNamesCallback = std::function<bool(std::string_view _xattr_name)>;

    // XAttrIterateNames() will call block with every xattr name for this file while handler returns true.
    // This function may cause blocking I/O.
    virtual void XAttrIterateNames(const XAttrIterateNamesCallback &_handler) const;

    // XAttrGet copies the extended attribute value named _xattr_name into the buffer _buffer limited with _buf_size.
    // If the requested xattr was not found this function returns POSIX/ENOATTR.
    // If _buffer is nullptr and the requested xattr was found then the size of this xattr is returned.
    // If _buf_size is smaller than the buffer required for _xattr_name then the data will be truncated and _buf_size
    // will be returned. Generally this function returns the amount of bytes copied (note that a valid xattr value can
    // be 0 bytes long). This function may cause blocking I/O.
    virtual std::expected<size_t, nc::Error>
    XAttrGet(std::string_view _xattr_name, void *_buffer, size_t _buf_size) const;

    // ComposeVerbosePath() relies solely on Host() and VerboseJunctionPath().
    std::string ComposeVerbosePath() const;

    // ReadFile() returns the full file content in a vector<uint8_t> or an Error.
    // Helper function, non-virtual.
    std::expected<std::vector<uint8_t>, nc::Error> ReadFile();

#ifdef __OBJC__
    // ReadFileToNSData() returns the full file content in NSData object or nil.
    // It's a syntax sugar wrapper for Cocoa APIs around ReadFile().
    // Helper function, non-virtual.
    NSData *ReadFileToNSData();
#endif

    // Will call Write until data ends or an error occurs.
    // Returns an error on failure.
    // Helper function, non-virtual.
    std::expected<void, nc::Error> WriteFile(const void *_d, size_t _sz);

private:
    std::string m_RelativePath;
    std::shared_ptr<VFSHost> m_Host;
};
