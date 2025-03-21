// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFSFile.h"

#include <string_view>

namespace nc::vfs {

class GenericMemReadOnlyFile : public VFSFile
{
public:
    GenericMemReadOnlyFile(std::string_view _relative_path,
                           const std::shared_ptr<VFSHost> &_host,
                           const void *_memory,
                           uint64_t _mem_size);
    GenericMemReadOnlyFile(std::string_view _relative_path,
                           const std::shared_ptr<VFSHost> &_host,
                           std::string_view _memory);

    std::expected<void, Error> Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker = {}) override;
    bool IsOpened() const override;
    std::expected<void, Error> Close() override;
    std::shared_ptr<VFSFile> Clone() const override;

    std::expected<size_t, Error> Read(void *_buf, size_t _size) override;
    std::expected<size_t, Error> ReadAt(off_t _pos, void *_buf, size_t _size) override;
    ReadParadigm GetReadParadigm() const override;
    std::expected<uint64_t, Error> Seek(off_t _off, int _basis) override;
    std::expected<uint64_t, Error> Pos() const override;
    std::expected<uint64_t, Error> Size() const override;
    bool Eof() const override;

private:
    const void *const m_Mem;
    const uint64_t m_Size;
    ssize_t m_Pos = 0;
    bool m_Opened = false;
};

} // namespace nc::vfs
