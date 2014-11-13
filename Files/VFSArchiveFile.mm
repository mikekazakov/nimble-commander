//
//  VFSArchiveFile.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSArchiveFile.h"
#import "VFSArchiveInternal.h"
#import "AppleDoubleEA.h"

VFSArchiveFile::VFSArchiveFile(const char* _relative_path, shared_ptr<VFSArchiveHost> _host):
    VFSFile(_relative_path, _host),
    m_EA(0),
    m_EACount(0)
{
}

VFSArchiveFile::~VFSArchiveFile()
{
    Close();
}

int VFSArchiveFile::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
    if( strlen(RelativePath()) < 2 || RelativePath()[0] != '/' )
        return SetLastError(VFSError::NotFound);
    
    if(_open_flags & VFSFlags::OF_Write)
        return SetLastError(VFSError::NotSupported); // ArchiveFile is Read-Only

    int res;
    auto host = dynamic_pointer_cast<VFSArchiveHost>(Host());

    char file_path[MAXPATHLEN*2];
    res = host->ResolvePathIfNeeded(RelativePath(), file_path, /*_open_flags*/0); // VFSFile currently don't have NoFollow flag, need to merge Host and File flags
    if(res < 0)
        return res;

    if(host->IsDirectory(file_path, /*_open_flags*/0, _cancel_checker))
        return VFSError::FromErrno(EISDIR);
    
    unique_ptr<VFSArchiveState> state;
    res = host->ArchiveStateForItem(file_path, state);
    if(res < 0)
        return res;
    
    assert(state->Entry());

    // read and parse metadata(xattrs) if any
    size_t s;
    m_EA = ExtractEAFromAppleDouble(archive_entry_mac_metadata(state->Entry(), &s), s, &m_EACount);
    
    m_Position = 0;
    m_Size = archive_entry_size(state->Entry());
    m_State = move(state);
    
    return VFSError::Ok;;
}

bool VFSArchiveFile::IsOpened() const
{
    return m_State != nullptr;
}

int VFSArchiveFile::Close()
{
    dynamic_pointer_cast<VFSArchiveHost>(Host())->CommitState( move(m_State) );
    m_State.reset();
    
    m_EACount = 0;
    free(m_EA);
    m_EA = 0;
    
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSArchiveFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

ssize_t VFSArchiveFile::Pos() const
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    return m_Position;
}

ssize_t VFSArchiveFile::Size() const
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    return m_Size;
}

bool VFSArchiveFile::Eof() const
{
    if(!IsOpened())
        return true;
    return m_Position == m_Size;
}

ssize_t VFSArchiveFile::Read(void *_buf, size_t _size)
{
    if(IsOpened() == 0) return SetLastError(VFSError::InvalidCall);
    if(Eof())     return 0;
    
    assert(_buf != 0);

    m_State->ConsumeEntry();
    ssize_t size = archive_read_data(m_State->Archive(), _buf, _size);
    if(size < 0)
    {
        // TODO: libarchive error - convert it into our errors
        printf("libarchive error: %s\n", archive_error_string(m_State->Archive()));
        return SetLastError(VFSError::FromLibarchive(archive_errno(m_State->Archive())));
    }
    
    m_Position += size;
    
    return size;
}

unsigned VFSArchiveFile::XAttrCount() const
{
    return (unsigned)m_EACount;
}

void VFSArchiveFile::XAttrIterateNames( function<bool(const char* _xattr_name)> _handler ) const
{
    if(!_handler || m_EACount == 0)
        return;
    assert(m_EA != 0);
    
    for(int i = 0; i < m_EACount; ++i)
        if( !_handler(m_EA[i].name) )
            break;
}

ssize_t VFSArchiveFile::XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const
{
    if(!IsOpened() || !_xattr_name)
        return SetLastError(VFSError::InvalidCall);
    
    for(int i = 0; i < m_EACount; ++i)
        if(strcmp(m_EA[i].name, _xattr_name) == 0)
        {
            if(_buffer == 0)
                return m_EA[i].data_sz;
    
            size_t sz = min(m_EA[i].data_sz, (uint32_t)_buf_size);
            memcpy(_buffer, m_EA[i].data, sz);
            return sz;
        }

    return SetLastError(VFSError::NotFound);
}
