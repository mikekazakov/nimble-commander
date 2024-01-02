// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <VFS/VFSFile.h>

namespace nc::vfs {
class NativeHost;
}

namespace nc::vfs::native {

class File : public VFSFile
{
public:
    File(const char* _relative_path, const std::shared_ptr<NativeHost> &_host);
    ~File();
    
    virtual int     Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    virtual ssize_t Write(const void *_buf, size_t _size) override;
    
    
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual WriteParadigm GetWriteParadigm() const override;
    
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual unsigned XAttrCount() const override;
    virtual void XAttrIterateNames( const XAttrIterateNamesCallback &_handler ) const override;
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;
    
    
    
    virtual std::shared_ptr<VFSFile> Clone() const override;
private:
    int     m_FD;
    unsigned long m_OpenFlags;
    ssize_t m_Position;
    ssize_t m_Size;
};

}
