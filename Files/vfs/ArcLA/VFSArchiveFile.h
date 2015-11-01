//
//  VFSArchiveFile.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "VFSArchiveHost.h"

struct AppleDoubleEA;

class VFSArchiveFile : public VFSFile
{
public:
    VFSArchiveFile(const char* _relative_path, shared_ptr<VFSArchiveHost> _host);
    ~VFSArchiveFile();
    
    
    virtual int     Open(int _open_flags, VFSCancelChecker _cancel_checker) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual unsigned XAttrCount() const override;
    virtual void XAttrIterateNames( function<bool(const char* _xattr_name)> _handler ) const override;
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;
private:
    unique_ptr<VFSArchiveState> m_State;
    vector<AppleDoubleEA> m_EA;
    ssize_t        m_Position;
    ssize_t        m_Size;
};
