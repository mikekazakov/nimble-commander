// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Host.h"

namespace nc::vfs {
struct AppleDoubleEA;
}

namespace nc::vfs::arc {

class File final : public VFSFile
{
public:
    File(std::string_view _relative_path, const std::shared_ptr<ArchiveHost> &_host);
    ~File();

    std::expected<void, Error> Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool IsOpened() const override;
    int Close() override;
    std::expected<size_t, Error> Read(void *_buf, size_t _size) override;
    ReadParadigm GetReadParadigm() const override;
    std::expected<uint64_t, Error> Pos() const override;
    std::expected<uint64_t, Error> Size() const override;
    bool Eof() const override;
    unsigned XAttrCount() const override;
    void XAttrIterateNames(const XAttrIterateNamesCallback &_handler) const override;
    ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;

private:
    std::unique_ptr<State> m_State;
    std::vector<AppleDoubleEA> m_EA;
    ssize_t m_Position;
    ssize_t m_Size;
};

} // namespace nc::vfs::arc
