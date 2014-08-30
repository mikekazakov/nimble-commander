//
//  VFSNetSFTPFile.h
//  Files
//
//  Created by Michael G. Kazakov on 29/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSFile.h"
#import "VFSNetSFTPHost.h"

class VFSNetSFTPFile : public VFSFile
{
public:
    VFSNetSFTPFile(const char* _relative_path, shared_ptr<VFSNetSFTPHost> _host);
    ~VFSNetSFTPFile();
    
    virtual int Open(int _open_flags, bool (^_cancel_checker)()) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual WriteParadigm GetWriteParadigm() const override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t Write(const void *_buf, size_t _size) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;

private:
    unique_ptr<VFSNetSFTPHost::Connection> m_Connection;
    LIBSSH2_SFTP_HANDLE *m_Handle = nullptr;
    ssize_t m_Position = 0;
    ssize_t m_Size     = 0;    
};
