//
//  VFSFile.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <memory>
#import "VFSError.h"

using namespace std;

class VFSHost;

class VFSFile : public enable_shared_from_this<VFSFile>
{
public:
    enum class ReadParadigm {
        /**
         * the best possible variant - can read a block of data from a random offset. Seeking is also possible
         */
        Random      = 3,

        /**
         * classic I/O - can seek and sequentially read requested data
         */
        Seek        = 2,
        
        /**
         * the worst variant - can only read file sequentially from the beginning
         * (http downloading without resuming for example)
         * should also support Skip operation, which can be not cheap
         */
        Sequential  = 1,

        /**
         * this file cannot be read
         */
        NoRead      = 0
    };
    
    enum class WriteParadigm {
        Random      = 3,
        Seek        = 2,
        Sequential  = 1,
        NoWrite     = 0
    };
    
    VFSFile(const char* _relative_path, shared_ptr<VFSHost> _host);
    virtual ~VFSFile();

    enum {
        OF_Read     = 0b00000001,
        OF_Write    = 0b00000010,
        OF_Create   = 0b00000100,
        OF_NoExist  = 0b00001000, // POSIX O_EXCL actucally, for clarity
        OF_ShLock   = 0b00010000, // not yet implemented
        OF_ExLock   = 0b00100000, // not yet implemented
        OF_NoCache  = 0b01000000  // turns off caching if supported
    };
    virtual int     Open(int _open_flags,
                         bool (^_cancel_checker)() = 0);
    virtual bool    IsOpened() const;
    virtual int     Close();

    /**
     * Return available read paradigm. Should return some considerable value even on non-opened files.
     */
    virtual ReadParadigm  GetReadParadigm() const;
    virtual WriteParadigm GetWriteParadigm() const;
    virtual ssize_t Read(void *_buf, size_t _size);
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
     * LastError() return last VFSError occured for this VFSFile. Overwritten only on error occurs, normal workflow won't overwrite last error code.
     */
    int LastError() const;
    
    /**
     * XAttrCount() should be always available, returning 0 on non-supported case.
     * This function may cause blocking I/O.
     */
    virtual unsigned XAttrCount() const;
    
    /**
     * XAttrIterateNames() will call block with every xattr name for this file while handler returns true.
     * This function may cause blocking I/O.
     */
    virtual void XAttrIterateNames(
                                   bool (^_handler)(const char* _xattr_name) // return true for allowing iteration, false to stop it
                                   ) const;
    
    /**
     * XAttrGet copies an extended attribute value named _xattr_name into buffer _buffer limited with _buf_size.
     * If requested xattr was not found this function returns VFSError::NotFound.
     * If _buffer is NULL and requested xattr was found then size of this xattr is returned.
     * If _buf_size is smaller than required buffer for _xattr_name then data will be truncated and _buf_size will be returned.
     * Generally this function returns amount of bytes copied (note that valid xattr value can be 0 bytes long).
     * This function may cause blocking I/O     
     */
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const;
    
    /**
     * Clone() returns an object of same type with same parent host and relative path
     * Open status and file positions are not shared
     * Can return null pointer in some cases
     */
    virtual shared_ptr<VFSFile> Clone() const;

    /**
     * ComposeFullHostsPath() relies solely on RelativePath() and Host()
     */
    void ComposeFullHostsPath(char *_buf) const;
    
    // sugar wrappers for Cocoa APIs
#ifdef __OBJC__
    /**
     * ReadFile() return full file content in NSData object or nil
     */
    NSData *ReadFile();
#endif
    
    inline shared_ptr<VFSFile> SharedPtr() { return shared_from_this(); }
    inline shared_ptr<const VFSFile> SharedPtr() const { return shared_from_this(); }
    const char* RelativePath() const;
    shared_ptr<VFSHost> Host() const;
protected:
    /**
     * Sets a new last error code and returns it for convenience.
     */
    int SetLastError(int _error) const;
    
private:
    string m_RelativePath;
    shared_ptr<VFSHost> m_Host;

    /**
     * m_LastError should be set when any error occurs. This storage is not thread-safe - concurrent accesses may overwrite it.
     */
    mutable int m_LastError;
    
    // forbid copying
    VFSFile(const VFSFile&) = delete;
    void operator=(const VFSFile&) = delete;
};

inline int VFSFile::SetLastError(int _error) const
{
    return m_LastError = _error;
}

inline int VFSFile::LastError() const
{
    return m_LastError;
}
