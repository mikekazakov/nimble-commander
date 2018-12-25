// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFSFile.h"

#include <string_view>

namespace nc::vfs {

class GenericMemReadOnlyFile : public VFSFile
{
public:
    GenericMemReadOnlyFile(const char* _relative_path,
                           const std::shared_ptr<VFSHost> &_host,
                           const void *_memory,
                           uint64_t _mem_size);
    GenericMemReadOnlyFile(const char* _relative_path,
                           const std::shared_ptr<VFSHost> &_host,
                           std::string_view _memory);    
    
    virtual int     Open(unsigned long _open_flags,
                         const VFSCancelChecker &_cancel_checker = {}) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;

private:
    const void * const  m_Mem;
    const uint64_t      m_Size;
    ssize_t             m_Pos = 0;
    bool                m_Opened = false;
};

}
