// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/algo.h>
#include <Habanero/CommonPaths.h>
#include <Utility/SystemInformation.h>
#include "../include/VFS/VFSSeqToRandomWrapper.h"
#include "../include/VFS/VFSError.h"
#include <stdio.h>
#include <unistd.h>
#include <limits.h>
#include <stddef.h>
#include <sys/param.h>
#include <sys/fcntl.h>
#include <errno.h>

VFSSeqToRandomROWrapperFile::Backend::~Backend()
{
    if( m_FD >= 0 )
        close( m_FD );
}

VFSSeqToRandomROWrapperFile::VFSSeqToRandomROWrapperFile(const VFSFilePtr &_file_to_wrap):
    VFSFile(_file_to_wrap->Path(), _file_to_wrap->Host()),
    m_SeqFile(_file_to_wrap)
{
}

VFSSeqToRandomROWrapperFile::VFSSeqToRandomROWrapperFile(const char* _relative_path,
                                                         const VFSHostPtr &_host,
                                                         std::shared_ptr<Backend> _backend):
    VFSFile(_relative_path, _host),
    m_Backend(_backend)
{
}

VFSSeqToRandomROWrapperFile::~VFSSeqToRandomROWrapperFile()
{
    Close();
}

int VFSSeqToRandomROWrapperFile::Open(unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker,
                                      std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    int ret = OpenBackend(_flags, _cancel_checker, _progress);
    return ret;
}

int VFSSeqToRandomROWrapperFile::OpenBackend(unsigned long _flags,
                                             VFSCancelChecker _cancel_checker,
                                             std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    auto ggg = at_scope_end( [=]{ m_SeqFile.reset(); } ); // ony any result wrapper won't hold any reference to VFSFile after this function ends
    if( !m_SeqFile )
        return VFSError::InvalidCall;
    if( m_SeqFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential )
        return VFSError::InvalidCall;
    
    if( !m_SeqFile->IsOpened() ) {
        int res = m_SeqFile->Open(_flags);
        if(res < 0)
            return res;
    }
    else if( m_SeqFile->Pos() > 0 )
        return VFSError::InvalidCall;
    
    
    auto backend = std::make_shared<Backend>();
    m_Pos = 0;
    
    if( m_SeqFile->Size() <= MaxCachedInMem ) {
        // we just read a whole file into a memory buffer
        
        backend->m_Size = m_SeqFile->Size();
        backend->m_DataBuf = std::make_unique<uint8_t[]>(backend->m_Size);
        
        const size_t max_io = 256*1024;
        uint8_t *d = &backend->m_DataBuf[0];
        uint8_t *e = d + backend->m_Size;
        ssize_t res;
        while( d < e && ( res = m_SeqFile->Read(d, std::min(e-d, (long)max_io)) ) > 0) {
            d += res;

            if(_cancel_checker && _cancel_checker())
                return VFSError::Cancelled;

            if(_progress)
                _progress(d - &backend->m_DataBuf[0], backend->m_Size);
        }
        
        if( _cancel_checker && _cancel_checker() )
            return VFSError::Cancelled;
        
        if( res < 0 )
            return (int)res;
        
        if( res == 0 && d != e )
            return VFSError::UnexpectedEOF;
    }
    else {
        // we need to write it into a temp dir and delete it upon finish
        char pattern_buf[MAXPATHLEN];
        sprintf(pattern_buf, ("%s" + nc::utility::GetBundleID() + ".vfs.XXXXXX").c_str(),
                CommonPaths::AppTemporaryDirectory().c_str());
        
        int fd = mkstemp(pattern_buf);
        
        if(fd < 0)
            return VFSError::FromErrno(errno);

        unlink(pattern_buf); // preemtive unlink - OS will remove inode upon last descriptor closing
        
        fcntl(fd, F_NOCACHE, 1); // don't need to cache this temporaral stuff
        
        backend->m_FD = fd;
        backend->m_Size = m_SeqFile->Size();
        
        size_t bufsz = 256*1024;

        char buf[bufsz];
        uint64_t left_read = backend->m_Size;
        ssize_t res_read;
        ssize_t total_wrote = 0 ;
        
        while ( (res_read = m_SeqFile->Read(buf, MIN(bufsz, left_read))) > 0 ) {
            if(_cancel_checker && _cancel_checker())
                return VFSError::Cancelled;
            
            ssize_t res_write;
            while(res_read > 0) {
                res_write = write(backend->m_FD, buf, res_read);
                if(res_write >= 0) {
                    res_read -= res_write;
                    total_wrote += res_write;
                    
                    if(_progress)
                        _progress(total_wrote, backend->m_Size);
                }
                else
                    return VFSError::FromErrno(errno);
            }
        }
        
        if( res_read < 0 )
            return (int)res_read;
        
        if( res_read == 0 && total_wrote != backend->m_Size )
            return VFSError::UnexpectedEOF;
        
    }
    
    m_Backend = backend;
    return VFSError::Ok;
}

