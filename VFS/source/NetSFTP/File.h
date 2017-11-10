// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSFile.h>
#include <libssh2_sftp.h>
#include "SFTPHost.h"

namespace nc::vfs::sftp {

class File : public VFSFile
{
public:
    File(const char* _relative_path, shared_ptr<SFTPHost> _host);
    ~File();
    
    virtual int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
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
    unique_ptr<SFTPHost::Connection> m_Connection;
    LIBSSH2_SFTP_HANDLE *m_Handle = nullptr;
    ssize_t m_Position = 0;
    ssize_t m_Size     = 0;    
};

}
