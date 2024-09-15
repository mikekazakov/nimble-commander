// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <vector>
#include <stdint.h>
#include "VFSError.h"
#include "VFSDeclarations.h"

#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

class VFSFile : public std::enable_shared_from_this<VFSFile>
{
public:
    enum class ReadParadigm {
        /**
         * the best possible variant - can read a block of data from a random offset. Seeking is also possible
         */
        Random = 3,

        /**
         * classic I/O - can seek and sequentially read requested data
         */
        Seek = 2,

        /**
         * the worst variant - can only read file sequentially from the beginning
         * (http downloading without resuming for example)
         * should also support Skip operation, which can be not cheap
         */
        Sequential = 1,

        /**
         * this file cannot be read
         */
        NoRead = 0
    };

    enum class WriteParadigm {
        Random = 4,
        Seek = 3,
        Sequential = 2,
        Upload = 1,
        NoWrite = 0
    };

    VFSFile(std::string_view _relative_path, const VFSHostPtr &_host);
    virtual ~VFSFile();

    virtual int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker = nullptr);
    virtual bool IsOpened() const;
    virtual int Close();

    /**
     * Negative value means that vfs doesn't provide such information.
     */
    virtual int PreferredIOSize() const;

    /**
     * Return available read paradigm. Should return some considerable value even on non-opened files.
     */
    virtual ReadParadigm GetReadParadigm() const;
    virtual WriteParadigm GetWriteParadigm() const;
    virtual ssize_t Read(void *_buf, size_t _size);

    /**
     * For Upload write paradigm: sets upload size in advance, to file object can set up it's data structures and
     * do an actual upload on Write() call when client hits stated size.
     * May be ignored by other write paradigms.
     * If _size is zero - file may perform an actual upload.
     * Default implementation returns Ok.
     */
    virtual int SetUploadSize(size_t _size);

    /**
     * Writes _size bytes from _buf to a file in blocking mode.
     * Returnes amount of bytes written or negative value for errors.
     */
    virtual ssize_t Write(const void *_buf, size_t _size);

    virtual ssize_t Skip(size_t _size);

    /**
     * ReadAt is available only on Random level.
     * It will not move any file pointers.
     * Reads up to _size bytes, may return less.
     */
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size);

    enum {
        Seek_Set = 0,
        Seek_Cur = 1,
        Seek_End = 2
    };

    /**
     * Seek() is available if Read paradigm is Seek or above.
     */
    virtual off_t Seek(off_t _off, int _basis);

    /**
     * Pos() should always be available, except of dummy VFSFile class, which returns VFSError::NotSupported.
     */
    virtual ssize_t Pos() const;

    /**
     * Size() should always be available, except of dummy VFSFile class, which returns VFSError::NotSupported.
     */
    virtual ssize_t Size() const;

    /**
     * Eof() should always be available, return true on not-valid file state.
     */
    virtual bool Eof() const;

    /**
     * LastError() return last VFSError occured for this VFSFile.
     * Should be overwritten only when error occurs,
     * normal workflow won't overwrite the last error code.
     */
    int LastError() const;

    /**
     * XAttrCount() should be always available, returning 0 on non-supported case.
     * This function may cause blocking I/O.
     */
    virtual unsigned XAttrCount() const;

    /**
     * return true to allow further iteration, false to stop it.
     */
    using XAttrIterateNamesCallback = std::function<bool(const char *_xattr_name)>;

    /**
     * XAttrIterateNames() will call block with every xattr name for this file while handler returns true.
     * This function may cause blocking I/O.
     *
     */
    virtual void XAttrIterateNames(const XAttrIterateNamesCallback &_handler) const;

    /**
     * XAttrGet copies an extended attribute value named _xattr_name into buffer _buffer limited with _buf_size.
     * If requested xattr was not found this function returns VFSError::NotFound.
     * If _buffer is NULL and requested xattr was found then size of this xattr is returned.
     * If _buf_size is smaller than required buffer for _xattr_name then data will be truncated and _buf_size will be
     * returned. Generally this function returns amount of bytes copied (note that valid xattr value can be 0 bytes
     * long). This function may cause blocking I/O
     */
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const;

    /**
     * Clone() returns an object of same type with same parent host and relative path
     * Open status and file positions are not shared
     * Can return null pointer in some cases
     */
    virtual std::shared_ptr<VFSFile> Clone() const;

    /**
     * ComposeVerbosePath() relies solely on Host() and VerboseJunctionPath()
     */
    std::string ComposeVerbosePath() const;

    /**
     * ReadFile() return full file content in vector<uint8_t> or nullptr.
     */
    std::optional<std::vector<uint8_t>> ReadFile();

    /**
     * Will call Write until data ends or an error occurs.
     * Returns VFSError::Ok on success or error code on failure.
     */
    int WriteFile(const void *_d, size_t _sz);

    // sugar wrappers for Cocoa APIs
#ifdef __OBJC__
    /**
     * ReadFileToNSData() return full file content in NSData object or nil.
     */
    NSData *ReadFileToNSData();
#endif

    std::shared_ptr<VFSFile> SharedPtr();
    std::shared_ptr<const VFSFile> SharedPtr() const;
    const char *Path() const noexcept;
    const std::shared_ptr<VFSHost> &Host() const;

protected:
    /**
     * Sets a new last error code and returns it for convenience.
     */
    int SetLastError(int _error) const;

private:
    std::string m_RelativePath;
    std::shared_ptr<VFSHost> m_Host;

    /**
     * m_LastError should be set when any error occurs.
     * This storage is not per-thread - concurrent accesses may overwrite it.
     */
    mutable std::atomic_int m_LastError;

    // forbid copying
    VFSFile(const VFSFile &) = delete;
    void operator=(const VFSFile &) = delete;
};

#ifdef __OBJC__
inline NSData *VFSFile::ReadFileToNSData()
{
    auto d = ReadFile();
    return d ? [NSData dataWithBytes:d->data() length:d->size()] : nil;
}
#endif
