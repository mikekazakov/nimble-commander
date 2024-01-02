// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Host.h"

namespace nc::vfs {
struct AppleDoubleEA;
}

namespace nc::vfs::arc {

class File final : public VFSFile
{
public:
    File(const char* _relative_path, const std::shared_ptr<ArchiveHost> &_host);
    ~File();
    
    
    virtual int     Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual unsigned XAttrCount() const override;
    virtual void XAttrIterateNames( const XAttrIterateNamesCallback &_handler ) const override;
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;
private:
    std::unique_ptr<State> m_State;
    std::vector<AppleDoubleEA> m_EA;
    ssize_t        m_Position;
    ssize_t        m_Size;
};

}
