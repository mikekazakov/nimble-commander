// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSFile.h>
#include <libssh2_sftp.h>
#include "SFTPHost.h"

namespace nc::vfs::sftp {

class File : public VFSFile
{
public:
    File(std::string_view _relative_path, std::shared_ptr<SFTPHost> _host);
    ~File();

    int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool IsOpened() const override;
    int Close() override;
    ReadParadigm GetReadParadigm() const override;
    WriteParadigm GetWriteParadigm() const override;
    std::expected<uint64_t, Error> Seek(off_t _off, int _basis) override;
    std::expected<size_t, Error> Read(void *_buf, size_t _size) override;
    ssize_t Write(const void *_buf, size_t _size) override;
    std::expected<uint64_t, Error> Pos() const override;
    ssize_t Size() const override;
    bool Eof() const override;

private:
    std::unique_ptr<SFTPHost::Connection> m_Connection;
    LIBSSH2_SFTP_HANDLE *m_Handle = nullptr;
    ssize_t m_Position = 0;
    ssize_t m_Size = 0;
};

} // namespace nc::vfs::sftp
