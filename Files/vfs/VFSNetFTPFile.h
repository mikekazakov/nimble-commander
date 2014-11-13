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
    
//        OF_Truncate is implicitly added to VFSFile when OF_Append is not used - FTP specific
    virtual int Open(int _open_flags, VFSCancelChecker _cancel_checker) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;    
    virtual ReadParadigm GetReadParadigm() const override;
    virtual WriteParadigm GetWriteParadigm() const override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t Write(const void *_buf, size_t _size) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    
private:
    enum class Mode
    {
        Closed = 0,
        Read,
        Write
    };
    
    ssize_t ReadChunk(
                      void *_read_to,
                      uint64_t _read_size,
                      uint64_t _file_offset,
                      VFSCancelChecker _cancel_checker
                      );
    
    path DirName() const;
    void FinishWriting();
    void FinishReading();
    
    unique_ptr<VFSNetFTP::CURLInstance>  m_CURL;
    unique_ptr<VFSNetFTP::ReadBuffer>    m_ReadBuf;
    uint64_t                             m_BufFileOffset = 0;
    unique_ptr<VFSNetFTP::WriteBuffer>   m_WriteBuf;    
    Mode                                 m_Mode = Mode::Closed;
    string                               m_URLRequest;
    uint64_t                             m_FileSize = 0;
    uint64_t                             m_FilePos = 0;
    constexpr static const struct timeval m_SelectTimeout = {0, 10000};
};
