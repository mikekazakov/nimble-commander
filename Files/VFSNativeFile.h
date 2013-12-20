//
//  VFSNativeFile.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "VFSFile.h"

class VFSNativeHost;

class VFSNativeFile : public VFSFile
{
public:
    VFSNativeFile(const char* _relative_path, shared_ptr<VFSNativeHost> _host);
    ~VFSNativeFile();
    
    virtual int     Open(int _open_flags) override;
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
    virtual void XAttrIterateNames( bool (^_handler)(const char* _xattr_name) ) const override;
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;
    
    
    
    virtual shared_ptr<VFSFile> Clone() const override;
private:
    int     m_FD;
    int     m_OpenFlags;
    ssize_t m_Position;
    ssize_t m_Size;
};
