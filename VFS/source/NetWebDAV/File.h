// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "WebDAVHost.h"
#include <VFS/VFSFile.h>
#include "ReadBuffer.h"
#include "WriteBuffer.h"
#include "ConnectionsPool.h"

namespace nc::vfs::webdav {

class File final : public VFSFile
{
public:
    File(const char* _relative_path, const std::shared_ptr<WebDAVHost> &_host);
    ~File();

    int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool    IsOpened() const override;
    int     Close() override;
    ssize_t Pos() const override;
    ssize_t Size() const override;
    bool Eof() const override;
    ssize_t Read(void *_buf, size_t _size) override;
    ssize_t Write(const void *_buf, size_t _size) override;
    int SetUploadSize(size_t _size) override;
    ReadParadigm  GetReadParadigm() const override;
    WriteParadigm GetWriteParadigm() const override;


private:
    void SpawnDownloadConnectionIfNeeded();
    void SpawnUploadConnectionIfNeeded();

    WebDAVHost &m_Host;
    ReadBuffer  m_ReadBuffer;
    WriteBuffer m_WriteBuffer;
    std::unique_ptr<Connection> m_Conn;
    unsigned long m_OpenFlags = 0;
    long        m_Pos = 0;
    long        m_Size = -1;
};

}
