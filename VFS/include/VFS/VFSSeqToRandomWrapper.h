// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import "VFSFile.h"

class VFSSeqToRandomROWrapperFile : public VFSFile
{
public:
    VFSSeqToRandomROWrapperFile(const VFSFilePtr &_file_to_wrap);
    ~VFSSeqToRandomROWrapperFile();
    
    virtual int Open(unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;
    int Open(unsigned long _flags,
             const VFSCancelChecker &_cancel_checker,
             std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress);
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
    
    std::shared_ptr<VFSSeqToRandomROWrapperFile> Share();
    
private:
    struct Backend
    {
        ~Backend();
        int                         m_FD = -1;
        ssize_t                     m_Size = 0;
        std::unique_ptr<uint8_t[]>  m_DataBuf; // used only when filesize <= MaxCachedInMem
    };
    
    VFSSeqToRandomROWrapperFile(const char* _relative_path, const VFSHostPtr &_host, std::shared_ptr<Backend> _backend);
    int OpenBackend(unsigned long _flags,
                    VFSCancelChecker _cancel_checker,
                    std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress);
    
    
    std::shared_ptr<Backend>      m_Backend;
    ssize_t                  m_Pos = 0;
    VFSFilePtr               m_SeqFile;
};

using VFSSeqToRandomROWrapperFilePtr = std::shared_ptr<VFSSeqToRandomROWrapperFile>;
