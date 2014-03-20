//
//  VFSNetFTPFile.h
//  Files
//
//  Created by Michael G. Kazakov on 19.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSFile.h"
#import "VFSNetFTPInternalsForward.h"

class VFSNetFTPFile : public VFSFile
{
public:
    VFSNetFTPFile(const char* _relative_path,
                  shared_ptr<VFSNetFTPHost> _host);
    ~VFSNetFTPFile();
    
    virtual int Open(int _open_flags, bool (^_cancel_checker)()) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;    
    virtual ReadParadigm GetReadParadigm() const override;
    virtual ssize_t Read(void *_buf, size_t _size) override;    
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    
    
    
private:
    
    ssize_t ReadChunk(
                      void *_read_to,
                      uint64_t _read_size,
                      uint64_t _file_offset,
                      bool (^_cancel_checker)()
                      );
    
    unique_ptr<VFSNetFTP::CURLInstance>  m_CURL;
    unique_ptr<VFSNetFTP::CURLMInstance> m_CURLM;
    unique_ptr<VFSNetFTP::Buffer>        m_Buf;
//    bool                                 m_IOAttached = false;
    bool                                 m_IsOpened = false;
    string                               m_URLRequest;
    uint64_t                             m_FileSize = 0;
    uint64_t                             m_FilePos = 0;
};
