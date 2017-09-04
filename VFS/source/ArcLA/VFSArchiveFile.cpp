//
//  VFSArchiveFile.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>
#include <VFS/AppleDoubleEA.h>
#include "VFSArchiveFile.h"
#include "VFSArchiveInternal.h"

VFSArchiveFile::VFSArchiveFile(const char* _relative_path, const shared_ptr<VFSArchiveHost> &_host):
    VFSFile(_relative_path, _host)
{
}

VFSArchiveFile::~VFSArchiveFile()
{
    Close();
}

int VFSArchiveFile::Open(int _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if( strlen(Path()) < 2 || Path()[0] != '/' )
        return SetLastError(VFSError::NotFound);
    
    if(_open_flags & VFSFlags::OF_Write)
        return SetLastError(VFSError::NotSupported); // ArchiveFile is Read-Only

    int res;
    auto host = dynamic_pointer_cast<VFSArchiveHost>(Host());

    char file_path[MAXPATHLEN*2];
    res = host->ResolvePathIfNeeded(Path(), file_path, _open_flags);
    if(res < 0)
        return res;

    if( host->IsDirectory(file_path, _open_flags, _cancel_checker) &&
      !(_open_flags & VFSFlags::OF_Directory) )
        return VFSError::FromErrno(EISDIR);
    
    unique_ptr<VFSArchiveState> state;
    res = host->ArchiveStateForItem(file_path, state);
    if(res < 0)
        return res;
    
    assert(state->Entry());

    // read and parse metadata(xattrs) if any
    size_t s;
    m_EA = ExtractEAFromAppleDouble(archive_entry_mac_metadata(state->Entry(), &s), s);
    
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
    return (unsigned)m_EA.size();
}

void VFSArchiveFile::XAttrIterateNames( function<bool(const char* _xattr_name)> _handler ) const
{
    if(!_handler || m_EA.empty())
        return;
    
    for(auto &i: m_EA)
        if( !_handler(i.name) )
            break;
}

ssize_t VFSArchiveFile::XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const
{
    if(!IsOpened() || !_xattr_name)
        return SetLastError(VFSError::InvalidCall);
    
    for(auto &i: m_EA)
        if(strcmp(i.name, _xattr_name) == 0) {
            if(_buffer == 0)
                return i.data_sz;
    
            size_t sz = min(i.data_sz, (uint32_t)_buf_size);
            memcpy(_buffer, i.data, sz);
            return sz;
        }

    return SetLastError(VFSError::NotFound);
}