int VFSSeqToRandomROWrapperFile::Open(unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    return Open(_flags, _cancel_checker, nullptr);
}

int VFSSeqToRandomROWrapperFile::Close()
{
    m_SeqFile.reset();
    m_Backend.reset();
//    m_DataBuf.reset();
//    if(m_FD >= 0) {
//        close(m_FD);
//        m_FD = -1;
//    }
//    m_Ready = false;
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSSeqToRandomROWrapperFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t VFSSeqToRandomROWrapperFile::Pos() const
{
    if( !IsOpened() )
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t VFSSeqToRandomROWrapperFile::Size() const
{
    if( !IsOpened() )
        return VFSError::InvalidCall;
    return m_Backend->m_Size;
}

bool VFSSeqToRandomROWrapperFile::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Pos == m_Backend->m_Size;
}

bool VFSSeqToRandomROWrapperFile::IsOpened() const
{
    return (bool)m_Backend;
}

ssize_t VFSSeqToRandomROWrapperFile::Read(void *_buf, size_t _size)
{
    ssize_t result = ReadAt(m_Pos, _buf, _size);
    if( result >= 0 )
        m_Pos += result;
    return result;
}

ssize_t VFSSeqToRandomROWrapperFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if( !IsOpened() )
        return VFSError::InvalidCall;

    if( _pos < 0 || _pos > m_Backend->m_Size )
        return VFSError::InvalidCall;
    
    if( m_Backend->m_DataBuf ) {
        ssize_t toread = std::min(m_Backend->m_Size - _pos, (off_t)_size);
        memcpy(_buf, &m_Backend->m_DataBuf[_pos], toread);
        return toread;
    }
    else if( m_Backend->m_FD >= 0 ) {
        ssize_t toread = std::min(m_Backend->m_Size - _pos, (off_t)_size);
        ssize_t res = pread(m_Backend->m_FD, _buf, toread, _pos);
        if(res >= 0)
            return res;
        else
            return VFSError::FromErrno(errno);
    }
    assert(0);
}

off_t VFSSeqToRandomROWrapperFile::Seek(off_t _off, int _basis)
{
    if( !IsOpened() )
        return VFSError::InvalidCall;
    
    // we can only deal with cache buffer now, need another branch later
    off_t req_pos = 0;
    if(_basis == VFSFile::Seek_Set)
        req_pos = _off;
    else if(_basis == VFSFile::Seek_End)
        req_pos = m_Backend->m_Size + _off;
    else if(_basis == VFSFile::Seek_Cur)
        req_pos = m_Pos + _off;
    else
        return VFSError::InvalidCall;
    
    if(req_pos < 0)
        return VFSError::InvalidCall;
    if(req_pos > m_Backend->m_Size)
        req_pos = m_Backend->m_Size;
    m_Pos = req_pos;
    
    return m_Pos;
}

std::shared_ptr<VFSSeqToRandomROWrapperFile> VFSSeqToRandomROWrapperFile::Share()
{
    if( !IsOpened() )
        return nullptr;
    return std::shared_ptr<VFSSeqToRandomROWrapperFile>(new VFSSeqToRandomROWrapperFile(Path(), Host(), m_Backend));
}
