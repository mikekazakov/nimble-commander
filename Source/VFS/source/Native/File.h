// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <VFS/VFSFile.h>

namespace nc::vfs {
class NativeHost;
}

namespace nc::vfs::native {

class File : public VFSFile
{
public:
    File(std::string_view _relative_path, const std::shared_ptr<NativeHost> &_host);
    ~File();

    int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool IsOpened() const override;
    int Close() override;
    std::expected<size_t, Error> Read(void *_buf, size_t _size) override;
    std::expected<size_t, Error> ReadAt(off_t _pos, void *_buf, size_t _size) override;
    ssize_t Write(const void *_buf, size_t _size) override;

    off_t Seek(off_t _off, int _basis) override;
    ReadParadigm GetReadParadigm() const override;
    WriteParadigm GetWriteParadigm() const override;

    ssize_t Pos() const override;
    ssize_t Size() const override;
    bool Eof() const override;
    unsigned XAttrCount() const override;
    void XAttrIterateNames(const XAttrIterateNamesCallback &_handler) const override;
    ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;

    std::shared_ptr<VFSFile> Clone() const override;

private:
    int m_FD;
    unsigned long m_OpenFlags;
    ssize_t m_Position;
    ssize_t m_Size;
};

} // namespace nc::vfs::native
