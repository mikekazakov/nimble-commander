//
//  VFSSeqToSeekWrapper.h
//  Files
//
//  Created by Michael G. Kazakov on 28.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <stdint.h>
#import "VFSFile.h"

class VFSSeqToRandomROWrapperFile : public VFSFile
{
public:
    VFSSeqToRandomROWrapperFile(shared_ptr<VFSFile> _file_to_wrap);
    ~VFSSeqToRandomROWrapperFile();
    
    virtual int Open(int _flags) override;
    virtual int Close() override;
    
    enum {
        MaxCachedInMem = 16*1024*1024    
    };
    
    virtual bool    IsOpened() const override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ReadParadigm GetReadParadigm() const override;
    
private:
    int                      m_FD;
    ssize_t                  m_Pos;
    ssize_t                  m_Size;
    shared_ptr<VFSFile> m_SeqFile;
    unique_ptr<uint8_t[]>    m_DataBuf; // used only when filesize <= MaxCachedInMem
    bool                     m_Ready;
};
