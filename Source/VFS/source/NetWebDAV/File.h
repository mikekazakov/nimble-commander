// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "WebDAVHost.h"
#include <VFS/VFSFile.h>
#include "ReadBuffer.h"
#include "WriteBuffer.h"
#include "Connection.h"

namespace nc::vfs::webdav {

class File final : public VFSFile
{
public:
    File(std::string_view _relative_path, const std::shared_ptr<WebDAVHost> &_host);
    ~File();

    std::expected<void, Error> Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool IsOpened() const override;
    int Close() override;
    std::expected<uint64_t, Error> Pos() const override;
    std::expected<uint64_t, Error> Size() const override;
    bool Eof() const override;
    std::expected<size_t, Error> Read(void *_buf, size_t _size) override;
    std::expected<size_t, Error> Write(const void *_buf, size_t _size) override;
    std::expected<void, Error> SetUploadSize(size_t _size) override;
    ReadParadigm GetReadParadigm() const override;
    WriteParadigm GetWriteParadigm() const override;

private:
    void SpawnDownloadConnectionIfNeeded();
    void SpawnUploadConnectionIfNeeded();

    WebDAVHost &m_Host;
    std::unique_ptr<Connection> m_Conn;
    unsigned long m_OpenFlags = 0;
    long m_Pos = 0;
    long m_Size = -1;
};

} // namespace nc::vfs::webdav
