// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSFile.h"
#include "../include/VFS/VFSError.h"
#include "../include/VFS/Host.h"

VFSFile::VFSFile(const char* _relative_path, const VFSHostPtr &_host):
    m_RelativePath(_relative_path ? _relative_path : ""),
    m_Host(_host),
    m_LastError(VFSError::Ok)
{
}

VFSFile::~VFSFile()
{
}

shared_ptr<VFSFile> VFSFile::SharedPtr()
{
    return shared_from_this();
}

shared_ptr<const VFSFile> VFSFile::SharedPtr() const
{
    return shared_from_this();
}

const char* VFSFile::Path() const noexcept
{
    return m_RelativePath.c_str();
}

const shared_ptr<VFSHost> &VFSFile::Host() const
{
    return m_Host;
}

VFSFile::ReadParadigm VFSFile::GetReadParadigm() const
{
    return ReadParadigm::NoRead;
}

VFSFile::WriteParadigm VFSFile::GetWriteParadigm() const
{
    return WriteParadigm::NoWrite;
}

ssize_t VFSFile::Read(void *_buf, size_t _size)
{
    return SetLastError(VFSError::NotSupported);
}

ssize_t VFSFile::Write(const void *_buf, size_t _size)
{
    return SetLastError(VFSError::NotSupported);
}

ssize_t VFSFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    return SetLastError(VFSError::NotSupported);
}

bool VFSFile::IsOpened() const
{
    return false;
}

int     VFSFile::Open(unsigned long, const VFSCancelChecker&){ return SetLastError(VFSError::NotSupported); }
int     VFSFile::Close()             { return SetLastError(VFSError::NotSupported); }
off_t   VFSFile::Seek(off_t, int)    { return SetLastError(VFSError::NotSupported); }
ssize_t VFSFile::Pos() const         { return SetLastError(VFSError::NotSupported); }
ssize_t VFSFile::Size() const        { return SetLastError(VFSError::NotSupported); }
bool    VFSFile::Eof() const         { return true; }
shared_ptr<VFSFile> VFSFile::Clone() const { return 0; }

string VFSFile::ComposeVerbosePath() const
{
    array<VFSHost*, 32> hosts;
    int hosts_n = 0;

    VFSHost *cur = m_Host.get();
    while(cur)
    {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    string s;
    while(hosts_n > 0)
        s += hosts[--hosts_n]->Configuration().VerboseJunction();
    s += m_RelativePath;
    return s;
}

unsigned VFSFile::XAttrCount() const
{
    return 0;
}

void VFSFile::XAttrIterateNames( function<bool(const char* _xattr_name)> _handler ) const
{
}

optional<vector<uint8_t>> VFSFile::ReadFile()
{
    if(!IsOpened())
        return nullopt;
    
    if(GetReadParadigm() < ReadParadigm::Seek && Pos() != 0)
        return nullopt;
    
    if(Pos() != 0 && Seek(Seek_Set, 0) < 0)
        return nullopt; // can't rewind file
    
    uint64_t sz = Size();
    auto buf = vector<uint8_t>(sz);
    
    uint8_t *buftmp = buf.data();
    uint64_t szleft = sz;
    while(szleft) {
        ssize_t r = Read(buftmp, szleft);
        if(r < 0)
            return nullopt;
        szleft -= r;
        buftmp += r;
    }
    
    return move(buf);
}

int VFSFile::WriteFile(const void *_d, size_t _sz)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    const uint8_t *d = (uint8_t *)_d;
    ssize_t r = 0;
    while( _sz > 0 ) {
        r = Write(d, _sz);
        if(r >= 0) {
            d += r;
            _sz -= r;
        }
        else
            return (int)r;
    }
    return VFSError::Ok;
}

ssize_t VFSFile::XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const
{
    return SetLastError(VFSError::NotSupported);
}

ssize_t VFSFile::Skip(size_t _size)
{
    const size_t trash_size = 32768;
    static char trash[trash_size];
    size_t skipped = 0;
    
    while(_size > 0) {
        ssize_t r = Read(trash, min(_size, trash_size));
        if(r < 0)
            return r;
        if(r == 0)
            return VFSError::UnexpectedEOF;
        _size -= r;
        skipped += r;
    }
    return skipped;
}

int VFSFile::SetUploadSize(size_t _size)
{
    return 0;
}

int VFSFile::SetLastError(int _error) const
{
    return m_LastError = _error;
}

int VFSFile::LastError() const
{
    return m_LastError;
}

int VFSFile::PreferredIOSize() const
{
    return VFSError::NotSupported;
}
