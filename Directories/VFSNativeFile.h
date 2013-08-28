//
//  VFSNativeFile.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "VFSFile.h"

class VFSNativeHost;

class VFSNativeFile : public VFSFile
{
public:
    VFSNativeFile(const char* _relative_path, std::shared_ptr<VFSNativeHost> _host);
    ~VFSNativeFile();
    
    virtual int     Open(int _open_flags) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ReadParadigm GetReadParadigm() const override;
    
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    
    virtual std::shared_ptr<VFSFile> Clone() const override;
private:
    int     m_FD;
    ssize_t m_Position;
    ssize_t m_Size;
};
