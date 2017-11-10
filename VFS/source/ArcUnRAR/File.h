// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSFile.h>

namespace nc::vfs {
class UnRARHost;
}

namespace nc::vfs::unrar {

struct SeekCache;
struct Entry;

// concurrent acces to VFSArchiveUnRARFile via Read may cause a lot of problems,
// it's designed to be best used with sta access.
class File final : public VFSFile
{
public:
    File(const char* _relative_path, shared_ptr<UnRARHost> _host);
    ~File();
    
    virtual int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;

    virtual ssize_t Read(void *_buf, size_t _size) override;    
    virtual ReadParadigm GetReadParadigm() const override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    
private:
    static int ProcessRAR(unsigned int _msg, long _user_data, long _p1, long _p2);
    static int ProcessRARDummy(unsigned int _msg, long _user_data, long _p1, long _p2);
    
    unique_ptr<SeekCache>    m_Archive;
    unique_ptr<uint8_t[]>                   m_UnpackBuffer;
    unsigned                                m_UnpackBufferSize = 0;
    static const unsigned                   m_UnpackBufferDefaultCapacity = 256*1024;
    unsigned                                m_UnpackBufferCapacity = 0;
    
    const Entry                 *m_Entry = 0;
    ssize_t                     m_Position = 0;
    ssize_t                     m_TotalExtracted = 0;
    dispatch_queue_t            m_UnpackThread = 0;
    dispatch_semaphore_t        m_UnpackSemaphore = 0;
    dispatch_semaphore_t        m_ConsumeSemaphore = 0;
    dispatch_semaphore_t        m_FinishUnpackSemaphore = 0;
    int                         m_RarError = 0;
    bool                        m_ExtractionRunning = false;
    bool                        m_ExitUnpacking = false;
};

}
