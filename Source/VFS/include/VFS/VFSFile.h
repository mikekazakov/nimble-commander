// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <vector>
#include <stdint.h>
#include "VFSError.h"
#include "VFSDeclarations.h"
#include <Base/Error.h>
#include <optional>

#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

class VFSFile : public std::enable_shared_from_this<VFSFile>
{
public:
    enum class ReadParadigm {
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

    enum class WriteParadigm {
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
    virtual int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker = {});

    // Returns true if the file is currently opened.
    virtual bool IsOpened() const;

    // Closes the file.
    virtual int Close();

    // Negative value means that vfs doesn't provide such information.
    virtual int PreferredIOSize() const;

    // Return the available read paradigm for this VFS at this path.
    // Should return some considerable value even on non-opened files.
    virtual ReadParadigm GetReadParadigm() const;

    // Return the available write paradigm for this VFS at this path.
    // Should return some considerable value even on non-opened files.
    virtual WriteParadigm GetWriteParadigm() const;

    // ...
    virtual ssize_t Read(void *_buf, size_t _size);

    // For Upload write paradigm: sets upload size in advance, so the file object can set up its data structures and
    // do an actual upload on Write() call when the client hits the stated size.
    // May be ignored by other write paradigms.
    // If _size is zero - the file object may perform an actual upload.
    // Default implementation returns Ok.
    virtual int SetUploadSize(size_t _size);

    // Writes _size bytes from _buf to a file in blocking mode.
    // Returnes the amount of bytes written or negative value for errors.
    virtual ssize_t Write(const void *_buf, size_t _size);

    // Reads and discards _size bytes.
    virtual std::expected<void, nc::Error> Skip(size_t _size);

    // ReadAt is available only on Random level.
    // It will not move any file pointers.
    // Reads up to _size bytes, may return less.
    virtual std::expected<size_t, nc::Error> ReadAt(off_t _pos, void *_buf, size_t _size);

    enum {
        Seek_Set = 0,
        Seek_Cur = 1,
        Seek_End = 2
    };

    // Seek() is available if Read paradigm is Seek or above.
    virtual off_t Seek(off_t _off, int _basis);

    // Pos() should always be available, except of dummy VFSFile class, which returns VFSError::NotSupported.
    virtual ssize_t Pos() const;

    // Size() should always be available, except of dummy VFSFile class, which returns VFSError::NotSupported.
    virtual ssize_t Size() const;

    // Eof() should always be available, return true on not-valid file state.
    virtual bool Eof() const;

    // LastError() return last Error occured for this VFSFile.
    // Should be overwritten only when error occurs, normal workflow won't overwrite the last error code.
    std::optional<nc::Error> LastError() const;

    // XAttrCount() should be always available, returning 0 on non-supported case.
    // This function may cause blocking I/O.
    virtual unsigned XAttrCount() const;

    // Return true to allow further iteration, false to stop it.
    using XAttrIterateNamesCallback = std::function<bool(const char *_xattr_name)>;

    // XAttrIterateNames() will call block with every xattr name for this file while handler returns true.
    // This function may cause blocking I/O.
    virtual void XAttrIterateNames(const XAttrIterateNamesCallback &_handler) const;

    // XAttrGet copies an extended attribute value named _xattr_name into buffer _buffer limited with _buf_size.
    // If the requested xattr was not found this function returns VFSError::NotFound.
    // If _buffer is NULL and requested xattr was found then size of this xattr is returned.
    // If _buf_size is smaller than required buffer for _xattr_name then data will be truncated and _buf_size will be
    // returned. Generally this function returns amount of bytes copied (note that valid xattr value can be 0 bytes
    // long). This function may cause blocking I/O.
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const;

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

protected:
    // TODO: remove this
    // Sets a new last error code and returns it for convenience.
    int SetLastError(int _error) const;

    // Sets the new last error and returns it as an std::unexpected for convenience.
    std::unexpected<nc::Error> SetLastError(nc::Error _error) const;

    // Resets the last error of this file, if there was any
    void ClearLastError() const;

private:
    std::string m_RelativePath;
    std::shared_ptr<VFSHost> m_Host;

    // m_LastError should be set when any error occurs.
    // This storage is not per thread as with errno, but instead per file object.
    mutable std::optional<nc::Error> m_LastError;
};
