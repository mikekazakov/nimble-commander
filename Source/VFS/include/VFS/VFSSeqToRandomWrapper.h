// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import "VFSFile.h"

class VFSSeqToRandomROWrapperFile : public VFSFile
{
public:
    VFSSeqToRandomROWrapperFile(const VFSFilePtr &_file_to_wrap);
    ~VFSSeqToRandomROWrapperFile();

    std::expected<void, nc::Error> Open(unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, nc::Error> Open(unsigned long _flags,
                                        const VFSCancelChecker &_cancel_checker,
                                        std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress);

    std::expected<void, nc::Error> Close() override;

    enum {
        MaxCachedInMem = 16 * 1024 * 1024
    };

    bool IsOpened() const override;

    std::expected<uint64_t, nc::Error> Pos() const override;

    std::expected<uint64_t, nc::Error> Size() const override;

    bool Eof() const override;

    std::expected<size_t, nc::Error> Read(void *_buf, size_t _size) override;

    std::expected<size_t, nc::Error> ReadAt(off_t _pos, void *_buf, size_t _size) override;

    std::expected<uint64_t, nc::Error> Seek(off_t _off, int _basis) override;

    ReadParadigm GetReadParadigm() const override;

    std::shared_ptr<VFSSeqToRandomROWrapperFile> Share();

private:
    struct Backend {
        ~Backend();
        int m_FD = -1;
        ssize_t m_Size = 0;
        std::unique_ptr<uint8_t[]> m_DataBuf; // used only when filesize <= MaxCachedInMem
    };

    VFSSeqToRandomROWrapperFile(const char *_relative_path, const VFSHostPtr &_host, std::shared_ptr<Backend> _backend);
    std::expected<void, nc::Error>
    OpenBackend(unsigned long _flags,
                VFSCancelChecker _cancel_checker,
                std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress);

    std::shared_ptr<Backend> m_Backend;
    ssize_t m_Pos = 0;
    VFSFilePtr m_SeqFile;
};

using VFSSeqToRandomROWrapperFilePtr = std::shared_ptr<VFSSeqToRandomROWrapperFile>;
