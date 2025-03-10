// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSFile.h>
#include "InternalsForward.h"
#include "Internals.h"
#include <filesystem>

namespace nc::vfs::ftp {

class File final : public VFSFile
{
public:
    File(std::string_view _relative_path, std::shared_ptr<FTPHost> _host);
    ~File();

    //        OF_Truncate is implicitly added to VFSFile when OF_Append is not used - FTP specific
    std::expected<void, Error> Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool IsOpened() const override;
    std::expected<void, Error> Close() override;
    ReadParadigm GetReadParadigm() const override;
    WriteParadigm GetWriteParadigm() const override;
    std::expected<uint64_t, Error> Seek(off_t _off, int _basis) override;
    std::expected<size_t, Error> Read(void *_buf, size_t _size) override;
    std::expected<size_t, Error> Write(const void *_buf, size_t _size) override;
    std::expected<uint64_t, Error> Pos() const override;
    std::expected<uint64_t, Error> Size() const override;
    bool Eof() const override;

private:
    enum class Mode {
        Closed = 0,
        Read,
        Write
    };

    ssize_t ReadChunk(void *_read_to, uint64_t _read_size, uint64_t _file_offset, VFSCancelChecker _cancel_checker);

    std::filesystem::path DirName() const;
    void FinishWriting();
    void FinishReading();

    std::unique_ptr<CURLInstance> m_CURL;
    ReadBuffer m_ReadBuf;
    uint64_t m_BufFileOffset = 0; // offset of ReadBuf within the file
    WriteBuffer m_WriteBuf;
    Mode m_Mode = Mode::Closed;
    std::string m_URLRequest;
    uint64_t m_FileSize = 0;
    uint64_t m_FilePos = 0;
    constexpr static const struct timeval m_SelectTimeout = {0, 10000};
};

} // namespace nc::vfs::ftp
