//
//  VFSArchiveFile.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSArchiveHost.h"
#import "VFSFile.h"

struct VFSArchiveMediator;
struct AppleDoubleEA;

class VFSArchiveFile : public VFSFile
{
public:
    VFSArchiveFile(const char* _relative_path, std::shared_ptr<VFSArchiveHost> _host);
    ~VFSArchiveFile();
    
    
    virtual int     Open(int _open_flags) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual unsigned XAttrCount() const override;
    virtual void XAttrIterateNames( bool (^_handler)(const char* _xattr_name) ) const override;
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const override;
private:
    AppleDoubleEA *m_EA;
    size_t         m_EACount;
    struct archive *m_Arc;
    struct archive_entry *m_Entry;
    std::shared_ptr<VFSFile> m_ArFile;
    std::shared_ptr<VFSArchiveMediator> m_Mediator;
    ssize_t m_Position;
    ssize_t m_Size;
    uint32_t m_UID;
    bool    m_ShouldCommitSC;
};
